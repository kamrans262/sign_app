import 'package:flutter/foundation.dart';

/// A session-only profile photo. The app has no authenticated photo API yet.
/// The shared header and Profile screen listen to the same notifier.
abstract final class ProfilePhotoSession {
  static final ValueNotifier<Uint8List?> bytes =
      ValueNotifier<Uint8List?>(null);

  static void setPhoto(Uint8List? value) => bytes.value = value;

  static void resetForTests() => bytes.value = null;
}
