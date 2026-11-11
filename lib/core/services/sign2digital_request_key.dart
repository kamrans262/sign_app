import 'dart:math';

/// One cryptographically random key per user-driven create action.
/// Keep the same key when retrying the same draft after a network timeout.
abstract final class Sign2DigitalRequestKey {
  static final Random _random = Random.secure();
  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String create() => List<String>.generate(32,
      (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
}
