// Numbers for the Session Summary and History screens, computed from a saved session log
// (SessionLog.toJson() / the formcoach_<id>.json files).
import 'form_errors.dart';

class SessionStats {
  final String exercise;
  final DateTime started;
  final int totalReps, correctReps, issueReps;
  final List<MapEntry<String, int>> issues; // error -> rep count, most common first

  SessionStats._(this.exercise, this.started, this.totalReps, this.correctReps, this.issueReps, this.issues);

  factory SessionStats.fromLog(Map<String, dynamic> log) {
    final reps = (log['reps'] as List? ?? const []).cast<Map>();
    var correct = 0, issue = 0;
    final counts = <String, int>{};
    for (final r in reps) {
      final reply = (r['reply'] as Map?) ?? const {};
      final action = reply['action'];
      final error = reply['error'];
      if (action == 'coach' && error is String) {
        issue++;
        counts[error] = (counts[error] ?? 0) + 1;
      } else if (action == 'praise' || action == 'hold') {
        correct++; // no problem was flagged on this rep
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return SessionStats._(
      (log['exercise'] ?? 'squat') as String,
      DateTime.tryParse((log['started'] ?? '') as String) ?? DateTime.now(),
      reps.length,
      correct,
      issue,
      sorted,
    );
  }

  MapEntry<String, int>? get mostCommon => issues.isEmpty ? null : issues.first;
  List<MapEntry<String, int>> get otherIssues => issues.length > 1 ? issues.sublist(1) : const [];

  int percentOfReps(int n) => totalReps == 0 ? 0 : (100 * n / totalReps).round();

  String get feedbackTitle {
    if (totalReps == 0) return 'No reps recorded';
    if (issueReps == 0) return 'Great work!';
    if (correctReps >= issueReps) return 'Good effort!';
    return 'Keep practicing!';
  }

  String get feedbackBody {
    if (totalReps == 0) {
      return 'Start from a standing position with your whole body in view, then do your reps.';
    }
    if (issueReps == 0) return 'No form problems were flagged. Keep it up, or try a few more reps.';
    final tips = issues.take(2).map((e) => infoFor(e.key).tip).toList();
    if (tips.length == 1) return '${tips[0]}.';
    return '${tips[0]} and ${tips[1][0].toLowerCase()}${tips[1].substring(1)}.';
  }
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October',
  'November', 'December'];

/// "November 14, 2026  10:32 AM"
String formatSessionDate(DateTime d) {
  final l = d.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  return '${_months[l.month - 1]} ${l.day}, ${l.year}  $h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
}

String exerciseName(String id) => switch (id) {
      'squat' => 'Squat',
      'lunge' => 'Lunge',
      'chest_press' => 'Chest Press',
      _ => id.replaceAll('_', ' '),
    };
