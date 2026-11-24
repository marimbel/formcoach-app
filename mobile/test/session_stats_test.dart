import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/models/session_stats.dart';

Map<String, dynamic> rep(String action, [String? error]) => {
      'reply': {'action': action, 'error': error, 'cue': 'x', 'source': 'mock'},
    };

void main() {
  test('counts reps, issues and the most common issue like the mockup', () {
    final log = {
      'exercise': 'squat',
      'started': '2026-11-14T10:32:00',
      'reps': [
        for (var i = 0; i < 6; i++) rep('praise'),
        rep('hold'),
        rep('hold'),
        rep('coach', 'knee_valgus'),
        rep('coach', 'knee_valgus'),
        rep('coach', 'insufficient_depth'),
        rep('coach', 'forward_lean'),
      ],
    };
    final s = SessionStats.fromLog(log);
    expect(s.totalReps, 12);
    expect(s.correctReps, 8);
    expect(s.issueReps, 4);
    expect(s.mostCommon!.key, 'knee_valgus');
    expect(s.percentOfReps(s.mostCommon!.value), 17);
    expect(s.otherIssues.map((e) => e.key), containsAll(['insufficient_depth', 'forward_lean']));
    expect(s.feedbackTitle, 'Good effort!');
    expect(s.feedbackBody, startsWith('Try to keep your knees aligned with your feet and '));
    expect(formatSessionDate(DateTime(2026, 11, 14, 10, 32)), 'November 14, 2026  10:32 AM');
    expect(s.formScore, 67); // 8 good of 12 judged
    expect(s.scoreLabel, 'Fair');
  });

  test('empty and perfect sessions', () {
    expect(SessionStats.fromLog({'exercise': 'lunge', 'reps': []}).feedbackTitle, 'No reps recorded');
    final perfect = SessionStats.fromLog({'exercise': 'lunge', 'reps': [rep('praise'), rep('praise')]});
    expect(perfect.issueReps, 0);
    expect(perfect.mostCommon, isNull);
    expect(perfect.feedbackTitle, 'Great work!');
    expect(perfect.formScore, 100);
    expect(perfect.scoreLabel, 'Excellent');
    expect(SessionStats.fromLog({'exercise': 'lunge', 'reps': []}).hasScore, isFalse);
  });
}
