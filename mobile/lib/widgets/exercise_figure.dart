// Small drawn figures of each exercise for the Home cards and summary header,
// in the same style as the live skeleton overlay (no image assets needed).
import 'package:flutter/material.dart';

class ExerciseFigure extends StatelessWidget {
  final String exercise;
  final double size;
  const ExerciseFigure({super.key, required this.exercise, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FigurePainter(exercise, body: cs.onSurface, accent: cs.primary)),
    );
  }
}

// Poses in a 100x100 box: head, shoulder, elbow, wrist, hip, knee, ankle, toe (+ second leg for lunge).
const _poses = <String, Map<String, Offset>>{
  'squat': {
    'head': Offset(44, 16), 'shoulder': Offset(42, 30), 'elbow': Offset(62, 33), 'wrist': Offset(82, 33),
    'hip': Offset(28, 56), 'knee': Offset(56, 62), 'ankle': Offset(50, 88), 'toe': Offset(62, 90),
  },
  'lunge': {
    'head': Offset(47, 13), 'shoulder': Offset(47, 27), 'elbow': Offset(45, 40), 'wrist': Offset(43, 52),
    'hip': Offset(47, 52), 'knee': Offset(68, 64), 'ankle': Offset(69, 88), 'toe': Offset(80, 90),
    'knee2': Offset(32, 80), 'ankle2': Offset(14, 84), 'toe2': Offset(8, 90),
  },
  'push_up': {
    'head': Offset(12, 58), 'shoulder': Offset(24, 64), 'elbow': Offset(36, 76), 'wrist': Offset(26, 88),
    'hip': Offset(56, 70), 'knee': Offset(74, 76), 'ankle': Offset(90, 82), 'toe': Offset(94, 88),
  },
};

class _FigurePainter extends CustomPainter {
  final String exercise;
  final Color body, accent;
  _FigurePainter(this.exercise, {required this.body, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final p = _poses[exercise] ?? _poses['squat']!;
    final s = size.width / 100;
    Offset o(String k) => p[k]! * s;
    final limb = Paint()
      ..color = body
      ..strokeWidth = 7 * s
      ..strokeCap = StrokeCap.round;
    final torso = Paint()
      ..color = accent
      ..strokeWidth = 9 * s
      ..strokeCap = StrokeCap.round;

    if (exercise == 'push_up') {
      final floor = Paint()
        ..color = body.withValues(alpha: 0.35)
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(6 * s, 92 * s), Offset(96 * s, 92 * s), floor);
    }
    if (p.containsKey('knee2')) {
      canvas.drawLine(o('hip'), o('knee2'), limb);
      canvas.drawLine(o('knee2'), o('ankle2'), limb);
      canvas.drawLine(o('ankle2'), o('toe2'), limb);
    }
    canvas.drawLine(o('hip'), o('knee'), limb);
    canvas.drawLine(o('knee'), o('ankle'), limb);
    canvas.drawLine(o('ankle'), o('toe'), limb);
    canvas.drawLine(o('shoulder'), o('hip'), torso);
    canvas.drawLine(o('shoulder'), o('elbow'), limb);
    canvas.drawLine(o('elbow'), o('wrist'), limb);
    canvas.drawCircle(o('head'), 7 * s, Paint()..color = body);
    final joint = Paint()..color = accent;
    for (final k in ['knee', 'elbow', 'hip']) {
      canvas.drawCircle(o(k), 3.2 * s, joint);
    }
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) =>
      old.exercise != exercise || old.body != body || old.accent != accent;
}
