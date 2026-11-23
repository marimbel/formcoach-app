import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/app_config.dart';
import 'models/app_settings.dart';
import 'screens/shell.dart';
import 'theme.dart';
import 'vision/form_classifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final config = await LabelsConfig.load();
  final classifier = await FormClassifier.load(config.classNames.length);
  final settings = await AppSettings.load();
  runApp(FormCoachApp(config: config, classifier: classifier, settings: settings));
}

class FormCoachApp extends StatelessWidget {
  final LabelsConfig config;
  final FormClassifier? classifier;
  final AppSettings settings;
  const FormCoachApp({super.key, required this.config, required this.classifier, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'FormCoach',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        home: AppShell(config: config, classifier: classifier, settings: settings),
      ),
    );
  }
}
