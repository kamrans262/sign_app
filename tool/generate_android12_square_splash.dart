// Generate a larger, truly centered Android 12+ splash wordmark.
// Android 12 masks a 1152x1152 image with a central 768px-diameter circle.
// The original PNG has generous white/transparent margins, so resizing the
// whole image made the Sign2Digital wordmark appear too small.
// Crop only background pixels first, then scale the actual artwork safely.
// Keep the full original logo and all iOS / older Android resources untouched.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const input = 'assets/logo_splash.png';
  const output = 'assets/logo_splash_android12.png';
  const canvasSize = 1152;
  // Draw within the Android 12 central circular icon region.
  const safeRadius = 382.0; // Android 12 masks at ~384px radius.
  const desiredContentWidth = 760.0;
  const desiredContentHeight = 255.0;
  const margin = 10;

  final sourceFile = File(input);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Original Sign2Digital splash logo missing: $input');
    exitCode = 1;
    return;
  }
  final original = img.decodePng(sourceFile.readAsBytesSync());
  if (original == null || original.width < 2 || original.height < 2) {
    stderr.writeln('Original logo is not a readable PNG.');
    exitCode = 1;
    return;
  }

  // Find the real colored artwork (not surrounding pure-white/transparent
  // margins). Keep tiny antialiasing pixels via the cropping margin.
  var minX = original.width;
  var minY = original.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < original.height; y++) {
    for (var x = 0; x < original.width; x++) {
      final pixel = original.getPixel(x, y);
      if (pixel.a < 24 ||
          (pixel.r > 244 && pixel.g > 244 && pixel.b > 244)) {
        continue;
      }
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) {
    stderr.writeln('Unable to locate visible Sign2Digital artwork.');
    exitCode = 1;
    return;
  }

  final left = math.max(0, minX - margin);
  final top = math.max(0, minY - margin);
  final right = math.min(original.width, maxX + margin + 1);
  final bottom = math.min(original.height, maxY + margin + 1);
  final cropped = img.copyCrop(original,
    x: left, y: top, width: right - left, height: bottom - top);

  final scale = math.min(
    desiredContentWidth / cropped.width,
    desiredContentHeight / cropped.height,
  );
  var width = (cropped.width * scale).round();
  var height = (cropped.height * scale).round();

  // The whole wordmark's bounding rectangle stays inside the Android
  // system's circular mask. Do not risk clipping either end of the text.
  final cornerRadius = math.sqrt(
    (width * width + height * height) / 4);
  if (cornerRadius > safeRadius) {
    final factor = safeRadius / cornerRadius;
    width = (width * factor).floor();
    height = (height * factor).floor();
  }
  if (width < 2 || height < 2) {
    stderr.writeln('Invalid rendered splash artwork dimensions.');
    exitCode = 1;
    return;
  }

  final resized = img.copyResize(cropped,
    width: width, height: height,
    interpolation: img.Interpolation.linear);
  final square = img.Image(width: canvasSize, height: canvasSize,
    numChannels: 4);
  img.fill(square, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(square, resized,
    dstX: (canvasSize - resized.width) ~/ 2,
    dstY: (canvasSize - resized.height) ~/ 2);

  File(output).writeAsBytesSync(img.encodePng(square, level: 6));
  stdout.writeln('Android 12 larger centered wordmark: '
    '${resized.width}x${resized.height}, '
    'in ${square.width}x${square.height} safe square; '
    'original proportions preserved.');
}
