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
  'elbow_flare': FormErrorInfo('Elbows flaring out', 'Tuck your elbows to about 45 degrees', [
    'Keep elbows about 45° from your body',
    'Lower the weights toward your mid-chest',
    'Squeeze your shoulder blades together',
    'Keep wrists stacked over elbows',
  ]),
  'uneven_arms': FormErrorInfo('Arms moving unevenly', 'Press both arms at the same speed', [
    'Press both weights at the same speed',
    'Keep the weights level with each other',
    'Use a weight you can control on both sides',
    'Pause briefly at the bottom',
  ]),
  'partial_rom': FormErrorInfo('Partial range of motion', 'Use your full range of motion', [
    'Lower until your upper arms are level with your body',
    'Press until your arms are straight',
    'Move slowly and under control',
    'Lighten the weight if you can\'t reach full range',
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
  'chest_press': [
    'Elbows about 45° from your body',
    'Lower the weights to chest level',
    'Press both arms evenly',
    'Keep your back and feet steady',
  ],
};
