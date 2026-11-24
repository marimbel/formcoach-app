import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/app_settings.dart';
import '../theme.dart';
import 'info_screens.dart';

/// Mockup screen 5: Settings.
class SettingsScreen extends StatelessWidget {
  final AppSettings settings;
  final LabelsConfig config;
  const SettingsScreen({super.key, required this.settings, required this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const _Header('App Preferences'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Audio Feedback'),
            subtitle: const Text('Speak a cue after each rep'),
            value: settings.audioFeedback,
            onChanged: settings.setAudio,
          ),
          _Row(
            icon: Icons.videocam_outlined,
            title: 'Camera View',
            value: settings.frontCamera ? 'Front' : 'Back',
            onTap: () => _choose<bool>(context, 'Camera View', {true: 'Front', false: 'Back'}, settings.frontCamera,
                settings.setFrontCamera),
          ),
          _Row(
            icon: Icons.palette_outlined,
            title: 'Display Style',
            value: switch (settings.themeMode) { ThemeMode.dark => 'Dark', ThemeMode.system => 'System', _ => 'Light' },
            onTap: () => _choose<ThemeMode>(context, 'Display Style',
                {ThemeMode.light: 'Light', ThemeMode.dark: 'Dark', ThemeMode.system: 'Match phone'}, settings.themeMode,
                settings.setTheme),
          ),
          const _Header('Account'),
          _Row(
            icon: Icons.person_outline,
            title: 'Profile',
            value: settings.profileName.isEmpty ? null : settings.profileName,
            onTap: () => _editName(context),
          ),
          const _Header('About'),
          _Row(
            icon: Icons.info_outline,
            title: 'About This App',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          _Row(
            icon: Icons.menu_book_outlined,
            title: 'Form Tips',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormTipsScreen(config: config))),
          ),
          _Row(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          const _Header('Testing'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Coach model'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'tuned', label: Text('Tuned')),
                  ButtonSegment(value: 'base', label: Text('Base')),
                  ButtonSegment(value: 'mock', label: Text('Rules')),
                ],
                selected: {settings.coachModel},
                onSelectionChanged: (s) => settings.setCoachModel(s.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('scenario'),
                initialValue: settings.scenario,
                decoration: const InputDecoration(
                  labelText: 'Test scenario label',
                  hintText: 'p11_squat_knee_valgus_dimlight_n8',
                  helperText: 'Saved in each session log for analyze_sessions.py',
                  border: OutlineInputBorder(),
                ),
                onChanged: settings.setScenario,
              ),
              const SizedBox(height: 10),
              Text('Backend: $backendUrl', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _choose<T>(BuildContext context, String title, Map<T, String> options, T current, void Function(T) set) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final e in options.entries)
            ListTile(
              title: Text(e.value),
              trailing: e.key == current ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked != null) set(picked);
  }

  Future<void> _editName(BuildContext context) async {
    final ctrl = TextEditingController(text: settings.profileName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profile'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null) settings.setProfileName(name);
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Container(
        color: context.fc.card,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        margin: const EdgeInsets.only(top: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (value != null) Text(value!, style: TextStyle(color: muted)),
        Icon(Icons.chevron_right, color: muted),
      ]),
      onTap: onTap,
    );
  }
}
