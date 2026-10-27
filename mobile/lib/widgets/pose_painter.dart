import 'package:flutter/material.dart';

import '../vision/geometry.dart';

const _edges = [
  [11, 12], [11, 23], [12, 24], [23, 24], // torso
  [11, 13], [13, 15], [12, 14], [14, 16], // arms
  [23, 25], [25, 27], [24, 26], [26, 28], // legs
  [27, 29], [29, 31], [28, 30], [30, 32], // feet
];

/// Draws the smoothed skeleton over the camera preview. Landmarks are in upright-image pixels;
/// the front-camera preview is mirrored, so x is flipped to line up with what the user sees.
class PosePainter extends CustomPainter {
  final Pose33? pose;
  final Size? imageSize;
  final bool mirror;
  final Set<int> highlight; // joints involved in the current error
  final List<int> requiredJoints;

  PosePainter({required this.pose, required this.imageSize, required this.mirror,
      this.highlight = const {}, this.requiredJoints = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose, img = imageSize;
    if (p == null || img == null) return;
    final sx = size.width / img.width, sy = size.height / img.height;
    Offset o(Lm l) => Offset(mirror ? size.width - l.x * sx : l.x * sx, l.y * sy);
    final bone = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final e in _edges) {
      if (p[e[0]].v < visThresh || p[e[1]].v < visThresh) continue;
      canvas.drawLine(o(p[e[0]]), o(p[e[1]]), bone);
    }
    for (var i = 11; i < 33; i++) {
      final l = p[i];
      final hidden = l.v < visThresh;
      if (hidden && !requiredJoints.contains(i)) continue;
      final color = hidden ? Colors.redAccent : (highlight.contains(i) ? Colors.amber : Colors.lightGreenAccent);
      canvas.drawCircle(o(l), highlight.contains(i) ? 9 : 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter old) => true;
}

/// Joints to highlight for a given error (visual feedback on the skeleton).
Set<int> jointsFor(String? error) {
  switch (error) {
    case 'knee_valgus':
    case 'knee_alignment':
      return {25, 26, 27, 28};
    case 'forward_lean':
      return {11, 12, 23, 24};
    case 'insufficient_depth':
      return {23, 24, 25, 26};
    case 'heel_lift':
      return {29, 30, 31, 32};
    case 'elbow_flare':
    case 'partial_rom':
      return {13, 14};
    case 'uneven_arms':
      return {13, 14, 15, 16};
    default:
      return {};
  }
}
