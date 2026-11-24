// Human-friendly names, tips and key points for each form error (labels.json error ids).

class FormErrorInfo {
  final String title; // shown on the live alert card, e.g. "Knees moving inward"
  final String tip; // one sentence for the session summary
  final List<String> keyPoints; // Visual Trainer checklist
  const FormErrorInfo(this.title, this.tip, this.keyPoints);
}

const formErrors = <String, FormErrorInfo>{
  'knee_valgus': FormErrorInfo('Knees moving inward', 'Try to keep your knees aligned with your feet', [
    'Keep your knees aligned with your feet',
    'Push your knees slightly outward',
    'Keep your chest upright',
    'Go to a comfortable depth',
  ]),
  'forward_lean': FormErrorInfo('Leaning too far forward', 'Keep your chest up as you lower', [
    'Brace your core before each rep',
    'Keep your chest up and eyes forward',
    'Sit your hips back and down, not just back',
    'Keep your weight over the middle of your feet',
  ]),
  'insufficient_depth': FormErrorInfo('Not deep enough', 'Focus on going a little deeper', [
    'Lower until your thighs are close to parallel',
    'Control the way down; don\'t drop',
    'Keep your heels on the floor at the bottom',
    'Only go as deep as is comfortable',
  ]),
  'heel_lift': FormErrorInfo('Heels lifting', 'Keep your heels down through the whole rep', [
    'Press through your whole foot',
    'Shift your weight slightly back toward your heels',
    'Widen your stance a little if needed',
    'Reduce depth until your heels stay down',
  ]),
  'knee_alignment': FormErrorInfo('Front knee too far forward', 'Keep your front knee over your ankle', [
    'Take a slightly longer step',
    'Keep your front knee above your ankle',
    'Drop your back knee straight down',
    'Keep your torso tall',
  ]),
  'hip_sag': FormErrorInfo('Hips sagging', 'Keep a straight line from head to heels', [
    'Squeeze your glutes and brace your core',
    'Keep your hips in line with your shoulders and heels',
    'Look at the floor just ahead of your hands',
    'Drop to your knees if you can\'t hold the line',
  ]),
  'elbow_flare': FormErrorInfo('Elbows flaring out', 'Tuck your elbows to about 45 degrees', [
    'Keep elbows about 45° from your body',
    'Hands just wider than your shoulders',
    'Point your elbows back, not out to the sides',
    'Keep wrists under your shoulders',
  ]),
  'partial_rom': FormErrorInfo('Not going low enough', 'Lower your chest closer to the floor', [
    'Bend your elbows to 90° or less',
    'Lower until your chest is a fist above the floor',
    'Push back up until your arms are straight',
    'Move slowly and under control',
  ]),
};

FormErrorInfo infoFor(String? error) =>
    formErrors[error] ??
    FormErrorInfo((error ?? 'Form issue').replaceAll('_', ' '), 'Focus on your form', const ['Move slowly and under control']);

/// Tips shown on the Form Tips screen, per exercise.
const exerciseTips = <String, List<String>>{
  'squat': [
    'Feet shoulder-width apart, toes slightly out',
    'Knees track over your toes',
    'Chest up, back neutral',
    'Hips to about knee height',
    'Heels stay on the floor',
  ],
  'lunge': [
    'Step long enough that your front knee stays over your ankle',
    'Lower your back knee straight down',
    'Keep your torso tall',
    'Push through your front heel to stand',
  ],
  'push_up': [
    'Hands just wider than your shoulders',
    'Straight line from head to heels',
    'Elbows about 45° from your body',
    'Lower until your elbows reach 90°',
    'Push all the way back up',
  ],
};
