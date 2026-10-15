import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/auth/data/account_repository.dart';
import 'package:sign2digital/features/auth/domain/account_profile.dart';
import 'package:sign2digital/features/clients/presentation/screens/more_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_sections_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_preferences_screen.dart';
import 'package:sign2digital/features/profile/data/profile_preferences_repository.dart';
import 'package:sign2digital/features/profile/presentation/widgets/profile_settings_action_card.dart';

class _StubAccountRepository implements AccountRepository {
  _StubAccountRepository([this.profile]);
  AccountProfile? profile;
  bool fails = false;

  @override
  Future<AccountProfile?> currentAccount() async {
    if (fails) throw StateError('offline');
    return profile;
  }

  @override
  Future<void> saveDraft(AccountProfile value) async {
    profile = value;
  }
}

class _StubPreferencesRepository implements ProfilePreferencesRepository {
  ProfilePreferences value = const ProfilePreferences();
  @override
  Future<ProfilePreferences> load() async => value;
  @override
  Future<void> save(ProfilePreferences newValue) async { value = newValue; }
}

AccountProfile _profile([String name = 'Verified User']) => AccountProfile(
  id: 'profile-1',
  fullName: name,
  email: 'verified@example.com',
  countryIsoCode: 'CH',
  dialingCode: '+41',
  phoneNumber: '791234567',
);

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    170,
    scrollable: find.descendant(
      of: find.byKey(const Key('profile-settings-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Profile reuses dashboard logo header, cards and More navigation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileSettingsScreen(
        accountRepository: _StubAccountRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Sign2DigitalDashboardHeader), findsOneWidget);
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('jeandupont@sign2digital.com'), findsOneWidget);
    expect(find.text('+41 78 123 456 78'), findsOneWidget);
    expect(find.byKey(const Key('profile-demo-notice')), findsOneWidget);
    expect(find.byType(ProfileSettingsActionCard), findsWidgets);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Uses saved account instead of example profile', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileSettingsScreen(
        accountRepository: _StubAccountRepository(_profile()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Verified User'), findsOneWidget);
    expect(find.text('verified@example.com'), findsOneWidget);
    expect(find.text('+41 791234567'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsNothing);
    expect(find.byKey(const Key('profile-demo-notice')), findsNothing);
  });

  testWidgets('More entry opens the actual Profile screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MoreScreen()),
    ));
    await tester.tap(find.byKey(const Key('open-profile-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSettingsScreen), findsOneWidget);
    expect(find.byType(Sign2DigitalDashboardHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit updates shared account record and profile card',
      (tester) async {
    final repo = _StubAccountRepository(_profile());
    await tester.pumpWidget(MaterialApp(
      home: ProfileSettingsScreen(accountRepository: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-edit')));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byKey(const Key('profile-edit-first-name')),
        matching: find.byType(TextFormField)), 'Updated');
    await tester.enterText(
      find.descendant(of: find.byKey(const Key('profile-edit-last-name')),
        matching: find.byType(TextFormField)), 'User');
    await tester.enterText(
      find.descendant(of: find.byKey(const Key('profile-edit-email')),
        matching: find.byType(TextFormField)), 'new@example.com');
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-edit-phone')), 150,
      scrollable: find.descendant(
        of: find.byKey(const Key('profile-edit-scroll')),
        matching: find.byType(Scrollable),
      ).first);
    await tester.enterText(
      find.descendant(of: find.byKey(const Key('profile-edit-phone')),
        matching: find.byType(TextFormField)), '787654321');
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-edit-save')), 150,
      scrollable: find.descendant(
        of: find.byKey(const Key('profile-edit-scroll')),
        matching: find.byType(Scrollable),
      ).first);
    await tester.tap(find.byKey(const Key('profile-edit-save')));
    await tester.pumpAndSettle();

    expect(repo.profile?.fullName, 'Updated User');
    expect(repo.profile?.email, 'new@example.com');
    expect(repo.profile?.phoneNumber, '787654321');
    expect(find.byType(ProfileSettingsScreen), findsOneWidget);
    expect(find.text('Updated User'), findsOneWidget);
    expect(find.text('new@example.com'), findsOneWidget);
    expect(find.text('+41 787654321'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Personal Information and Business Information open destinations',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileSettingsScreen(
        accountRepository: _StubAccountRepository(_profile()),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-action-personal')));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    await _scrollTo(tester, const Key('profile-action-business'));
    await tester.tap(find.byKey(const Key('profile-action-business')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileBusinessInformationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Preferences, Security and App Settings have honest destinations',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileSettingsScreen(
        accountRepository: _StubAccountRepository(_profile()),
        preferencesRepository: _StubPreferencesRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    await _scrollTo(tester, const Key('profile-action-preferences'));
    await tester.tap(find.byKey(const Key('profile-action-preferences')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePreferencesScreen), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    for (final pair in [
      (const Key('profile-action-security'), 'Security & Access'),
      (const Key('profile-action-app-settings'), 'App Settings'),
    ]) {
      await _scrollTo(tester, pair.$1);
      await tester.tap(find.byKey(pair.$1));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSectionUnavailableScreen), findsOneWidget);
      expect(find.text(pair.$2), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSettingsScreen), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile loading errors allow retry', (tester) async {
    final repo = _StubAccountRepository(_profile())..fails = true;
    await tester.pumpWidget(MaterialApp(
      home: ProfileSettingsScreen(accountRepository: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-settings-retry')), findsOneWidget);
    repo.fails = false;
    await tester.tap(find.byKey(const Key('profile-settings-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Verified User'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('Profile action cards fit and scroll on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: ProfileSettingsScreen(
          accountRepository: _StubAccountRepository(_profile()),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, const Key('profile-action-app-settings'));
      expect(find.byKey(const Key('profile-action-app-settings')),
        findsOneWidget);
      expect(find.byType(Sign2DigitalBottomNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
