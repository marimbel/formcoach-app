import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/form_errors.dart';
import '../models/session_stats.dart';
import '../theme.dart';
import '../widgets/exercise_figure.dart';

class FormTipsScreen extends StatelessWidget {
  final LabelsConfig config;
  const FormTipsScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Scaffold(
      appBar: AppBar(title: const Text('Form Tips')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final ex in config.exercises.values) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ExerciseFigure(exercise: ex.id, size: 48),
                  const SizedBox(width: 12),
                  Text(exerciseName(ex.id), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                for (final tip in exerciseTips[ex.id] ?? const <String>[])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.check_circle, size: 20, color: fc.success),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tip)),
                    ]),
                  ),
                const SizedBox(height: 6),
                Text('Common mistakes the app watches for: '
                    '${ex.errors.where((e) => e != 'correct').map((e) => infoFor(e).title.toLowerCase()).join(', ')}.',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    ('Set up the camera', 'Stand the phone up at hip height, 2–3 m away, so your whole body is in frame. For push-ups, put it on the floor about 2 m away, turned about 45° from your side.'),
    ('"I can\'t see you clearly"', 'Step back or move the phone until the skeleton covers your whole body. Bright, even light and fitted clothing help.'),
    ('Reps aren\'t counted', 'Start each set standing tall (in a high plank for push-ups) and move through a full rep. Very fast or very shallow reps may be skipped.'),
    ('No spoken feedback', 'Check that Audio Feedback is on in Settings, the speaker button on the camera screen isn\'t muted, and your phone isn\'t on silent.'),
    ('"Coach: offline"', 'The app couldn\'t reach the coaching server, so it used simple built-in cues. Check your internet connection.'),
    ('Privacy', 'Video stays on your phone. For coaching, only joint measurements and one small cropped image per rep are sent to the server.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final (q, a) in _faq) ...[
          Card(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Align(alignment: Alignment.centerLeft, child: Text(a))],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const Text('FormCoach is a fitness tool, not medical advice. Stop if you feel pain.', textAlign: TextAlign.center),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const models = [
      ('Pose detection', 'Finds your joints in every frame (on your phone).'),
      ('Form classifier', 'Recognizes common mistakes at the bottom of each rep (on your phone).'),
      ('AI coach', 'Turns what the models saw into one short, useful cue (Gemini, in the cloud).'),
      ('Visual trainer', 'Draws what correct form looks like (Gemini image model, in the cloud).'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('About This App')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('AI Fitness Coach', style: t.headlineSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Real-time form feedback for squats, lunges and push-ups, using your phone\'s camera.'),
        const SizedBox(height: 20),
        Text('How it works', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final (name, what) in models)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.auto_awesome, color: cs.primary),
            title: Text(name),
            subtitle: Text(what),
          ),
        const SizedBox(height: 16),
        Text('CS 663 Computer Vision · Project 2 · Group 1\nMarianna Belmares, Brent Paterson, Nico Savaides',
            style: t.bodySmall),
        const SizedBox(height: 4),
        Text('Version 1.0', style: t.bodySmall),
      ]),
    );
  }
}
