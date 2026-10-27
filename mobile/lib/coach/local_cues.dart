// Offline fallback: a tiny version of the rule-based coach (backend/app/coaching_kb.py), used only
// when the backend can't be reached. Kept deliberately simple; the real coaching is Model B.
import 'coach_client.dart';

const _cues = {
  'squat__knee_valgus': 'Push your knees out over your toes.',
  'squat__forward_lean': 'Keep your chest up as you sit back.',
  'squat__insufficient_depth': 'Sit lower, hips to knee height.',
  'squat__heel_lift': 'Keep your heels down through the rep.',
  'lunge__knee_alignment': 'Keep your front knee above your ankle.',
  'lunge__forward_lean': 'Stay tall through your torso.',
  'lunge__insufficient_depth': 'Lower your back knee closer to the floor.',
  'chest_press__elbow_flare': 'Tuck your elbows to about 45 degrees.',
  'chest_press__uneven_arms': 'Press both arms at the same speed.',
  'chest_press__partial_rom': 'Lower the weights all the way down.',
};

CoachReply localReply(Map<String, dynamic> s, String source) {
  final q = s['pose_quality'] as Map<String, dynamic>;
  if (q['required_visible'] != true || (q['visibility'] as num) < 0.6) {
    return CoachReply(
        action: 'reposition', cue: 'Adjust the camera so your whole body is visible.',
        explanation: 'Key joints were not clearly visible.', source: source);
  }
  final ma = s['model_a'] as Map<String, dynamic>;
  final err = ma['top_error'] as String;
  final p = (ma['top_prob'] as num).toDouble();
  if (p < 0.5) {
    return CoachReply(action: 'hold', cue: '', explanation: 'Not confident enough to correct.', source: source);
  }
  if (err == 'correct') {
    return CoachReply(action: 'praise', cue: 'Good rep.', explanation: 'Classified as correct form.', source: source);
  }
  final cue = _cues['${s['exercise']}__$err'] ?? 'Focus on your form.';
  return CoachReply(
      action: 'coach', error: err, severity: p > 0.7 ? 'medium' : 'low', cue: cue,
      explanation: 'Model A flagged ${err.replaceAll('_', ' ')} (${(p * 100).round()}%).', source: source);
}
