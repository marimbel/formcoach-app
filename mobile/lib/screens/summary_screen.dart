import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../coach/coach_client.dart';
import '../models/form_errors.dart';
import '../models/session_stats.dart';
import '../theme.dart';
import '../widgets/exercise_figure.dart';
import 'trainer_screen.dart';

/// Mockup screen 4: Session Summary. Used after a session and when opening one from History.
class SessionSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> log;
  final String? savedPath;
  final CoachClient? client;
  const SessionSummaryScreen({super.key, required this.log, this.savedPath, this.client});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fc = context.fc;
    final st = SessionStats.fromLog(log);
    final top = st.mostCommon;
    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        Text(formatSessionDate(st.started),
            textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: fc.successSoft, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            ExerciseFigure(exercise: st.exercise, size: 52),
            const SizedBox(width: 16),
            Text(exerciseName(st.exercise), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Stat(label: 'Total Reps', value: st.totalReps)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'Correct Reps', value: st.correctReps, color: fc.success)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'Form Issues', value: st.issueReps, color: fc.danger)),
        ]),
        if (top != null) ...[
          const SizedBox(height: 20),
          Text('Most Common Issue', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Material(
            color: fc.dangerSoft,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TrainerScreen(client: client ?? CoachClient(), exercise: st.exercise, error: top.key)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.report, color: fc.danger, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(infoFor(top.key).title,
                          style: TextStyle(color: fc.danger, fontWeight: FontWeight.w700, fontSize: 16.5)),
                      const SizedBox(height: 2),
                      Text('Detected in ${st.percentOfReps(top.value)}% of your reps.'),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: fc.danger),
                ]),
              ),
            ),
          ),
        ],
        if (st.otherIssues.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Other Issues', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              for (final (i, e) in st.otherIssues.indexed) ...[
                if (i > 0) Divider(height: 1, color: fc.cardBorder),
                ListTile(
                  dense: true,
                  title: Text(infoFor(e.key).title, style: t.bodyLarge),
                  trailing: Text('${e.value} rep${e.value == 1 ? '' : 's'}'),
                ),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 20),
        Text('Overall Feedback', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: fc.successSoft, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.star_rounded, color: fc.success, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.feedbackTitle, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(st.feedbackBody),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _EvalDetails(log: log, savedPath: savedPath),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('$value',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: color ?? Theme.of(context).colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      );
}

/// Per-stage timings and the raw log, for the evaluation section of the report.
class _EvalDetails extends StatelessWidget {
  final Map<String, dynamic> log;
  final String? savedPath;
  const _EvalDetails({required this.log, this.savedPath});

  @override
  Widget build(BuildContext context) {
    final stats = (log['stats'] as Map?) ?? const {};
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('Performance details'),
          subtitle: const Text('Timings and the session log, for evaluation'),
          children: [
            for (final e in stats.entries)
              ListTile(dense: true, title: Text('${e.key}'), trailing: Text('${e.value}')),
            if (savedPath != null) ListTile(dense: true, title: const Text('Log file'), subtitle: Text(savedPath!)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent(' ').convert(log)));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session log copied')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy session log (JSON)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
