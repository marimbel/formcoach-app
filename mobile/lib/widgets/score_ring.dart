// The 0-100 form score ring used on the Session Summary and the score pills on History.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Green from 70, amber from 50, red below.
Color scoreColor(BuildContext context, int score) {
  final fc = context.fc;
  if (score >= 70) return fc.success;
  if (score >= 50) return fc.warning;
  return fc.danger;
}

class ScoreRing extends StatelessWidget {
  final int score;
  final String label;
  final double size;
  const ScoreRing({super.key, required this.score, required this.label, this.size = 148});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(context, score);
    final track = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(score.clamp(0, 100) / 100, color, track, size * 0.075),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$score', style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w700, height: 1.0)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: size * 0.095, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction, stroke;
  final Color color, track;
  _RingPainter(this.fraction, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, 2 * math.pi, false, base..color = track);
    if (fraction > 0) {
      canvas.drawArc(arc, -math.pi / 2, 2 * math.pi * fraction, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track || old.stroke != stroke;
}

/// Small rounded score badge, e.g. on a History row.
class ScorePill extends StatelessWidget {
  final int score;
  const ScorePill({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final c = scoreColor(context, score);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 3)),
      child: Text('$score', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}
