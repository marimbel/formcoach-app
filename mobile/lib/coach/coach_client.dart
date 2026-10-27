// Talks to the Cloud Run backend: Model B (fine-tuned Gemini coach) and Model D (trainer images).
// If the backend is unreachable, the app falls back to local cues so a workout never stalls.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/app_config.dart';
import 'local_cues.dart';

class CoachReply {
  final String action; // coach | praise | reposition | hold
  final String? error, severity, visualPrompt;
  final String cue, explanation, source;
  final double? modelLatencyMs;

  const CoachReply({
    required this.action,
    this.error,
    this.severity,
    this.visualPrompt,
    required this.cue,
    required this.explanation,
    required this.source,
    this.modelLatencyMs,
  });

  factory CoachReply.fromJson(Map<String, dynamic> j) => CoachReply(
        action: j['action'] as String,
        error: j['error'] as String?,
        severity: j['severity'] as String?,
        visualPrompt: j['visual_prompt'] as String?,
        cue: (j['cue'] ?? '') as String,
        explanation: (j['explanation'] ?? '') as String,
        source: (j['source'] ?? 'unknown') as String,
        modelLatencyMs: (j['model_latency_ms'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'action': action,
        'error': error,
        'severity': severity,
        'visual_prompt': visualPrompt,
        'cue': cue,
        'explanation': explanation,
        'source': source,
        'model_latency_ms': modelLatencyMs,
      };
}

class TrainerImage {
  final Uint8List? bytes;
  final String source, prompt;
  const TrainerImage(this.bytes, this.source, this.prompt);
}

class CoachClient {
  final String baseUrl;
  final String key;
  final http.Client _http = http.Client();
  CoachClient({this.baseUrl = backendUrl, this.key = apiKey});

  Map<String, String> get _headers => {'content-type': 'application/json', if (key.isNotEmpty) 'x-api-key': key};

  /// model: 'tuned' | 'base' | 'mock' (base lets you demo the base-vs-tuned comparison live).
  Future<CoachReply> coach(Map<String, dynamic> situation,
      {Uint8List? jpeg, String model = 'tuned', String sessionId = ''}) async {
    try {
      final r = await _http
          .post(Uri.parse('$baseUrl/v1/coach'),
              headers: _headers,
              body: jsonEncode({
                'session_id': sessionId,
                'situation': situation,
                'model': model,
                if (jpeg != null) 'image_jpeg_b64': base64Encode(jpeg),
              }))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return CoachReply.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
      return localReply(situation, 'offline:http_${r.statusCode}');
    } on TimeoutException {
      return localReply(situation, 'offline:timeout');
    } catch (e) {
      return localReply(situation, 'offline:${e.runtimeType}');
    }
  }

  Future<TrainerImage> trainerImage(String exercise, String error, String? visualPrompt) async {
    try {
      final r = await _http
          .post(Uri.parse('$baseUrl/v1/trainer-image'),
              headers: _headers,
              body: jsonEncode({'exercise': exercise, 'error': error, 'visual_prompt': visualPrompt}))
          .timeout(const Duration(seconds: 40));
      if (r.statusCode != 200) return TrainerImage(null, 'http_${r.statusCode}', '');
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final b64 = j['image_b64'] as String?;
      return TrainerImage(b64 == null ? null : base64Decode(b64), j['source'] as String, j['prompt'] as String);
    } catch (e) {
      return TrainerImage(null, 'offline', '');
    }
  }
}
