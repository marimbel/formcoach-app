import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../coach/coach_client.dart';
import '../coach/session_controller.dart';
import '../models/app_config.dart';
import '../vision/form_classifier.dart';
import '../widgets/pose_painter.dart';
import 'summary_screen.dart';
import 'trainer_screen.dart';

class LiveScreen extends StatefulWidget {
  final LabelsConfig config;
  final ExerciseConfig ex;
  final FormClassifier? classifier;
  final String coachModel, scenario;
  const LiveScreen({super.key, required this.config, required this.ex, required this.classifier,
      required this.coachModel, required this.scenario});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final SessionController s;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    s = SessionController(
        config: widget.config, ex: widget.ex, classifier: widget.classifier,
        coachModel: widget.coachModel, scenario: widget.scenario);
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
        context, MaterialPageRoute(builder: (_) => SummaryScreen(log: s.log, savedPath: path)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final c = s.controller;
            return Stack(children: [
              Center(
                child: s.cameraError != null
                    ? Padding(padding: const EdgeInsets.all(24), child: Text(s.cameraError!, textAlign: TextAlign.center))
                    : (c == null || !c.value.isInitialized)
                        ? const Column(mainAxisSize: MainAxisSize.min, children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Starting camera…'),
                          ])
                        : CameraPreview(c,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: PosePainter(
                                pose: s.landmarks,
                                imageSize: s.uprightSize,
                                mirror: s.isFrontCamera,
                                highlight: jointsFor(s.lastReply?.action == 'coach' ? s.lastReply?.error : null),
                                requiredJoints: widget.ex.requiredLandmarks,
                              ),
                            )),
              ),
              _topBar(context),
              if (s.needsReposition) _repositionBanner(context),
              Positioned(left: 12, right: 12, bottom: 12, child: _feedbackCard(context)),
            ]);
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Positioned(
      top: 8, left: 8, right: 8,
      child: Row(children: [
        IconButton.filledTonal(onPressed: _ending ? null : _end, icon: const Icon(Icons.stop), tooltip: 'End session'),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.ex.display, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
        if (!s.modelALoaded) const Chip(label: Text('No Model A')),
        if (s.coachBusy)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
          child: Semantics(
            label: '${s.reps} reps',
            child: Text('${s.reps}', style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        IconButton(onPressed: s.switchCamera, icon: const Icon(Icons.cameraswitch), tooltip: 'Switch camera'),
      ]),
    );
  }

  Widget _repositionBanner(BuildContext context) => Positioned(
        top: 80, left: 16, right: 16,
        child: Card(
          color: Colors.blue.shade800,
          child: ListTile(
            leading: const Icon(Icons.open_with, color: Colors.white),
            title: const Text("I can't see you clearly", style: TextStyle(color: Colors.white)),
            subtitle: Text(widget.ex.cameraHint, style: const TextStyle(color: Colors.white70)),
          ),
        ),
      );

  Widget _feedbackCard(BuildContext context) {
    final r = s.lastReply;
    final t = Theme.of(context).textTheme;
    if (r == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.hourglass_empty),
          title: Text(s.reps == 0 ? 'Do your first rep' : 'Analyzing…'),
          subtitle: const Text('Feedback appears after each rep.'),
        ),
      );
    }
    final color = switch (r.action) {
      'coach' => switch (r.severity) { 'high' => Colors.red.shade700, 'medium' => Colors.orange.shade800, _ => Colors.amber.shade800 },
      'praise' => Colors.green.shade700,
      'reposition' => Colors.blue.shade700,
      _ => Colors.grey.shade800,
    };
    final title = r.action == 'hold' ? 'Keep going, still watching' : r.cue;
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          if (r.explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.explanation, style: t.bodyMedium?.copyWith(color: Colors.white70)),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Text(_sourceLabel(r), style: t.labelSmall?.copyWith(color: Colors.white60)),
            const Spacer(),
            if (r.action == 'coach' && r.error != null)
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TrainerScreen(client: s.coach, exercise: widget.ex.id, reply: r))),
                icon: const Icon(Icons.image),
                label: const Text('See correct form'),
              ),
          ]),
        ]),
      ),
    );
  }

  String _sourceLabel(CoachReply r) {
    if (r.source.startsWith('gemini-')) return 'Coach: Gemini (${r.source.substring(7)})';
    if (r.source == 'mock') return 'Coach: rules';
    return 'Coach: offline fallback (${r.source})';
  }
}
