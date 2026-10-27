// Model A: fine-tuned MobileNetV3-Large (TFLite) on device. Input [1,224,224,3] RGB 0..255,
// output [1,N] softmax over all '<exercise>__<error>' classes (order from labels.json).
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

class FormClassifier {
  final Interpreter _interpreter;
  final IsolateInterpreter _isolate; // keeps inference off the UI thread
  final int numClasses;

  FormClassifier._(this._interpreter, this._isolate, this.numClasses);

  static const asset = 'assets/models/form_classifier.tflite';

  /// Returns null if the model file is missing (e.g. before the team has trained it).
  static Future<FormClassifier?> load(int numClasses) async {
    try {
      final interp = await Interpreter.fromAsset(asset);
      final outShape = interp.getOutputTensor(0).shape;
      if (outShape.last != numClasses) {
        throw StateError('model has ${outShape.last} outputs but labels.json has $numClasses classes');
      }
      final iso = await IsolateInterpreter.create(address: interp.address);
      return FormClassifier._(interp, iso, numClasses);
    } catch (e) {
      // ignore: avoid_print
      print('Model A not loaded: $e');
      return null;
    }
  }

  Future<List<double>> predict(Float32List rgb224) async {
    final input = rgb224.reshape([1, 224, 224, 3]);
    final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);
    await _isolate.run(input, output);
    return List<double>.from(output[0] as List);
  }

  /// Average several crops (frames around the bottom), then keep only the selected exercise's
  /// classes and renormalise, exactly like scripts/04_eval_model_a.py.
  static Map<String, double> maskedAverage(List<List<double>> probs, List<int> idx, List<String> classNames) {
    final sums = List.filled(idx.length, 0.0);
    for (final p in probs) {
      for (var j = 0; j < idx.length; j++) {
        sums[j] += p[idx[j]];
      }
    }
    final total = sums.fold(0.0, (a, b) => a + b);
    return {
      for (var j = 0; j < idx.length; j++)
        classNames[idx[j]].split('__')[1]: total > 0 ? sums[j] / total : 1.0 / idx.length
    };
  }

  void close() {
    _isolate.close();
    _interpreter.close();
  }
}
