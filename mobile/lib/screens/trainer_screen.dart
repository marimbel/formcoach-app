import 'package:flutter/material.dart';

import '../coach/coach_client.dart';

/// Model D: AI-generated illustration of the corrected form.
class TrainerScreen extends StatefulWidget {
  final CoachClient client;
  final String exercise;
  final CoachReply reply;
  const TrainerScreen({super.key, required this.client, required this.exercise, required this.reply});

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  late Future<TrainerImage> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = widget.client.trainerImage(widget.exercise, widget.reply.error!, widget.reply.visualPrompt);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Correct form')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.reply.cue, style: t.headlineSmall),
        const SizedBox(height: 8),
        Text(widget.reply.explanation, style: t.bodyLarge),
        const SizedBox(height: 16),
        FutureBuilder<TrainerImage>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 360,
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Drawing your visual trainer… (can take ~10 s)'),
                ])),
              );
            }
            final img = snap.data;
            if (img?.bytes == null) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.image_not_supported),
                  title: const Text("Couldn't create the illustration"),
                  subtitle: const Text('Use the spoken cue above. You can retry.'),
                  trailing: TextButton(onPressed: () => setState(_load), child: const Text('Retry')),
                ),
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(img!.bytes!, fit: BoxFit.contain,
                    semanticLabel: 'Illustration of correct ${widget.exercise.replaceAll('_', ' ')} form'),
              ),
              const SizedBox(height: 8),
              Text('AI-generated illustration (${img.source}). It may contain mistakes; follow the cue if they disagree.',
                  style: t.bodySmall),
            ]);
          },
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to workout')),
      ]),
    );
  }
}
