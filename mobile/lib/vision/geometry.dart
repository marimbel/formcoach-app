// Joint angles and form features. MUST mirror formcoach-models/formcoach/geometry.py:
// same names, formulas and units (pixels of the upright image, y down, degrees).
// test/parity_test.dart checks this against fixtures exported from Python.
import 'dart:math' as math;

class Lm {
  final double x, y, v; // pixels, pixels, visibility/likelihood 0..1
  const Lm(this.x, this.y, this.v);
}

typedef Pose33 = List<Lm>;

const int nose = 0;
const int lShoulder = 11, rShoulder = 12, lElbow = 13, rElbow = 14, lWrist = 15, rWrist = 16;
const int lHip = 23, rHip = 24, lKnee = 25, rKnee = 26, lAnkle = 27, rAnkle = 28;
const int lHeel = 29, rHeel = 30, lFoot = 31, rFoot = 32;
const double visThresh = 0.5;

double angleDeg(double ax, double ay, double bx, double by, double cx, double cy) {
  final v1x = ax - bx, v1y = ay - by, v2x = cx - bx, v2y = cy - by;
  final n = math.sqrt(v1x * v1x + v1y * v1y) * math.sqrt(v2x * v2x + v2y * v2y);
  if (n < 1e-9) return double.nan;
  final c = ((v1x * v2x + v1y * v2y) / n).clamp(-1.0, 1.0);
  return math.acos(c) * 180.0 / math.pi;
}

double jointAngle(Pose33 p, int a, int b, int c) =>
    angleDeg(p[a].x, p[a].y, p[b].x, p[b].y, p[c].x, p[c].y);

double _dist(Lm a, Lm b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

bool allVisible(Pose33 p, List<int> idx, [double t = visThresh]) => idx.every((i) => p[i].v >= t);

/// Angle that drives rep counting ('knee' or 'elbow'; combine 'mean' or 'min').
double primaryAngle(Pose33 p, String which, String combine) {
  late List<double> vals, vis;
  if (which == 'knee') {
    vals = [jointAngle(p, lHip, lKnee, lAnkle), jointAngle(p, rHip, rKnee, rAnkle)];
    vis = [
      [p[lHip].v, p[lKnee].v, p[lAnkle].v].reduce(math.min),
      [p[rHip].v, p[rKnee].v, p[rAnkle].v].reduce(math.min),
    ];
  } else {
    vals = [jointAngle(p, lShoulder, lElbow, lWrist), jointAngle(p, rShoulder, rElbow, rWrist)];
    vis = [
      [p[lShoulder].v, p[lElbow].v, p[lWrist].v].reduce(math.min),
      [p[rShoulder].v, p[rElbow].v, p[rWrist].v].reduce(math.min),
    ];
  }
  final ok = <double>[];
  for (var i = 0; i < 2; i++) {
    if (vis[i] >= visThresh && !vals[i].isNaN) ok.add(vals[i]);
  }
  if (ok.isEmpty) return double.nan;
  return combine == 'min' ? ok.reduce(math.min) : ok.reduce((a, b) => a + b) / ok.length;
}

String estimateView(Pose33 p) {
  final sw = _dist(p[lShoulder], p[rShoulder]);
  final msx = (p[lShoulder].x + p[rShoulder].x) / 2, msy = (p[lShoulder].y + p[rShoulder].y) / 2;
  final mhx = (p[lHip].x + p[rHip].x) / 2, mhy = (p[lHip].y + p[rHip].y) / 2;
  final torso = math.sqrt(math.pow(msx - mhx, 2) + math.pow(msy - mhy, 2));
  if (torso < 1e-6) return 'unknown';
  final r = sw / torso;
  if (r > 0.55) return 'front';
  if (r < 0.25) return 'side';
  return 'oblique';
}

double _minOf(List<double> v) {
  final ok = v.where((x) => !x.isNaN).toList();
  return ok.isEmpty ? double.nan : ok.reduce(math.min);
}

double _sign(double v) => v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0);

