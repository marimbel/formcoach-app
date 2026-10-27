// ROI extraction for Model A: sample a square, upright, 224x224 RGB crop around the person straight
// from the camera buffer. Rotation, cropping, padding and resizing happen in one pass over 50k output
// pixels instead of converting and rotating the whole frame, which keeps it to a few ms on a phone.
// Out-of-frame pixels are black, matching crop_square() in the Python pipeline.
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class Crop {
  final img.Image image; // for the JPEG sent to Gemini and the debug view
  final Float32List input; // [224*224*3] RGB 0..255 for Model A
  const Crop(this.image, this.input);
}

Crop sampleCrop(CameraImage cam, int rotationDeg, double left, double top, double side, {int out = 224}) {
  final w = cam.width, h = cam.height;
  final bytes = cam.planes[0].bytes;
  var stride = cam.planes[0].bytesPerRow;
  final isBgra = Platform.isIOS;
  if (!isBgra && bytes.length < stride * h * 3 ~/ 2) stride = w; // defensive: unpadded NV21
  final uvStart = stride * h;
  final im = img.Image(width: out, height: out);
  final input = Float32List(out * out * 3);
  final step = side / out;
  var k = 0;
  for (var oy = 0; oy < out; oy++) {
    final uy = top + (oy + 0.5) * step;
    for (var ox = 0; ox < out; ox++) {
      final ux = left + (ox + 0.5) * step;
      // upright (ux,uy) -> sensor (sx,sy); inverse of a clockwise rotation by rotationDeg
      int sx, sy;
      switch (rotationDeg) {
        case 90:
          sx = uy.floor();
          sy = h - 1 - ux.floor();
          break;
        case 180:
          sx = w - 1 - ux.floor();
          sy = h - 1 - uy.floor();
          break;
        case 270:
          sx = w - 1 - uy.floor();
          sy = ux.floor();
          break;
        default:
          sx = ux.floor();
          sy = uy.floor();
      }
      int r = 0, g = 0, b = 0;
      if (sx >= 0 && sy >= 0 && sx < w && sy < h) {
        if (isBgra) {
          final i = sy * stride + sx * 4;
          b = bytes[i];
          g = bytes[i + 1];
          r = bytes[i + 2];
        } else {
          final yv = bytes[sy * stride + sx];
          final uvi = uvStart + (sy >> 1) * stride + (sx & ~1);
          final v = bytes[uvi] - 128, u = bytes[uvi + 1] - 128; // NV21 = interleaved V,U
          r = (yv + 1.402 * v).round().clamp(0, 255).toInt();
          g = (yv - 0.344136 * u - 0.714136 * v).round().clamp(0, 255).toInt();
          b = (yv + 1.772 * u).round().clamp(0, 255).toInt();
        }
      }
      im.setPixelRgb(ox, oy, r, g, b);
      input[k++] = r.toDouble();
      input[k++] = g.toDouble();
      input[k++] = b.toDouble();
    }
  }
  return Crop(im, input);
}

Uint8List encodeJpeg(img.Image im) => img.encodeJpg(im, quality: 80);
