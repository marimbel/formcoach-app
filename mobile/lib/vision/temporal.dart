// Temporal processing: One Euro smoothing of landmarks and the online rep counter.
// Mirrors formcoach-models/formcoach/reps.py.
import 'dart:math' as math;

import 'geometry.dart';

class OneEuro {
  final double minCutoff, beta, dCutoff;
  double? _x, _dx, _t;
  OneEuro({this.minCutoff = 1.5, this.beta = 0.01, this.dCutoff = 1.0});

  static double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double call(double x, double t) {
    if (_x == null) {
      _x = x;
      _dx = 0;
      _t = t;
      return x;
    }
    final dt = math.max(t - _t!, 1e-6);
    final dx = (x - _x!) / dt;
    final ad = _alpha(dCutoff, dt);
    _dx = ad * dx + (1 - ad) * _dx!;
    final a = _alpha(minCutoff + beta * _dx!.abs(), dt);
    _x = a * x + (1 - a) * _x!;
    _t = t;
    return _x!;
  }
}

/// Smooths x/y of all 33 landmarks; visibility passes through.
class PoseSmoother {
  final _fx = List.generate(33, (_) => OneEuro());
  final _fy = List.generate(33, (_) => OneEuro());

  Pose33 call(Pose33 raw, double t) =>
      List.generate(33, (i) => Lm(_fx[i](raw[i].x, t), _fy[i](raw[i].y, t), raw[i].v));
}

class RepEvent {
  final bool enteredDown; // started a new descent: clear snapshots
  final bool newMin; // deepest point so far in this rep: snapshot this frame
  final RepInfo? completed;
  const RepEvent({this.enteredDown = false, this.newMin = false, this.completed});
}

class RepInfo {
  final double startT, bottomT, endT, minAngle;
  const RepInfo(this.startT, this.bottomT, this.endT, this.minAngle);
}

/// UP --(angle < bottomEnter)--> DOWN (track min) --(angle > top, long enough)--> UP + emit rep.
class RepCounter {
  final double top, bottomEnter, minRepSeconds;
  String state = 'init';
  double _start = 0, _bottomT = 0, _min = double.infinity;
  int count = 0;
  RepCounter({required this.top, required this.bottomEnter, required this.minRepSeconds});

  bool get inDown => state == 'down';

  RepEvent update(double a, double t) {
    if (a.isNaN) return const RepEvent();
    switch (state) {
      case 'init':
        if (a > top) {
          state = 'up';
          _start = t;
        }
        return const RepEvent();
      case 'up':
        if (a > top) {
          _start = t;
        } else if (a < bottomEnter) {
          state = 'down';
          _min = a;
          _bottomT = t;
          return const RepEvent(enteredDown: true, newMin: true);
        }
        return const RepEvent();
      default: // down
        var nm = false;
        if (a < _min) {
          _min = a;
          _bottomT = t;
          nm = true;
        }
        if (a > top) {
          final ok = (t - _start) >= minRepSeconds;
          final info = RepInfo(_start, _bottomT, t, _min);
          state = 'up';
          _start = t;
          if (ok) {
            count++;
            return RepEvent(completed: info);
          }
        }
        return RepEvent(newMin: nm);
    }
  }

  void reset() {
    state = 'init';
    count = 0;
    _min = double.infinity;
  }
}

/// "Can we see the body well enough?" with hysteresis so one bad frame doesn't nag the user.
class VisibilityGate {
  final List<int> requiredIdx;
  final double gateSeconds;
  double? _badSince;
  VisibilityGate(this.requiredIdx, {this.gateSeconds = 1.0});

  /// Returns true when the user should be asked to reposition.
  bool update(Pose33? p, double t) {
    final ok = p != null && allVisible(p, requiredIdx);
    if (ok) {
      _badSince = null;
      return false;
    }
    _badSince ??= t;
    return t - _badSince! >= gateSeconds;
  }

  double meanVisibility(Pose33 p) =>
      requiredIdx.map((i) => p[i].v).reduce((a, b) => a + b) / requiredIdx.length;
}
