import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Backend settings come from --dart-define so no secrets are committed:
///   flutter run --dart-define=BACKEND_URL=https://formcoach-api-xxxx.run.app --dart-define=API_KEY=...
const backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://10.0.2.2:8080');
const apiKey = String.fromEnvironment('API_KEY', defaultValue: '');

class ExerciseConfig {
  final String id, display, cameraHint;
  final List<String> errors;
  final String angle, combine;
  final double top, bottomEnter, minRepSeconds;
  final List<int> requiredLandmarks;

  ExerciseConfig.fromJson(this.id, Map<String, dynamic> j)
      : display = j['display'],
        cameraHint = j['camera_hint'],
        errors = List<String>.from(j['errors']),
        angle = j['rep']['angle'],
        combine = j['rep']['combine'],
        top = (j['rep']['top'] as num).toDouble(),
        bottomEnter = (j['rep']['bottom_enter'] as num).toDouble(),
        minRepSeconds = (j['rep']['min_rep_seconds'] as num).toDouble(),
        requiredLandmarks = List<int>.from(j['required_landmarks']);
}

/// Loaded from assets/config/labels.json (copied from formcoach-models/configs).
class LabelsConfig {
  final Map<String, ExerciseConfig> exercises;
  final double errorMinProb, speakCooldownSeconds, gateSeconds;

  LabelsConfig._(this.exercises, this.errorMinProb, this.speakCooldownSeconds, this.gateSeconds);

  /// Global class order = Model A output order: '<exercise>__<error>'.
  List<String> get classNames => [
        for (final e in exercises.values)
          for (final err in e.errors) '${e.id}__$err'
      ];

  List<int> indicesFor(String exercise) {
    final names = classNames;
    return [for (var i = 0; i < names.length; i++) if (names[i].startsWith('${exercise}__')) i];
  }

  static Future<LabelsConfig> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/config/labels.json')) as Map<String, dynamic>;
    final ex = <String, ExerciseConfig>{};
    (j['exercises'] as Map<String, dynamic>).forEach((k, v) => ex[k] = ExerciseConfig.fromJson(k, v));
    final t = j['thresholds'] as Map<String, dynamic>;
    return LabelsConfig._(ex, (t['error_min_prob'] as num).toDouble(),
        (t['speak_cooldown_seconds'] as num).toDouble(), (t['gate_seconds'] as num).toDouble());
  }
}
