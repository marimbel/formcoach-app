import 'package:flutter/material.dart';

import '../coach/coach_client.dart';
import '../models/form_errors.dart';
import '../theme.dart';

/// Mockup screen 3: Visual Trainer / Correction. Image from Model D (via the backend).
class TrainerScreen extends StatefulWidget {
  final CoachClient client;
  final String exercise, error;
  final String? visualPrompt, explanation;
  const TrainerScreen({
    super.key,
    required this.client,
    required this.exercise,
    required this.error,
    this.visualPrompt,
    this.explanation,
  });

  /// From a live coaching reply.
  factory TrainerScreen.fromReply({required CoachClient client, required String exercise, required CoachReply reply}) =>
      TrainerScreen(
          client: client,
          exercise: exercise,
          error: reply.error ?? '',
          visualPrompt: reply.visualPrompt,
          explanation: reply.explanation);

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

  void _load() => _future = widget.client.trainerImage(widget.exercise, widget.error, widget.visualPrompt);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fc = context.fc;
    final info = infoFor(widget.error);
    final exName = widget.exercise.replaceAll('_', ' ');
    return Scaffold(
      appBar: AppBar(title: const Text('Form Correction')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Here is an example of the correct $exName form:', style: t.bodyMedium),
              const SizedBox(height: 12),
              AspectRatio(aspectRatio: 3 / 4, child: _image()),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Key Points', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final k in info.keyPoints)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_circle, color: fc.success, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Text(k, style: t.bodyLarge)),
                  ]),
                ),
            ]),
          ),
        ),
        if ((widget.explanation ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Icon(Icons.insights, color: Theme.of(context).colorScheme.primary),
              title: const Text('What the coach saw'),
              subtitle: Text(widget.explanation!),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
      ]),
    );
  }

  Widget _image() {
    final fc = context.fc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: fc.successSoft,
        child: FutureBuilder<TrainerImage>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Drawing the correct form…'),
                ]),
              );
            }
            final img = snap.data;
            if (img?.bytes == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.image_not_supported_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    const Text("Couldn't load the illustration. The key points below still apply.", textAlign: TextAlign.center),
                    TextButton(onPressed: () => setState(_load), child: const Text('Try again')),
                  ]),
                ),
              );
            }
            return Stack(fit: StackFit.expand, children: [
              Image.memory(img!.bytes!,
                  fit: BoxFit.cover, semanticLabel: 'Illustration of correct ${widget.exercise.replaceAll('_', ' ')} form'),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: fc.success, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Correct Form', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Text('AI illustration', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
