import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/sign_api_client.dart';

/// Native Google identity only. The backend always verifies the signed ID
/// token and creates the Sign2Digital session. Never use Google access tokens
/// as Laravel bearer tokens.
class GoogleSignInClient {
  GoogleSignInClient._();

  static final GoogleSignInClient shared = GoogleSignInClient._();

  Future<void>? _initialized;

  Future<void> _initialize() {
    // On Android the google-services.json Web OAuth client is discovered by
    // the Google Services Gradle plugin. A build-time ID may override it.
    const webId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    const iosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    return _initialized ??= GoogleSignIn.instance.initialize(
      serverClientId: webId.isEmpty ? null : webId,
      clientId: defaultTargetPlatform == TargetPlatform.iOS && iosId.isNotEmpty
          ? iosId : null,
    );
  }

  /// Null means the user canceled the Google account picker.
  Future<String?> idToken() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const SignApiException(
        'Google sign-in is currently available in the Android and iOS apps.');
    }
    try {
      await _initialize();
      final signIn = GoogleSignIn.instance;
      if (!signIn.supportsAuthenticate()) {
        throw const SignApiException('Google sign-in is unavailable on this device.');
      }
      final account = await signIn.authenticate();
      final credential = account.authentication;
      final token = credential.idToken;
      if (token == null || token.isEmpty) {
        throw const SignApiException(
          'Google did not provide a sign-in token. Check your Google OAuth configuration.');
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const SignApiException(
        'Unable to sign in with Google. Check your Google account and app configuration.');
    }
  }
}
