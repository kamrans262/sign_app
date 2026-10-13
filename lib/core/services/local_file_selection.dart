// Sign2Digital — local-only file selection. Never uploads files to a server.
import 'package:file_picker/file_picker.dart';

class LocalFileSelection {
  const LocalFileSelection._();

  static const int maxBytes = 2 * 1024 * 1024;

  /// Returns null when the user cancels. Throws FormatException when invalid.
  static Future<PlatformFile?> choose({
    required List<String> extensions,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return validate(result.files.single, extensions: extensions);
  }

  /// Pure validation shared by the picker and unit tests. Backend will validate
  /// both MIME type and actual file contents independently during upload.
  static PlatformFile validate(
    PlatformFile file, {
    required List<String> extensions,
  }) {
    final extension =
        file.extension?.toLowerCase() ??
        (file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : '');
    if (!extensions.contains(extension)) {
      throw const FormatException('This file format is not supported.');
    }
    if (file.size > maxBytes) {
      throw const FormatException('The file must be 2 MB or smaller.');
    }
    return file;
  }
}
