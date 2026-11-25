import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/active_company_session.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../reminders/services/m20_push_coordinator.dart';
import '../presentation/screens/m23_checkout_return_screen.dart';

enum M23BillingReturnKind { success, cancel, portal }

/// Navigation-only return from the browser. Never proof of payment.
class M23BillingReturn {
  const M23BillingReturn(this.kind, this.intentId);
  final M23BillingReturnKind kind;
  final String? intentId;

  static final _uuid = RegExp(
    r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89abAB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$',
  );

  static M23BillingReturn? parse(Uri uri) {
    if (uri.scheme != 'sign2digital' || uri.host != 'billing' ||
        uri.userInfo.isNotEmpty || uri.hasPort || uri.fragment.isNotEmpty ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final kind = switch (uri.pathSegments.single) {
      'success' => M23BillingReturnKind.success,
      'cancel' => M23BillingReturnKind.cancel,
      'portal' => M23BillingReturnKind.portal,
      _ => null,
    };
    if (kind == null) return null;
    final intent = uri.queryParameters['intent'];
    if (kind == M23BillingReturnKind.portal) {
      return intent == null && uri.queryParameters.isEmpty
          ? const M23BillingReturn(M23BillingReturnKind.portal, null)
          : null;
    }
    if (uri.queryParameters.length != 1 || intent == null ||
        !_uuid.hasMatch(intent)) {
      return null;
    }
    return M23BillingReturn(kind, intent);
  }
}

/// Handles Android/iOS warm and cold starts. A cold-start browser link is
/// queued until the existing auth + company gate completes; it never logs the
/// user in or selects a company from an untrusted URL.
abstract final class M23BillingDeepLinks {
  static StreamSubscription<Uri>? _subscription;
  static M23BillingReturn? _pending;
  static bool _showing = false;

  static void start() {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS)) return;
    _subscription ??= AppLinks().uriLinkStream.listen(
      accept, onError: (Object _) {
        // A failed deep link never interrupts the regular application.
      },
    );
  }

  @visibleForTesting
  static void accept(Uri uri) {
    final parsed = M23BillingReturn.parse(uri);
    if (parsed == null) return;
    _pending = parsed;
    presentIfReady();
  }

  static void presentIfReady() {
    if (_showing || _pending == null ||
        !MobileAuthRepository.shared.isSignedIn ||
        ActiveCompanySession.companyId == null) return;
    final nav = M20PushCoordinator.navigatorKey.currentState;
    if (nav == null) return;
    final result = _pending!;
    _pending = null;
    _showing = true;
    nav.push<void>(MaterialPageRoute<void>(
      builder: (_) => M23CheckoutReturnScreen(result: result),
    )).whenComplete(() {
      _showing = false;
      if (_pending != null) presentIfReady();
    });
  }
}
