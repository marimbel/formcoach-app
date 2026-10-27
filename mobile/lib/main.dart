import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/app_config.dart';
import 'screens/home_screen.dart';
import 'vision/form_classifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final config = await LabelsConfig.load();
  final classifier = await FormClassifier.load(config.classNames.length);
  runApp(FormCoachApp(config: config, classifier: classifier));
}

class FormCoachApp extends StatelessWidget {
  final LabelsConfig config;
  final FormClassifier? classifier;
  const FormCoachApp({super.key, required this.config, required this.classifier});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FormCoach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B7F5B), brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 18), bodyMedium: TextStyle(fontSize: 16)),
      ),
      home: HomeScreen(config: config, classifier: classifier),
    );
  }
}
