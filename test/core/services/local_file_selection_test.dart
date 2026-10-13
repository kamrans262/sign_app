import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/services/local_file_selection.dart';

void main() {
  test('file validation accepts supported extensions and exactly 2 MB', () {
    final file = PlatformFile(
      name: 'logo.PNG',
      size: LocalFileSelection.maxBytes,
    );
    expect(
      LocalFileSelection.validate(file, extensions: ['png', 'jpg', 'svg']),
      same(file),
    );
  });

  test('file validation rejects unsupported extension', () {
    final file = PlatformFile(name: 'script.exe', size: 100);
    expect(
      () => LocalFileSelection.validate(file, extensions: ['pdf']),
      throwsFormatException,
    );
  });

  test('file validation rejects files larger than 2 MB', () {
    final file = PlatformFile(
      name: 'terms.pdf',
      size: LocalFileSelection.maxBytes + 1,
    );
    expect(
      () => LocalFileSelection.validate(file, extensions: ['pdf']),
      throwsFormatException,
    );
  });
}
