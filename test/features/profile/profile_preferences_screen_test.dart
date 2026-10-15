import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_header.dart';
import 'package:sign2digital/features/profile/data/profile_preferences_repository.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_preferences_screen.dart';
import 'package:sign2digital/features/profile/presentation/widgets/profile_notification_row.dart';

class _PreferencesRepo implements ProfilePreferencesRepository {
  ProfilePreferences saved = const ProfilePreferences();
  int writes = 0;
  bool failLoad = false;
  bool failSave = false;

  @override
  Future<ProfilePreferences> load() async {
    if (failLoad) throw StateError('offline');
    return saved;
  }

  @override
  Future<void> save(ProfilePreferences preferences) async {
    if (failSave) throw StateError('offline');
    saved = preferences;
    writes++;
  }
}

Finder _scrollable() => find.descendant(
  of: find.byKey(const Key('preferences-scroll')),
  matching: find.byType(Scrollable),
).first;

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  // ListView lazily builds the lower cards, especially on small phones.
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target);
  } else {
    try {
      await tester.scrollUntilVisible(
        target, -160, maxScrolls: 20, scrollable: _scrollable());
    } on StateError {
      await tester.scrollUntilVisible(
        target, 160, maxScrolls: 20, scrollable: _scrollable());
    }
  }
  await tester.pumpAndSettle();
}

Future<void> _openOption(
    WidgetTester tester, Key field, String value) async {
  await _scrollTo(tester, field);
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  test('Preference records round trip and preserve defaults', () {
    final value = const ProfilePreferences().copyWith(
      language: 'German', timeFormat: '12 hours',
      pushNotifications: false, smsNotifications: true);
    final decoded = ProfilePreferences.fromJson(value.toJson());
    expect(decoded.language, 'German');
    expect(decoded.timeFormat, '12 hours');
    expect(decoded.pushNotifications, isFalse);
    expect(decoded.smsNotifications, isTrue);
    expect(decoded.emailNotifications, isTrue);
    expect(ProfilePreferences.fromJson({}).timeZone, 'Europe/Zurich');
  });

  testWidgets('Renders shared fields, four selections and More bottom nav',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfilePreferencesScreen(repository: _PreferencesRepo()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Sign2DigitalHeader), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('DD / MM / YYYY'), findsOneWidget);
    expect(find.text('24 hours'), findsOneWidget);
    await _scrollTo(tester, const Key('preferences-time-zone'));
    expect(find.text('Europe/Zurich'), findsOneWidget);
    await _scrollTo(tester, const Key('preferences-save'));
    expect(find.text('Save Preferences'), findsOneWidget);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dropdowns save language, date, time and real time zone',
      (tester) async {
    final repo = _PreferencesRepo();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        ElevatedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) =>
              ProfilePreferencesScreen(repository: repo))),
          child: const Text('Open Preferences'),
        ),
      )),
    ));
    await tester.tap(find.text('Open Preferences'));
    await tester.pumpAndSettle();

    await _openOption(tester, const Key('preferences-language'), 'German');
    await _openOption(tester, const Key('preferences-date-format'), 'YYYY-MM-DD');
    await _openOption(tester, const Key('preferences-time-format'), '12 hours');
    await _openOption(tester, const Key('preferences-time-zone'), 'UTC');
    await _scrollTo(tester, const Key('preferences-save'));
    await tester.tap(find.byKey(const Key('preferences-save')));
    await tester.pump();
    expect(repo.writes, 1);
    expect(repo.saved.language, 'German');
    expect(repo.saved.dateFormat, 'YYYY-MM-DD');
    expect(repo.saved.timeFormat, '12 hours');
    expect(repo.saved.timeZone, 'UTC');

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('German'), findsOneWidget);
    expect(find.text('YYYY-MM-DD'), findsOneWidget);
    expect(find.text('12 hours'), findsOneWidget);
    await _scrollTo(tester, const Key('preferences-time-zone'));
    expect(find.text('UTC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Three notification rows toggle independently and save',
      (tester) async {
    final repo = _PreferencesRepo();
    await tester.pumpWidget(MaterialApp(
      home: ProfilePreferencesScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('preferences-push'));
    expect(tester.widget<ProfileNotificationRow>(
      find.byKey(const Key('preferences-push'))).enabled, isTrue);
    await tester.tap(find.byKey(const Key('preferences-push')));
    await tester.pumpAndSettle();
    expect(tester.widget<ProfileNotificationRow>(
      find.byKey(const Key('preferences-push'))).enabled, isFalse);

    await _scrollTo(tester, const Key('preferences-sms'));
    expect(tester.widget<ProfileNotificationRow>(
      find.byKey(const Key('preferences-sms'))).enabled, isFalse);
    await tester.tap(find.byKey(const Key('preferences-sms')));
    await tester.pumpAndSettle();
    expect(tester.widget<ProfileNotificationRow>(
      find.byKey(const Key('preferences-sms'))).enabled, isTrue);

    await _scrollTo(tester, const Key('preferences-save'));
    await tester.tap(find.byKey(const Key('preferences-save')));
    await tester.pump();
    expect(repo.saved.pushNotifications, isFalse);
    expect(repo.saved.emailNotifications, isTrue);
    expect(repo.saved.smsNotifications, isTrue);
    expect(repo.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unsaved changes do not touch repository on back',
      (tester) async {
    final repo = _PreferencesRepo();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        ElevatedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) =>
              ProfilePreferencesScreen(repository: repo))),
          child: const Text('Open Preferences'),
        ),
      )),
    ));
    await tester.tap(find.text('Open Preferences'));
    await tester.pumpAndSettle();
    await _openOption(tester, const Key('preferences-language'), 'French');
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
    expect(repo.saved.language, 'English');
  });

  testWidgets('Load error retries, failed save preserves previous values',
      (tester) async {
    final repo = _PreferencesRepo()..failLoad = true;
    await tester.pumpWidget(MaterialApp(
      home: ProfilePreferencesScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preferences-retry')), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.byKey(const Key('preferences-retry')));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    repo.failSave = true;
    await _scrollTo(tester, const Key('preferences-save'));
    await tester.tap(find.byKey(const Key('preferences-save')));
    await tester.pump();
    expect(repo.writes, 0);
    expect(repo.saved.language, 'English');
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('No overflow and save remains reachable on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _PreferencesRepo();
      await tester.pumpWidget(MaterialApp(
        home: ProfilePreferencesScreen(repository: repo),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, const Key('preferences-save'));
      expect(find.byKey(const Key('preferences-save')), findsOneWidget);
      expect(find.byType(Sign2DigitalBottomNavigationBar), findsOneWidget);
      await tester.tap(find.byKey(const Key('preferences-save')));
      await tester.pump();
      expect(repo.writes, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
