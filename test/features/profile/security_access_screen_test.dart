import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_header.dart';
import 'package:sign2digital/features/profile/data/security_access_repository.dart';
import 'package:sign2digital/features/profile/presentation/screens/security_access_screen.dart';
import 'package:sign2digital/features/profile/presentation/widgets/profile_notification_row.dart';
import 'package:sign2digital/features/profile/presentation/widgets/security_session_card.dart';

const _current = SecurityDeviceSession(
  id: 'current',
  deviceName: 'Current Laptop',
  location: 'Zurich, Switzerland',
  agentAndLastSeen: 'Chrome · Today',
  isCurrent: true,
);
const _other = SecurityDeviceSession(
  id: 'other',
  deviceName: 'Other Phone',
  location: 'Bern, Switzerland',
  agentAndLastSeen: 'Safari · Yesterday',
  isCurrent: false,
  isMobile: true,
);

class _SecurityRepository implements SecurityAccessRepository {
  SecurityOverview snapshot = const SecurityOverview(
    twoFactorEnabled: false, sessions: [_current, _other],
  );
  bool loadingFails = false;
  bool acceptChanges = true;
  int twoFactorCalls = 0;
  int logoutAllCalls = 0;
  int revokeCalls = 0;

  @override
  Future<SecurityOverview> load() async {
    if (loadingFails) throw StateError('offline');
    return snapshot;
  }

  @override
  Future<bool> changeTwoFactor({
    required bool enable,
    required String confirmationPassword,
  }) async {
    twoFactorCalls++;
    if (confirmationPassword.isEmpty || !acceptChanges) return false;
    snapshot = SecurityOverview(
      twoFactorEnabled: enable,
      sessions: snapshot.sessions,
    );
    return true;
  }

  @override
  Future<bool> revokeOtherSessions({
    required String confirmationPassword,
  }) async {
    logoutAllCalls++;
    if (confirmationPassword.isEmpty || !acceptChanges) return false;
    snapshot = SecurityOverview(
      twoFactorEnabled: snapshot.twoFactorEnabled,
      sessions: snapshot.sessions!.where((s) => s.isCurrent).toList(),
    );
    return true;
  }

  @override
  Future<bool> revokeSession({
    required String sessionId,
    required String confirmationPassword,
  }) async {
    revokeCalls++;
    if (confirmationPassword.isEmpty || !acceptChanges) return false;
    snapshot = SecurityOverview(
      twoFactorEnabled: snapshot.twoFactorEnabled,
      sessions: snapshot.sessions!.where((s) => s.id != sessionId).toList(),
    );
    return true;
  }
}

Finder _passwordField() => find.descendant(
  of: find.byKey(const Key('security-confirm-password')),
  matching: find.byType(TextFormField),
);

