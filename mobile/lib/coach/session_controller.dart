// Orchestrates one workout session:
//   camera frame -> Model C pose (on device) -> One Euro smoothing -> visibility gate
//   -> rep counter (knee/elbow angle) -> snapshots of the 3 deepest frames
//   -> on rep end: Model A on the crops (on device) + joint-angle features
//   -> Model B coach via backend (Gemini) -> spoken cue / UI;  Model D on request (trainer screen).
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/app_config.dart';
import '../vision/form_classifier.dart';
import '../vision/frame_sampler.dart';
import '../vision/geometry.dart';
import '../vision/pose_service.dart';
import '../vision/temporal.dart';
import 'coach_client.dart';
import 'session_log.dart';

class _Snap {
  final double angle;
  final Crop crop;
  final Pose33 landmarks;
  _Snap(this.angle, this.crop, this.landmarks);
}

class SessionController extends ChangeNotifier {
  final LabelsConfig config;
  final ExerciseConfig ex;
  final FormClassifier? classifier;
  final String coachModel; // tuned | base | mock
  final CoachClient coach;
  final PoseService _pose = PoseService();
  final FlutterTts _tts = FlutterTts();
  final Stopwatch _clock = Stopwatch()..start();
  late final SessionLog log;

  List<CameraDescription> _cameras = [];
  int _camIndex = 0;
  CameraController? controller;
  bool _busy = false, _disposed = false;

  PoseSmoother _smoother = PoseSmoother();
  late final RepCounter counter;
  late final VisibilityGate gate;

  // UI state
  Pose33? landmarks;
  Size? uprightSize;
  bool needsReposition = false;
  bool coachBusy = false;
  CoachReply? lastReply;
  String? cameraError;

  // per-rep state
  final List<_Snap> _snaps = [];
  double _visSum = 0;
  int _visN = 0;
  final List<String> _history = [];
  int _repIndex = 0;
  double _lastSpokeAt = -100, _lastRepositionAt = -100, _lastFrameT = -1;
  int _praiseCount = 0;
  bool _lastWasError = false;

  SessionController({
    required this.config,
    required this.ex,
    required this.classifier,
    required this.coachModel,
    required String scenario,
    CoachClient? coachClient,
  }) : coach = coachClient ?? CoachClient() {
    counter = RepCounter(top: ex.top, bottomEnter: ex.bottomEnter, minRepSeconds: ex.minRepSeconds);
    gate = VisibilityGate(ex.requiredLandmarks, gateSeconds: config.gateSeconds);
    log = SessionLog(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        exercise: ex.id,
        coachModel: coachModel,
        scenario: scenario);
  }

  double get _now => _clock.elapsedMicroseconds / 1e6;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool get isFrontCamera => controller?.description.lensDirection == CameraLensDirection.front;
  bool get modelALoaded => classifier != null;
  int get reps => counter.count;

