import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/app_settings.dart';
import '../theme.dart';
import '../vision/form_classifier.dart';
import '../widgets/exercise_figure.dart';
import 'live_screen.dart';

/// Mockup screen 1: Home / Exercise Selection.
class HomeScreen extends StatefulWidget {
  final LabelsConfig config;
  final FormClassifier? classifier;
  final AppSettings settings;
  final VoidCallback onSessionSaved;
  const HomeScreen({super.key, required this.config, required this.classifier, required this.settings,
      required this.onSessionSaved});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _selected = widget.config.exercises.keys.first;

  Future<void> _start() async {
    final ex = widget.config.exercises[_selected]!;
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _SetupSheet(ex: ex),
    );
    if (go != true || !mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LiveScreen(config: widget.config, ex: ex, classifier: widget.classifier, settings: widget.settings),
      ),
    );
    if (saved == true) widget.onSessionSaved();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final name = widget.settings.profileName;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        children: [
          Text('AI Fitness Coach',
              textAlign: TextAlign.center,
              style: t.headlineMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            name.isEmpty
                ? 'Get real-time feedback on your form and improve your workouts.'
                : 'Hi $name! Get real-time feedback on your form and improve your workouts.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          for (final ex in widget.config.exercises.values) ...[
            _ExerciseCard(ex: ex, selected: ex.id == _selected, onTap: () => setState(() => _selected = ex.id)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton(onPressed: _start, child: const Text('Start Session')),
          if (widget.classifier == null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: context.fc.info),
                title: const Text('Form model not installed yet'),
                subtitle: const Text('Reps are still counted. Form feedback starts once Model A is added to the app.'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseConfig ex;
  final bool selected;
  final VoidCallback onTap;
  const _ExerciseCard({required this.ex, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fc = context.fc;
    return Semantics(
      selected: selected,
      button: true,
      label: '${ex.display}${selected ? ', selected' : ''}',
      child: Material(
        color: selected ? fc.successSoft : fc.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? cs.primary : fc.cardBorder, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              ExerciseFigure(exercise: ex.id, size: 72),
              const SizedBox(width: 18),
              Expanded(
                child: Text(_shortName(ex), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              ),
              Icon(selected ? Icons.check_circle : Icons.chevron_right, color: selected ? cs.primary : cs.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

String _shortName(ExerciseConfig ex) => switch (ex.id) {
      'squat' => 'Squat',
      'lunge' => 'Lunge',
      'chest_press' => 'Chest Press',
      _ => ex.display,
    };

class _SetupSheet extends StatelessWidget {
  final ExerciseConfig ex;
  const _SetupSheet({required this.ex});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Set up for ${_shortName(ex)}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _step(context, Icons.phone_android, ex.cameraHint),
          _step(context, Icons.accessibility_new,
              ex.id == 'chest_press' ? 'Start with your arms extended.' : 'Start standing tall.'),
          _step(context, Icons.volume_up_outlined, 'Feedback is spoken after each rep, so you don\'t need to watch the screen.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("I'm ready")),
        ]),
      ),
    );
  }

  Widget _step(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      );
}