Finder _editablePassword() => find.descendant(
  of: find.byKey(const Key('security-confirm-password')),
  matching: find.byType(TextField),
);

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key), 170,
    maxScrolls: 25,
    scrollable: find.descendant(
      of: find.byKey(const Key('security-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _enterPassword(WidgetTester tester) async {
  await _scrollTo(tester, const Key('security-confirm-password'));
  await tester.enterText(_passwordField(), 'test-password-not-persisted');
  await tester.pump();
}

void main() {
  testWidgets('Renders Figma security preview with explicit demo notice',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SecurityAccessScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalHeader), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.byType(ProfileNotificationRow), findsOneWidget);
    expect(find.text('2 FA is enabled'), findsOneWidget);
    expect(find.byKey(const Key('security-demo-notice')), findsOneWidget);
    // Session cards are below the initial viewport on smaller screens.
    await _scrollTo(tester, const Key('security-session-preview-current'));
    expect(find.text('MacBook Pro'), findsOneWidget);
    await _scrollTo(tester, const Key('security-session-preview-iphone'));
    expect(find.text('iPhone 15'), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Password starts obscured and visibility is controlled',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: _SecurityRepository()),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_editablePassword()).obscureText, isTrue);
    await tester.tap(find.byKey(const Key('security-password-visibility')));
    await tester.pump();
    expect(tester.widget<TextField>(_editablePassword()).obscureText, isFalse);
    await tester.tap(find.byKey(const Key('security-password-visibility')));
    await tester.pump();
    expect(tester.widget<TextField>(_editablePassword()).obscureText, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2FA needs password and confirmation, updates after verification',
      (tester) async {
    final repo = _SecurityRepository();
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-two-factor-toggle')));
    await tester.pump();
    expect(repo.twoFactorCalls, 0);
    await _enterPassword(tester);
    await tester.tap(find.byKey(const Key('security-two-factor-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Enable Two-Factor Authentication?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('security-dialog-cancel')));
    await tester.pumpAndSettle();
    expect(repo.twoFactorCalls, 0);
    await tester.tap(find.byKey(const Key('security-two-factor-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(repo.twoFactorCalls, 1);
    expect(repo.snapshot.twoFactorEnabled, isTrue);
    expect(find.text('2 FA is enabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Preview does not enable or disable actual account security',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SecurityAccessScreen(),
    ));
    await tester.pumpAndSettle();
    await _enterPassword(tester);
    await tester.tap(find.byKey(const Key('security-two-factor-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('2 FA is enabled'), findsOneWidget);
    expect(find.text(
      'Two-factor authentication is not connected or verified.'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('View all shows sessions and device details',
      (tester) async {
    final repo = _SecurityRepository();
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('security-view-all'));
    await tester.tap(find.byKey(const Key('security-view-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('security-all-sessions')), findsOneWidget);
    expect(find.byType(SecuritySessionCard), findsWidgets);
    await tester.tap(find.byKey(const Key('security-all-session-other')));
    await tester.pumpAndSettle();
    expect(find.text('Sign Out This Device'), findsOneWidget);
    expect(repo.revokeCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Verified session revocation refreshes list after View all',
      (tester) async {
    final repo = _SecurityRepository();
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    await _enterPassword(tester);
    await _scrollTo(tester, const Key('security-view-all'));
    await tester.tap(find.byKey(const Key('security-view-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-all-session-other')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-revoke-session')));
    await tester.pumpAndSettle();
    expect(find.text('Sign Out Other Phone?'), findsOneWidget);
    expect(repo.revokeCalls, 0);
    await tester.tap(find.byKey(const Key('security-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(repo.revokeCalls, 1);
    expect(repo.snapshot.sessions!.length, 1);
    expect(repo.snapshot.sessions!.single.id, 'current');
    expect(find.byKey(const Key('security-all-sessions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logout all requires confirmation and server confirmation',
      (tester) async {
    final repo = _SecurityRepository();
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-logout-all')));
    await tester.pumpAndSettle();
    expect(find.text('Log Out From All Devices?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('security-dialog-cancel')));
    await tester.pumpAndSettle();
    expect(repo.logoutAllCalls, 0);

    await _enterPassword(tester);
    await tester.tap(find.byKey(const Key('security-logout-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(repo.logoutAllCalls, 1);
    expect(repo.snapshot.sessions!.length, 1);
    expect(repo.snapshot.sessions!.single.id, 'current');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rejected changes never claim success',
      (tester) async {
    final repo = _SecurityRepository()..acceptChanges = false;
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    await _enterPassword(tester);
    await tester.tap(find.byKey(const Key('security-logout-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(repo.logoutAllCalls, 1);
    expect(repo.snapshot.sessions!.length, 2);
    expect(find.text('Device logout is not connected. No sessions were changed.'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing account security is not shown as verified',
      (tester) async {
    final repo = _SecurityRepository()..snapshot = const SecurityOverview();
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2FA status unavailable'), findsOneWidget);
    expect(find.text('Active sessions are unavailable.'), findsOneWidget);
    expect(find.byKey(const Key('security-demo-notice')), findsNothing);
    expect(find.text('MacBook Pro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Load error is retryable', (tester) async {
    final repo = _SecurityRepository()..loadingFails = true;
    await tester.pumpWidget(MaterialApp(
      home: SecurityAccessScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('security-retry')), findsOneWidget);
    repo.loadingFails = false;
    await tester.tap(find.byKey(const Key('security-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('Sessions scroll and destructive action stays visible on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: SecurityAccessScreen(repository: _SecurityRepository()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, const Key('security-session-other'));
      expect(find.byKey(const Key('security-session-other')), findsOneWidget);
      expect(find.byKey(const Key('security-logout-all')), findsOneWidget);
      expect(find.byType(Sign2DigitalBottomNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