  Future<void> start() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw CameraException('none', 'No camera found');
      final front = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _camIndex = front >= 0 ? front : 0;
      await _openCamera();
    } on CameraException catch (e) {
      cameraError = 'Camera unavailable: ${e.description ?? e.code}. Check camera permission in Settings.';
      _notify();
    }
  }

  Future<void> _openCamera() async {
    final c = CameraController(_cameras[_camIndex], ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
    await c.initialize();
    if (_disposed) {
      await c.dispose();
      return;
    }
    controller = c;
    await c.startImageStream(_onFrame);
    _notify();
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    final old = controller;
    controller = null;
    _notify();
    await old?.stopImageStream();
    await old?.dispose();
    _camIndex = (_camIndex + 1) % _cameras.length;
    _smoother = PoseSmoother();
    await _openCamera();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final c = controller;
      if (c == null) return;
      final rot = _pose.rotationFor(c, c.description);
      if (rot == null) return;
      final t = _now;
      if (_lastFrameT > 0) log.frameIntervalsMs.add((t - _lastFrameT) * 1000);
      _lastFrameT = t;

      final sw = Stopwatch()..start();
      final pf = await _pose.detect(image, rot); // Model C
      log.poseMs.add(sw.elapsedMicroseconds / 1000);
      if (_disposed) return;

      final smoothed = pf == null ? null : _smoother(pf.landmarks, t);
      landmarks = smoothed;
      uprightSize = pf?.uprightSize ?? uprightSize;
      needsReposition = gate.update(smoothed, t);
      if (needsReposition) {
        _promptReposition(t);
        _notify();
        return; // don't count or judge reps we can't see
      }
      if (smoothed == null) {
        _notify();
        return;
      }

      final angle = primaryAngle(smoothed, ex.angle, ex.combine);
      final ev = counter.update(angle, t);
      if (ev.enteredDown) {
        _snaps.clear();
        _visSum = 0;
        _visN = 0;
      }
      if (counter.inDown || ev.completed != null) {
        _visSum += gate.meanVisibility(smoothed);
        _visN++;
      }
      if (ev.newMin) _snapshot(image, rot, angle, smoothed);
      if (ev.completed != null) {
        final snaps = List<_Snap>.from(_snaps);
        final vis = _visN > 0 ? _visSum / _visN : 0.0;
        final bottomLm = snaps.isNotEmpty ? snaps.first.landmarks : smoothed;
        final reqVisible = allVisible(bottomLm, ex.requiredLandmarks);
        unawaited(_handleRep(ev.completed!, snaps, vis, reqVisible, t));
      }
      _notify();
    } catch (e, st) {
      debugPrint('frame error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  /// Keep the 3 deepest frames of the current rep (lowest angle first) as Model A inputs.
  void _snapshot(CameraImage image, int rot, double angle, Pose33 lm) {
    if (_snaps.length == 3 && angle >= _snaps.last.angle) return;
    final box = personBox(lm);
    final crop = sampleCrop(image, rot, box.left, box.top, box.side);
    _snaps.add(_Snap(angle, crop, lm));
    _snaps.sort((a, b) => a.angle.compareTo(b.angle));
    if (_snaps.length > 3) _snaps.removeLast();
  }

  Future<void> _handleRep(RepInfo info, List<_Snap> snaps, double vis, bool reqVisible, double tEnd) async {
    final idx = ++_repIndex;
    final sw = Stopwatch()..start();
    final indices = config.indicesFor(ex.id);
    Map<String, double> probs;
    if (classifier != null && snaps.isNotEmpty) {
      final all = <List<double>>[];
      for (final s in snaps) {
        all.add(await classifier!.predict(s.crop.input)); // Model A
      }
      probs = FormClassifier.maskedAverage(all, indices, config.classNames);
    } else {
      probs = {for (final e in ex.errors) e: 1.0 / ex.errors.length}; // no Model A: coach will hold
    }
    final modelAMs = sw.elapsedMicroseconds / 1000;
    final top = probs.entries.reduce((a, b) => b.value > a.value ? b : a);
    final lm = snaps.isNotEmpty ? snaps.first.landmarks : landmarks;
    if (lm == null) return;
    final feats = featuresForJson(frameFeatures(lm, ex.id)..['min_primary_angle'] = info.minAngle);
    final situation = <String, dynamic>{
      'exercise': ex.id,
      'rep_index': idx,
      'phase': 'bottom',
      'view': estimateView(lm),
      'pose_quality': {'visibility': vis.clamp(0.0, 1.0), 'required_visible': reqVisible},
      'model_a': {'top_error': top.key, 'top_prob': top.value, 'probs': probs},
      'pose_features': feats,
      'history': _history.length > 3 ? _history.sublist(_history.length - 3) : List<String>.from(_history),
    };
    if (reqVisible) _history.add(top.value >= 0.5 ? top.key : 'uncertain');

    coachBusy = true;
    _notify();
    final c0 = Stopwatch()..start();
    final jpeg = snaps.isNotEmpty ? encodeJpeg(snaps.first.crop.image) : null;
    final reply = await coach.coach(situation, jpeg: jpeg, model: coachModel, sessionId: log.sessionId);
    final coachMs = c0.elapsedMicroseconds / 1000;
    coachBusy = false;
    if (_disposed) return;
    lastReply = reply;
    _maybeSpeak(reply);
    log.reps.add(RepRecord(
        index: idx,
        tEnd: tEnd,
        situation: situation,
        reply: reply.toJson(),
        modelAMs: modelAMs,
        coachMs: coachMs,
        endToEndMs: (_now - tEnd) * 1000,
        modelALoaded: classifier != null));
    _notify();
  }

  void _maybeSpeak(CoachReply r) {
    final now = _now;
    final wasError = _lastWasError;
    _lastWasError = r.action == 'coach';
    if (r.action == 'hold' || r.cue.isEmpty) return;
    final cooldownOk = now - _lastSpokeAt >= config.speakCooldownSeconds;
    if (r.action == 'praise') {
      _praiseCount++;
      if (!(wasError || (cooldownOk && _praiseCount % 3 == 1))) return;
    } else if (!cooldownOk && r.severity != 'high') {
      return;
    }
    _tts.speak(r.cue);
    _lastSpokeAt = now;
    if (r.action == 'coach') HapticFeedback.mediumImpact();
  }

  void _promptReposition(double t) {
    if (t - _lastRepositionAt < 6) return;
    _lastRepositionAt = t;
    log.repositionPrompts++;
    _tts.speak(ex.id == 'chest_press'
        ? 'Move the phone so both arms are visible.'
        : 'Step back so I can see your whole body.');
  }

  Future<String> finish() async {
    _disposed = true;
    final c = controller;
    controller = null;
    try {
      await c?.stopImageStream();
    } catch (_) {}
    await c?.dispose();
    await _tts.stop();
    await _pose.close();
    return log.save();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      controller?.dispose();
      _pose.close();
    }
    super.dispose();
  }
}
