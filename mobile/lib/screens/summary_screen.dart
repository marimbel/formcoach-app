import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../coach/session_log.dart';

class SummaryScreen extends StatelessWidget {
  final SessionLog log;
  final String savedPath;
  const SummaryScreen({super.key, required this.log, required this.savedPath});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stats = log.stats();
    final errorCounts = <String, int>{};
    var correct = 0;
    for (final r in log.reps) {
      final reply = r.reply ?? {};
      if (reply['action'] == 'coach' && reply['error'] != null) {
        final e = reply['error'] as String;
        errorCounts[e] = (errorCounts[e] ?? 0) + 1;
      } else if (reply['action'] == 'praise') {
        correct++;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Session summary'), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${log.reps.length} reps', style: t.displaySmall),
        Text('$correct with good form', style: t.titleMedium),
        const SizedBox(height: 16),
        if (errorCounts.isNotEmpty) ...[
          Text('What to work on', style: t.titleLarge),
          for (final e in (errorCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
            ListTile(
                dense: true,
                leading: const Icon(Icons.flag),
                title: Text(e.key.replaceAll('_', ' ')),
                trailing: Text('${e.value} reps')),
          const SizedBox(height: 8),
        ],
        Text('Rep by rep', style: t.titleLarge),
        for (final r in log.reps)
          ListTile(
            dense: true,
            leading: CircleAvatar(child: Text('${r.index}')),
            title: Text((r.reply?['cue'] as String?)?.isNotEmpty == true ? r.reply!['cue'] : '(no cue)'),
            subtitle: Text('Model A: ${r.situation['model_a']['top_error']} '
                '${((r.situation['model_a']['top_prob'] as num) * 100).round()}% · ${r.reply?['source']}'),
          ),
        const Divider(),
        ExpansionTile(
          title: const Text('Performance (for evaluation)'),
          children: [
            for (final e in stats.entries) ListTile(dense: true, title: Text(e.key), trailing: Text('${e.value}')),
            ListTile(dense: true, title: const Text('Log file'), subtitle: Text(savedPath)),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent(' ').convert(log.toJson())));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session log copied')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy session log (JSON)'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text('Done')),
      ]),
    );
  }
}
