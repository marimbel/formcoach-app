// Checks that the Dart geometry / smoothing / rep counting match the Python code used to build the
// training data. Regenerate the fixture with formcoach-models/scripts/export_parity_fixture.py.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/vision/form_classifier.dart';
import 'package:formcoach/vision/geometry.dart';
import 'package:formcoach/vision/temporal.dart';

void main() {
  final fx = jsonDecode(File('test/fixtures/parity.json').readAsStringSync()) as Map<String, dynamic>;

  Pose33 toPose(List raw) =>
      [for (final l in raw) Lm((l[0] as num).toDouble(), (l[1] as num).toDouble(), (l[2] as num).toDouble())];

  void close(double got, dynamic want, String what) {
    if (want == null) {
      expect(got.isNaN, isTrue, reason: '$what should be NaN/null, got $got');
    } else {
      expect(got, closeTo((want as num).toDouble(), 2e-3), reason: what);
    }
  }

  test('features and primary angles match Python', () {
    for (final (i, p) in (fx['poses'] as List).indexed) {
      final pose = toPose(p['landmarks'] as List);
      final ex = p['exercise'] as String;
      close(primaryAngle(pose, 'knee', 'mean'), p['knee_mean'], 'pose $i knee mean');
      close(primaryAngle(pose, 'knee', 'min'), p['knee_min'], 'pose $i knee min');
      close(primaryAngle(pose, 'elbow', 'mean'), p['elbow_mean'], 'pose $i elbow mean');
      final want = Map<String, dynamic>.from(p['features'] as Map);
      expect(estimateView(pose), want.remove('view'), reason: 'pose $i view');
      final got = frameFeatures(pose, ex);
      expect(got.keys.toSet(), want.keys.toSet(), reason: 'pose $i feature names');
      for (final k in want.keys) {
        close(got[k]!, want[k], 'pose $i $k');
      }
      final box = personBox(pose);
      final wb = (p['box'] as List).map((e) => (e as num).toDouble()).toList();
      expect(box.left, closeTo(wb[0], 1.0), reason: 'pose $i box left');
      expect(box.top, closeTo(wb[1], 1.0), reason: 'pose $i box top');
      expect(box.side, closeTo(wb[2] - wb[0], 1.0), reason: 'pose $i box side');
    }
  });

  test('rep counter finds the same reps', () {
    final r = fx['rep_signal'] as Map<String, dynamic>;
    final fps = (r['fps'] as num).toDouble();
    final cfg = r['config'] as Map<String, dynamic>;
    final rc = RepCounter(
        top: (cfg['top'] as num).toDouble(),
        bottomEnter: (cfg['bottom_enter'] as num).toDouble(),
        minRepSeconds: (cfg['min_rep_seconds'] as num).toDouble());
    final found = <RepInfo>[];
    final angles = (r['angles'] as List).map((e) => e == null ? double.nan : (e as num).toDouble()).toList();
    for (var i = 0; i < angles.length; i++) {
      final ev = rc.update(angles[i], i / fps);
      if (ev.completed != null) found.add(ev.completed!);
    }
    final want = r['reps'] as List;
    expect(found.length, want.length);
    for (var k = 0; k < want.length; k++) {
      expect((found[k].bottomT * fps).round(), want[k]['bottom']);
      expect((found[k].endT * fps).round(), want[k]['end']);
      expect(found[k].minAngle, closeTo((want[k]['min'] as num).toDouble(), 1e-3));
    }
  });

  test('One Euro filter matches', () {
    final e = fx['one_euro'] as Map<String, dynamic>;
    final f = OneEuro();
    final xs = (e['x'] as List).map((v) => (v as num).toDouble()).toList();
    final ys = (e['y'] as List).map((v) => (v as num).toDouble()).toList();
    for (var i = 0; i < xs.length; i++) {
      expect(f(xs[i], i * (e['t_step'] as num).toDouble()), closeTo(ys[i], 1e-6));
    }
  });

  test('masked average keeps only the selected exercise', () {
    final names = ['squat__correct', 'squat__knee_valgus', 'lunge__correct'];
    final p = FormClassifier.maskedAverage([
      [0.2, 0.2, 0.6],
      [0.1, 0.3, 0.6]
    ], [0, 1], names);
    expect(p.keys, ['correct', 'knee_valgus']);
    expect(p['correct']! + p['knee_valgus']!, closeTo(1.0, 1e-9));
    expect(p['knee_valgus'], closeTo(0.625, 1e-9));
  });
}
