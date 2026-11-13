// Generate a centered, unclipped Android 12+ splash icon from the unchanged
// Sign2Digital horizontal wordmark. Android 12 forces its splash asset into a
// square icon area; using the 3:1 source directly stretches it vertically.
//
// Run BEFORE flutter_native_splash:create. The same white background is used
// in dark mode. No change to the launcher icon, iOS or Android 11 splash.
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const input = 'assets/logo_splash.png';
  const output = 'assets/logo_splash_android12.png';
  const canvasSize = 1152;
  // Android 12 mask: safe circle diameter 768 px in a 1152 px icon.
  // A 720x240 centered wordmark fits inside that circle exactly.
  const maxWidth = 720;
  const maxHeight = 240;

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

  final scale = [
    maxWidth / original.width,
    maxHeight / original.height,
  ].reduce((a, b) => a < b ? a : b);
  final width = (original.width * scale).round();
  final height = (original.height * scale).round();
  if (width < 2 || height < 2) {
    stderr.writeln('Invalid scaled splash logo dimensions.');
    exitCode = 1;
    return;
  }

  final resized = img.copyResize(original,
    width: width, height: height,
    interpolation: img.Interpolation.linear);
  final square = img.Image(width: canvasSize, height: canvasSize,
    numChannels: 4);
  img.fill(square, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(square, resized,
    dstX: (canvasSize - resized.width) ~/ 2,
    dstY: (canvasSize - resized.height) ~/ 2);

  final file = File(output);
  file.writeAsBytesSync(img.encodePng(square, level: 6));
  // The native splash theme keeps the background white, so transparent
  // padding is invisible. The image content is truly centered and 3:1.
  stdout.writeln('Centered Android 12 splash: '
    '${square.width}x${square.height} canvas; '
    '${resized.width}x${resized.height} source, aspect preserved.');
}
