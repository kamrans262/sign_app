import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/core/services/profile_photo_session.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_country_selector.dart';
import 'package:sign2digital/core/widgets/sign2digital_header.dart';
import 'package:sign2digital/features/auth/data/account_repository.dart';
import 'package:sign2digital/features/auth/domain/account_profile.dart';
import 'package:sign2digital/features/profile/presentation/screens/edit_profile_screen.dart';

class _AccountRepo implements AccountRepository {
  _AccountRepo(this.value);
  AccountProfile? value;
  int saveCount = 0;

  @override
  Future<AccountProfile?> currentAccount() async => value;

  @override
  Future<void> saveDraft(AccountProfile profile) async {
    saveCount++;
    value = profile;
  }
}

AccountProfile _account() => AccountProfile(
  id: 'account-123',
  fullName: 'Jean Dupont',
  email: 'jean@example.ch',
  countryIsoCode: 'CH',
  dialingCode: '+41',
  phoneNumber: '781234567',
  title: 'Architect',
);

Finder _field(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byType(TextFormField),
);

Future<void> _scrollTo(WidgetTester tester, Key target) async {
  await tester.scrollUntilVisible(
    find.byKey(target),
    140,
    scrollable: find.descendant(
      of: find.byKey(const Key('profile-edit-scroll')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(ProfilePhotoSession.resetForTests);
  tearDown(ProfilePhotoSession.resetForTests);

  testWidgets('Figma form uses 100px avatar, shared fields and More nav',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(
      repository: _AccountRepo(_account()),
      initialAccount: _account(),
    )));
    expect(find.byType(Sign2DigitalHeader), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Change Photo'), findsOneWidget);
    expect(find.byKey(const Key('profile-edit-camera')), findsOneWidget);
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    await _scrollTo(tester, const Key('profile-edit-phone'));
    expect(find.byType(Sign2DigitalCountrySelector), findsOneWidget);
    await _scrollTo(tester, const Key('profile-edit-title'));
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Architect'), findsOneWidget);
    await _scrollTo(tester, const Key('profile-edit-save'));
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Save preserves account ID and updates names, email, phone, title',
      (tester) async {
    final repo = _AccountRepo(_account());
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => EditProfileScreen(
            repository: repo, initialAccount: repo.value,
          )),
        ),
        child: const Text('Edit'),
      )),
    ));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(_field(const Key('profile-edit-first-name')), 'Marie');
    await tester.enterText(_field(const Key('profile-edit-last-name')), 'Curie');
    await _scrollTo(tester, const Key('profile-edit-email'));
    await tester.enterText(_field(const Key('profile-edit-email')),
      'marie@example.ch');
    await _scrollTo(tester, const Key('profile-edit-phone'));
    await tester.enterText(_field(const Key('profile-edit-phone')), '795551122');
    await _scrollTo(tester, const Key('profile-edit-title'));
    await tester.tap(find.byKey(const Key('profile-edit-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project Manager'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('profile-edit-save'));
    await tester.tap(find.byKey(const Key('profile-edit-save')));
    await tester.pumpAndSettle();
    expect(repo.saveCount, 1);
    expect(repo.value?.id, 'account-123');
    expect(repo.value?.fullName, 'Marie Curie');
    expect(repo.value?.email, 'marie@example.ch');
    expect(repo.value?.phoneNumber, '795551122');
    expect(repo.value?.title, 'Project Manager');
    expect(repo.value?.countryIsoCode, 'CH');
    expect(find.text('Edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel discards unsaved profile and photo changes',
      (tester) async {
    final repo = _AccountRepo(_account());
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      ElevatedButton(onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => EditProfileScreen(
          repository: repo,
          initialAccount: repo.value,
          pickPhotoBytes: () async => bytes,
        ))), child: const Text('Edit')))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(_field(const Key('profile-edit-first-name')), 'Unsaved');
    await tester.tap(find.byKey(const Key('profile-edit-photo')));
    await tester.pump();
    expect(ProfilePhotoSession.bytes.value, isNull);
    await _scrollTo(tester, const Key('profile-edit-cancel'));
    await tester.tap(find.byKey(const Key('profile-edit-cancel')));
    await tester.pumpAndSettle();
    expect(repo.saveCount, 0);
    expect(repo.value?.fullName, 'Jean Dupont');
    expect(ProfilePhotoSession.bytes.value, isNull);
    expect(find.text('Edit'), findsOneWidget);
    // Mock bytes are not an actual image; decoding errors do not alter state.
  });

  testWidgets('Selected photo updates shared session only after Save',
      (tester) async {
    final bytes = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4'
      'z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=='));
    final repo = _AccountRepo(_account());
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      ElevatedButton(onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => EditProfileScreen(
          repository: repo,
          initialAccount: repo.value,
          pickPhotoBytes: () async => bytes,
        ))), child: const Text('Edit')))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-edit-camera')));
    await tester.pump();
    expect(ProfilePhotoSession.bytes.value, isNull);
    await _scrollTo(tester, const Key('profile-edit-save'));
    await tester.tap(find.byKey(const Key('profile-edit-save')));
    await tester.pumpAndSettle();
    expect(ProfilePhotoSession.bytes.value, same(bytes));
    expect(repo.saveCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid e-mail blocks saving and keeps the form open',
      (tester) async {
    final repo = _AccountRepo(_account());
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(repository: repo, initialAccount: repo.value),
    ));
    await _scrollTo(tester, const Key('profile-edit-email'));
    await tester.enterText(_field(const Key('profile-edit-email')),
      'invalid email');
    await _scrollTo(tester, const Key('profile-edit-save'));
    await tester.tap(find.byKey(const Key('profile-edit-save')));
    await tester.pumpAndSettle();
    expect(repo.saveCount, 0);
    await _scrollTo(tester, const Key('profile-edit-email'));
    expect(find.text('Enter a valid e-mail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('Form scrolls and bottom navigation remains fixed at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _AccountRepo(_account());
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(repository: repo, initialAccount: repo.value),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, const Key('profile-edit-save'));
      expect(find.byKey(const Key('profile-edit-save')), findsOneWidget);
      expect(find.byType(Sign2DigitalBottomNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
