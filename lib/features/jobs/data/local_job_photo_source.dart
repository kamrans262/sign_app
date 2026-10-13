import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Picked photo held locally until the user confirms Add Photos.
class LocalJobPhotoSelection {
  const LocalJobPhotoSelection({
    required this.name,
    required this.bytes,
    required this.sourceKey,
  });

  final String name;
  final Uint8List bytes;
  final String sourceKey;
}

/// Inject this service in widget tests; no native picker is opened there.
abstract class JobPhotoSource {
  Future<List<LocalJobPhotoSelection>> upload();
  Future<LocalJobPhotoSelection?> camera();
}

class DeviceJobPhotoSource implements JobPhotoSource {
  DeviceJobPhotoSource({ImagePicker? cameraPicker})
    : _cameraPicker = cameraPicker ?? ImagePicker();

  final ImagePicker _cameraPicker;
  static const maxBytes = 20 * 1024 * 1024;

  /// Catch accidental non-images even when the extension looks correct.
  static void validate(String name, Uint8List bytes) {
    final extension = name.split('.').last.toLowerCase();
    if (!const ['jpg', 'jpeg', 'png'].contains(extension)) {
      throw const FormatException('Choose JPG, JPEG or PNG images.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Each image must be between 1 byte and 20 MB.',
      );
    }
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    if (!((extension == 'png' && png) ||
        ((extension == 'jpg' || extension == 'jpeg') && jpg))) {
      throw const FormatException('The selected file is not a valid image.');
    }
  }

  @override
  Future<List<LocalJobPhotoSelection>> upload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return [];
    final selected = <LocalJobPhotoSelection>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('The image could not be read.');
      }
      validate(file.name, bytes);
      selected.add(
        LocalJobPhotoSelection(
          name: file.name,
          bytes: bytes,
          sourceKey: file.path ?? '${file.name}:${file.size}',
        ),
      );
    }
    return selected;
  }

  @override
  Future<LocalJobPhotoSelection?> camera() async {
    final file = await _cameraPicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    // Camera files may have generated names without a supported extension.
    final name =
        RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false).hasMatch(file.name)
        ? file.name
        : '${file.name}.jpg';
    validate(name, bytes);
    return LocalJobPhotoSelection(
      name: name,
      bytes: bytes,
      sourceKey: file.path,
    );
  }
}
