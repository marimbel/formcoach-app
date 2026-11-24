import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_config.dart';
import '../models/session_stats.dart';
import '../theme.dart';
import '../widgets/exercise_figure.dart';
import 'summary_screen.dart';

class _Saved {
  final File file;
  final Map<String, dynamic> log;
  final SessionStats stats;
  _Saved(this.file, this.log) : stats = SessionStats.fromLog(log);
}

/// History tab: past sessions saved on this phone (the same JSON logs used for evaluation).
class HistoryScreen extends StatefulWidget {
  final LabelsConfig config;
  const HistoryScreen({super.key, required this.config});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<_Saved>? _sessions;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final out = <_Saved>[];
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.startsWith('formcoach_') || !name.endsWith('.json')) continue;
        try {
          out.add(_Saved(f, jsonDecode(await f.readAsString()) as Map<String, dynamic>));
        } catch (_) {
          // skip unreadable files
        }
      }
    } catch (_) {}
    out.sort((a, b) => b.stats.started.compareTo(a.stats.started));
    if (mounted) setState(() => _sessions = out);
  }

  Future<void> _delete(_Saved s) async {
    try {
      await s.file.delete();
    } catch (_) {}
    setState(() => _sessions?.remove(s));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = _sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bar_chart, size: 48, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('No sessions yet', style: t.titleMedium),
                      const SizedBox(height: 4),
                      const Text('Finish a session and its summary will appear here.', textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    _Totals(list.map((s) => s.stats).toList()),
                    const SizedBox(height: 16),
                    for (final s in list) ...[
                      Dismissible(
                        key: ValueKey(s.file.path),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: context.fc.danger, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(s),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            leading: ExerciseFigure(exercise: s.stats.exercise, size: 44),
                            title: Text(exerciseName(s.stats.exercise), style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${formatSessionDate(s.stats.started)}\n'
                                '${s.stats.totalReps} reps · ${s.stats.issueReps} form issue${s.stats.issueReps == 1 ? '' : 's'}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => SessionSummaryScreen(log: s.log, savedPath: s.file.path))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text('Swipe left on a session to delete it.', textAlign: TextAlign.center, style: t.bodySmall),
                  ]),
                ),
    );
  }
}

class _Totals extends StatelessWidget {
  final List<SessionStats> all;
  const _Totals(this.all);

  @override
  Widget build(BuildContext context) {
    final reps = all.fold<int>(0, (a, s) => a + s.totalReps);
    final correct = all.fold<int>(0, (a, s) => a + s.correctReps);
    final pct = reps == 0 ? 0 : (100 * correct / reps).round();
    Widget cell(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: context.fc.successSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [cell('Sessions', '${all.length}'), cell('Total reps', '$reps'), cell('Good form', '$pct%')]),
    );
  }
}
