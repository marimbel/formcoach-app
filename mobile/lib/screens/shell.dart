import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/app_settings.dart';
import '../vision/form_classifier.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Bottom navigation: Home · History · Settings (screens 1 and 5 of the mockup, plus History).
class AppShell extends StatefulWidget {
  final LabelsConfig config;
  final FormClassifier? classifier;
  final AppSettings settings;
  const AppShell({super.key, required this.config, required this.classifier, required this.settings});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        HomeScreen(
          config: widget.config,
          classifier: widget.classifier,
          settings: widget.settings,
          onSessionSaved: () => _historyKey.currentState?.reload(),
        ),
        HistoryScreen(key: _historyKey, config: widget.config),
        SettingsScreen(settings: widget.settings, config: widget.config),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) _historyKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
