import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/services/sign_api_client.dart';

class AppleSignInClient {
  static const _channel = MethodChannel('sign2digital/apple_auth');

  static Future<Map<String, dynamic>?> signIn(String nonce) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const SignApiException('Apple sign-in is available on iPhone and iPad.');
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'signIn', {'nonce': nonce},
      );
      if (result == null) return null; // User canceled.
      final token = result['id_token'];
      if (token is! String || token.isEmpty) {
        throw const SignApiException('Apple did not return a sign-in token.');
      }
      return result;
    } on PlatformException {
      throw const SignApiException(
        'Unable to sign in with Apple. Check your Apple account and try again.',
      );
    } on MissingPluginException {
      throw const SignApiException('Apple sign-in is unavailable on this device.');
    }
  }
}
