import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../coach/coach_client.dart';
import '../coach/session_controller.dart';
import '../models/app_config.dart';
import '../models/app_settings.dart';
import '../models/form_errors.dart';
import '../theme.dart';
import '../vision/form_classifier.dart';
import '../widgets/exercise_figure.dart';
import '../widgets/pose_painter.dart';
import 'summary_screen.dart';
import 'trainer_screen.dart';

/// Mockup screen 2: Camera / Live Feedback.
class LiveScreen extends StatefulWidget {
  final LabelsConfig config;
  final ExerciseConfig ex;
  final FormClassifier? classifier;
  final AppSettings settings;
  const LiveScreen({super.key, required this.config, required this.ex, required this.classifier, required this.settings});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final SessionController s;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    final st = widget.settings;
    s = SessionController(
      config: widget.config,
      ex: widget.ex,
      classifier: widget.classifier,
      coachModel: st.coachModel,
      scenario: st.scenario,
      audioEnabled: st.audioFeedback,
      preferFrontCamera: st.frontCamera,
    );
    s.start();
  }

  @override
  void dispose() {
    s.dispose();
    super.dispose();
  }

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    final path = await s.finish();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SessionSummaryScreen(log: s.log.toJson(), savedPath: path, client: s.coach)),
      result: true,
    );
  }

  Future<void> _pauseSheet() async {
    s.pause();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Paused', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${s.reps} reps so far'),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, 'resume'), icon: const Icon(Icons.play_arrow), label: const Text('Resume')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.pop(ctx, 'end'),
              icon: const Icon(Icons.stop),
              label: const Text('End session'),
            ),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'end') {
      _end();
    } else {
      s.resume();
    }
  }

  void _toggleAudio() {
    final on = !s.audioEnabled;
    s.setAudio(on);
    widget.settings.setAudio(on);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_ending) _pauseSheet();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: s,
          builder: (context, _) => Stack(children: [
            Positioned.fill(child: _camera()),
            // soft gradients so overlays stay readable on bright scenes
            const Positioned(top: 0, left: 0, right: 0, height: 140, child: _Fade(top: true)),
            const Positioned(bottom: 0, left: 0, right: 0, height: 300, child: _Fade(top: false)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(children: [
                  _topBar(),
                  if (s.needsReposition) ...[const SizedBox(height: 12), _repositionBanner()],
                  if (s.paused) ...[const SizedBox(height: 12), const _Pill(text: 'Paused', dark: true)],
                  const Spacer(),
                  _alertCard(context),
                  const SizedBox(height: 16),
                  _controls(),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _camera() {
    if (s.cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(s.cameraError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    final c = s.controller;
    if (c == null || !c.value.isInitialized || c.value.previewSize == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 12),
          Text('Starting camera…', style: TextStyle(color: Colors.white)),
        ]),
      );
    }
    final ps = c.value.previewSize!; // landscape sensor size; the app is portrait-only
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ps.height,
          height: ps.width,
          child: CameraPreview(
            c,
            child: CustomPaint(
              painter: PosePainter(
                pose: s.landmarks,
                imageSize: s.uprightSize,
                mirror: s.isFrontCamera,
                highlight: jointsFor(s.lastReply?.action == 'coach' ? s.lastReply?.error : null),
                requiredJoints: widget.ex.requiredLandmarks,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Theme(
            data: buildTheme(Brightness.light),
            child: ExerciseFigure(exercise: widget.ex.id, size: 30),
          ),
          const SizedBox(width: 8),
          Text(_name(widget.ex), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
      ),
      const Spacer(),
      if (s.coachBusy)
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        ),
      Semantics(label: '${s.reps} reps', child: _Pill(text: 'Rep: ${s.reps}', dark: true)),
    ]);
  }

  Widget _repositionBanner() {
    final fc = context.fc;
    return _AlertShell(
      background: fc.infoSoft,
      border: fc.info,
      icon: Icon(Icons.open_with, color: fc.info),
      title: "I can't see you clearly",
      titleColor: fc.info,
      body: widget.ex.cameraHint,
    );
  }

  Widget _alertCard(BuildContext context) {
    final fc = context.fc;
    final r = s.lastReply;
    if (r == null) {
      return _AlertShell(
        background: fc.card,
        border: fc.cardBorder,
        icon: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary),
        title: s.reps == 0 ? 'Do your first rep' : 'Analyzing your form…',
        body: s.modelALoaded
            ? 'Feedback appears after each rep.'
            : 'Counting reps. Form feedback needs the form model, which isn\'t installed yet.',
      );
    }
    switch (r.action) {
      case 'coach':
        final info = infoFor(r.error);
        return _AlertShell(
          background: fc.dangerSoft,
          border: fc.danger,
          icon: Icon(Icons.error, color: fc.danger, size: 30),
          title: info.title,
          titleColor: fc.danger,
          body: r.cue,
          footer: _source(r),
          onTap: r.error == null ? null : () => _openTrainer(r),
          trailing: r.error == null ? null : 'See correct form',
        );
      case 'praise':
        return _AlertShell(
          background: fc.successSoft,
          border: fc.success,
          icon: Icon(Icons.check_circle, color: fc.success, size: 30),
          title: 'Good rep!',
          titleColor: fc.success,
          body: r.cue,
          footer: _source(r),
        );
      case 'reposition':
        return _AlertShell(
          background: fc.infoSoft,
          border: fc.info,
          icon: Icon(Icons.open_with, color: fc.info, size: 30),
          title: 'Adjust the camera',
          titleColor: fc.info,
          body: r.cue,
          footer: _source(r),
        );
      default: // hold
        return _AlertShell(
          background: fc.card,
          border: fc.cardBorder,
          icon: Icon(Icons.visibility_outlined, color: Theme.of(context).colorScheme.primary, size: 30),
          title: 'Keep going',
          body: 'Still watching your form.',
          footer: _source(r),
        );
    }
  }

  String _source(CoachReply r) {
    if (r.source.startsWith('gemini-')) return 'Coach: Gemini (${r.source.substring(7)})';
    if (r.source == 'mock') return 'Coach: rules';
    return 'Coach: offline';
  }

  void _openTrainer(CoachReply r) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => TrainerScreen.fromReply(client: s.coach, exercise: widget.ex.id, reply: r)));
  }

  Widget _controls() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _RoundButton(icon: Icons.cameraswitch_outlined, tooltip: 'Switch camera', onTap: s.switchCamera),
      Semantics(
        button: true,
        label: s.paused ? 'Resume' : 'Pause',
        child: GestureDetector(
          onTap: _ending ? null : (s.paused ? s.resume : _pauseSheet),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: brandGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Icon(s.paused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 40),
          ),
        ),
      ),
      _RoundButton(
        icon: s.audioEnabled ? Icons.volume_up : Icons.volume_off,
        tooltip: s.audioEnabled ? 'Mute spoken feedback' : 'Turn on spoken feedback',
        onTap: _toggleAudio,
      ),
    ]);
  }
}

