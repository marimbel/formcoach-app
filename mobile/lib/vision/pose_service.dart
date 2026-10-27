// Model C: ML Kit pose detection (BlazePose, 33 landmarks) on device.
import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'geometry.dart';

class PoseFrame {
  final Pose33 landmarks; // upright-image pixels
  final Size uprightSize;
  const PoseFrame(this.landmarks, this.uprightSize);
}

class PoseService {
  final PoseDetector _detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base));

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Clockwise rotation (deg) that makes the sensor image upright. Same value is used to sample crops.
  int? rotationFor(CameraController c, CameraDescription cam) {
    final sensor = cam.sensorOrientation;
    if (Platform.isIOS) return sensor;
    var comp = _orientations[c.value.deviceOrientation];
    if (comp == null) return null;
    return cam.lensDirection == CameraLensDirection.front ? (sensor + comp) % 360 : (sensor - comp + 360) % 360;
  }

  /// Follows the google_mlkit_commons example for camera streams.
  InputImage? toInputImage(CameraImage image, int rotationDeg) {
    final rotation = InputImageRotationValue.fromRawValue(rotationDeg);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<PoseFrame?> detect(CameraImage image, int rotationDeg) async {
    final input = toInputImage(image, rotationDeg);
    if (input == null) return null;
    final poses = await _detector.processImage(input);
    if (poses.isEmpty) return null;
    final pose = poses.first;
    final lms = <Lm>[];
    for (final t in PoseLandmarkType.values) {
      // enum order == BlazePose index order (nose=0 ... rightFootIndex=32)
      final l = pose.landmarks[t];
      lms.add(l == null ? const Lm(0, 0, 0) : Lm(l.x, l.y, l.likelihood));
    }
    final swap = rotationDeg == 90 || rotationDeg == 270;
    final size = swap
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
    return PoseFrame(lms, size);
  }

  Future<void> close() => _detector.close();
}
