import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_config.dart';
import '../models/session_stats.dart';
import '../theme.dart';
import '../widgets/exercise_figure.dart';
import '../widgets/score_ring.dart';
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
      appBar: AppBar(title: const Text('Progress')),
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
                            trailing: s.stats.hasScore ? ScorePill(score: s.stats.formScore) : const Icon(Icons.chevron_right),
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
  final List<SessionStats> all; // newest first
  const _Totals(this.all);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reps = all.fold<int>(0, (a, s) => a + s.totalReps);
    final scored = all.where((s) => s.hasScore).toList().reversed.toList(); // oldest -> newest
    final recent = scored.length > 12 ? scored.sublist(scored.length - 12) : scored;
    final avg = recent.isEmpty ? 0 : (recent.fold<int>(0, (a, s) => a + s.formScore) / recent.length).round();
    Widget cell(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label, style: t.bodySmall),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Form score', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (recent.isNotEmpty)
              Text('Latest ${recent.last.formScore}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: scoreColor(context, recent.last.formScore))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: recent.length < 2
                ? Center(child: Text('Your trend appears after two sessions.', style: t.bodySmall))
                : CustomPaint(
                    size: Size.infinite,
                    painter: _TrendPainter(
                      recent.map((s) => s.formScore.toDouble()).toList(),
                      line: Theme.of(context).colorScheme.primary,
                      grid: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                      label: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            cell('Sessions', '${all.length}'),
            cell('Total reps', '$reps'),
            cell('Average score', recent.isEmpty ? '–' : '$avg'),
          ]),
        ]),
      ),
    );
  }
}

/// Line of form scores (0-100) for the most recent sessions, oldest on the left.
class _TrendPainter extends CustomPainter {
  final List<double> scores;
  final Color line, grid, label;
  _TrendPainter(this.scores, {required this.line, required this.grid, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, top = 6.0, bottom = 6.0;
    final w = size.width - left - 4, h = size.height - top - bottom;
    double y(double v) => top + h * (1 - v / 100);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in const [0.0, 50.0, 100.0]) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), gridPaint);
      final tp = TextPainter(
          text: TextSpan(text: v.toInt().toString(), style: TextStyle(fontSize: 10, color: label)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, y(v) - tp.height / 2));
    }
    final step = scores.length > 1 ? w / (scores.length - 1) : 0.0;
    final pts = [for (var i = 0; i < scores.length; i++) Offset(left + i * step, y(scores[i]))];
    final fill = Path()..moveTo(pts.first.dx, y(0));
    for (final p in pts) {
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(pts.last.dx, y(0))
      ..close();
    canvas.drawPath(fill, Paint()..color = line.withValues(alpha: 0.10));
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);
    for (final p in pts) {
      canvas.drawCircle(p, 3, Paint()..color = line);
    }
    canvas.drawCircle(pts.last, 6, Paint()..color = line);
    canvas.drawCircle(pts.last, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.scores != scores || old.line != line;
}