String _name(ExerciseConfig ex) => switch (ex.id) {
      'squat' => 'Squat',
      'lunge' => 'Lunge',
      'push_up' => 'Push-up',
      _ => ex.display,
    };

class _AlertShell extends StatelessWidget {
  final Color background, border;
  final Widget icon;
  final String title, body;
  final Color? titleColor;
  final String? footer, trailing;
  final VoidCallback? onTap;
  const _AlertShell({
    required this.background,
    required this.border,
    required this.icon,
    required this.title,
    required this.body,
    this.titleColor,
    this.footer,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border.withValues(alpha: 0.5))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: titleColor ?? cs.onSurface)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 15.5, color: cs.onSurface)),
                if (footer != null || trailing != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    if (footer != null) Text(footer!, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                    const Spacer(),
                    if (trailing != null)
                      Text('$trailing ›', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: titleColor ?? cs.primary)),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool dark;
  const _Pill({required this.text, this.dark = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: dark ? Colors.black.withValues(alpha: 0.6) : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: TextStyle(color: dark ? Colors.white : Colors.black, fontSize: 17, fontWeight: FontWeight.w700)),
      );
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 54, height: 54, child: Icon(icon, color: Colors.white, size: 26)),
          ),
        ),
      );
}

class _Fade extends StatelessWidget {
  final bool top;
  const _Fade({required this.top});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
            ),
          ),
        ),
      );
}