/// Features at the bottom frame. NaN = not measurable (sent as null).
Map<String, double> frameFeatures(Pose33 p, String exercise) {
  final f = <String, double>{};
  final msx = (p[lShoulder].x + p[rShoulder].x) / 2, msy = (p[lShoulder].y + p[rShoulder].y) / 2;
  final mhx = (p[lHip].x + p[rHip].x) / 2, mhy = (p[lHip].y + p[rHip].y) / 2;
  final ux = msx - mhx, uy = msy - mhy;
  f['trunk_lean_deg'] = (ux * ux + uy * uy) > 0 ? angleDeg(mhx, mhy - 1.0, mhx, mhy, mhx + ux, mhy + uy) : double.nan;

  if (exercise == 'squat' || exercise == 'lunge') {
    final kl = jointAngle(p, lHip, lKnee, lAnkle), kr = jointAngle(p, rHip, rKnee, rAnkle);
    f['knee_angle_left'] = kl;
    f['knee_angle_right'] = kr;
    f['hip_angle_left'] = jointAngle(p, lShoulder, lHip, lKnee);
    f['hip_angle_right'] = jointAngle(p, rShoulder, rHip, rKnee);
    final ankleW = (p[lAnkle].x - p[rAnkle].x).abs();
    final kneeW = (p[lKnee].x - p[rKnee].x).abs();
    f['knee_to_ankle_width'] = ankleW > 1e-6 ? kneeW / ankleW : double.nan;
    final thigh = (_dist(p[lHip], p[lKnee]) + _dist(p[rHip], p[rKnee])) / 2;
    final hipY = (p[lHip].y + p[rHip].y) / 2, kneeY = (p[lKnee].y + p[rKnee].y) / 2;
    f['hip_below_knee'] = thigh > 1e-6 ? (hipY - kneeY) / thigh : double.nan;
    final lifts = <double>[];
    for (final s in const [
      [lHeel, lFoot, lKnee, lAnkle],
      [rHeel, rFoot, rKnee, rAnkle]
    ]) {
      final shank = _dist(p[s[2]], p[s[3]]);
      if (shank > 1e-6 && p[s[0]].v >= visThresh && p[s[1]].v >= visThresh) {
        lifts.add((p[s[1]].y - p[s[0]].y) / shank);
      }
    }
    f['heel_lift'] = lifts.isEmpty ? double.nan : lifts.reduce(math.max);
    final frontLeft = (kl.isNaN ? 999 : kl) <= (kr.isNaN ? 999 : kr);
    final knee = frontLeft ? lKnee : rKnee, ankle = frontLeft ? lAnkle : rAnkle;
    final heel = frontLeft ? lHeel : rHeel, foot = frontLeft ? lFoot : rFoot;
    final shank = _dist(p[knee], p[ankle]);
    var facing = _sign(p[foot].x - p[heel].x);
    if (facing == 0) facing = 1.0;
    f['knee_past_toe'] = shank > 1e-6 ? (p[knee].x - p[foot].x) * facing / shank : double.nan;
  }
  if (exercise == 'chest_press') {
    final el = jointAngle(p, lShoulder, lElbow, lWrist), er = jointAngle(p, rShoulder, rElbow, rWrist);
    f['elbow_angle_left'] = el;
    f['elbow_angle_right'] = er;
    f['elbow_asymmetry_deg'] = (el - er).abs();
    f['shoulder_abduction_left'] = jointAngle(p, lHip, lShoulder, lElbow);
    f['shoulder_abduction_right'] = jointAngle(p, rHip, rShoulder, rElbow);
    final sw = _dist(p[lShoulder], p[rShoulder]);
    f['wrist_height_diff'] = sw > 1e-6 ? (p[lWrist].y - p[rWrist].y).abs() / sw : double.nan;
  }
  return f;
}

/// Same rounding as Python; NaN -> null for JSON.
Map<String, double?> featuresForJson(Map<String, double> f) => f.map(
    (k, v) => MapEntry(k, v.isNaN || v.isInfinite ? null : (v * 1000).roundToDouble() / 1000));

/// Square box around visible landmarks (+15% each side), may extend past the image (padded later).
({double left, double top, double side}) personBox(Pose33 p, {double margin = 0.15}) {
  var pts = p.where((l) => l.v >= visThresh).toList();
  if (pts.length < 4) pts = p;
  var x0 = pts.first.x, x1 = pts.first.x, y0 = pts.first.y, y1 = pts.first.y;
  for (final l in pts) {
    x0 = math.min(x0, l.x);
    x1 = math.max(x1, l.x);
    y0 = math.min(y0, l.y);
    y1 = math.max(y1, l.y);
  }
  final side = math.max(16.0, (math.max(x1 - x0, y1 - y0) * (1 + 2 * margin)).roundToDouble());
  final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  return (left: (cx - side / 2).roundToDouble(), top: (cy - side / 2).roundToDouble(), side: side);
}
