import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../vision/form_classifier.dart';
import 'live_screen.dart';

const _icons = {'squat': Icons.accessibility_new, 'lunge': Icons.directions_walk, 'chest_press': Icons.fitness_center};

class HomeScreen extends StatefulWidget {
  final LabelsConfig config;
  final FormClassifier? classifier;
  const HomeScreen({super.key, required this.config, required this.classifier});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _coachModel = 'tuned';
  final _scenario = TextEditingController();

  Future<void> _start(ExerciseConfig ex) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set up for ${ex.display}'),
        content: Text('${ex.cameraHint}\n\nStart from a standing (or arms-extended) position. '
            'Cues are spoken, so you don\'t need to watch the screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LiveScreen(
                config: widget.config,
                ex: ex,
                classifier: widget.classifier,
                coachModel: _coachModel,
                scenario: _scenario.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('FormCoach')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Choose an exercise', style: t.headlineSmall),
          const SizedBox(height: 12),
          for (final ex in widget.config.exercises.values)
            Card(
              child: ListTile(
                minVerticalPadding: 18,
                leading: Icon(_icons[ex.id] ?? Icons.sports_gymnastics, size: 36),
                title: Text(ex.display, style: t.titleLarge),
                subtitle: Text(ex.errors.where((e) => e != 'correct').map((e) => e.replaceAll('_', ' ')).join(' · ')),
                onTap: () => _start(ex),
              ),
            ),
          const SizedBox(height: 24),
          if (widget.classifier == null)
            const Card(
              color: Color(0xFF5A3A00),
              child: ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('Form model (Model A) not loaded'),
                subtitle: Text('Add assets/models/form_classifier.tflite. Reps are still counted; coaching will hold.'),
              ),
            ),
          ExpansionTile(
            title: const Text('Testing options'),
            children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Coach model (for base vs. tuned demos)')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'tuned', label: Text('Tuned')),
                  ButtonSegment(value: 'base', label: Text('Base')),
                  ButtonSegment(value: 'mock', label: Text('Rules')),
                ],
                selected: {_coachModel},
                onSelectionChanged: (s) => setState(() => _coachModel = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scenario,
                decoration: const InputDecoration(
                    labelText: 'Test scenario label (saved in the session log)',
                    hintText: 'e.g. p11_squat_knee_valgus_dim_light'),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text('Backend: $backendUrl', style: t.bodySmall)),
              const SizedBox(height: 12),
            ],
          ),
          const SizedBox(height: 8),
          Text('FormCoach is a fitness tool, not medical advice. Stop if you feel pain.', style: t.bodySmall),
        ],
      ),
    );
  }
}
