// Everything needed for the full-system evaluation: per-rep predictions from every model,
// where the reply came from (tuned / base / fallback), and per-stage latency.
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RepRecord {
  final int index;
  final double tEnd;
  final Map<String, dynamic> situation;
  final Map<String, dynamic>? reply;
  final double modelAMs, coachMs, endToEndMs;
  final bool modelALoaded;

  RepRecord({
    required this.index,
    required this.tEnd,
    required this.situation,
    required this.reply,
    required this.modelAMs,
    required this.coachMs,
    required this.endToEndMs,
    required this.modelALoaded,
  });

  Map<String, dynamic> toJson() => {
        'rep': index,
        't_end_s': tEnd,
        'situation': situation,
        'reply': reply,
        'model_a_ms': modelAMs,
        'coach_ms': coachMs,
        'end_to_end_ms': endToEndMs,
        'model_a_loaded': modelALoaded,
      };
}

class SessionLog {
  final String sessionId, exercise, coachModel, scenario;
  final DateTime started = DateTime.now();
  final List<RepRecord> reps = [];
  final List<double> poseMs = [];
  final List<double> frameIntervalsMs = [];
  int repositionPrompts = 0;

  SessionLog({required this.sessionId, required this.exercise, required this.coachModel, required this.scenario});

  static double pct(List<double> v, double q) {
    if (v.isEmpty) return double.nan;
    final s = [...v]..sort();
    return s[((s.length - 1) * q).round()];
  }

  Map<String, dynamic> stats() {
    final coach = reps.map((r) => r.coachMs).toList();
    final e2e = reps.map((r) => r.endToEndMs).toList();
    final ma = reps.map((r) => r.modelAMs).toList();
    double r1(double x) => x.isNaN ? -1 : (x * 10).round() / 10;
    final avgInterval = frameIntervalsMs.isEmpty
        ? double.nan
        : frameIntervalsMs.reduce((a, b) => a + b) / frameIntervalsMs.length;
    return {
      'reps': reps.length,
      'pose_ms_p50': r1(pct(poseMs, 0.5)),
      'pose_fps': avgInterval.isNaN ? -1 : r1(1000 / avgInterval),
      'model_a_ms_p50': r1(pct(ma, 0.5)),
      'coach_ms_p50': r1(pct(coach, 0.5)),
      'coach_ms_p95': r1(pct(coach, 0.95)),
      'end_to_end_ms_p50': r1(pct(e2e, 0.5)),
      'fallback_replies': reps.where((r) => !((r.reply?['source'] ?? '') as String).startsWith('gemini')).length,
      'reposition_prompts': repositionPrompts,
    };
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'exercise': exercise,
        'coach_model': coachModel,
        'scenario': scenario,
        'started': started.toIso8601String(),
        'stats': stats(),
        'reps': reps.map((r) => r.toJson()).toList(),
      };

  Future<String> save() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/formcoach_${sessionId}.json');
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert(toJson()));
    return f.path;
  }
}
