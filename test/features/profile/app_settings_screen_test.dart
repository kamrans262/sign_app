import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/core/widgets/sign2digital_header.dart';
import 'package:sign2digital/features/profile/data/app_settings_repository.dart';
import 'package:sign2digital/features/profile/presentation/screens/app_settings_screen.dart';
import 'package:sign2digital/features/profile/presentation/widgets/profile_notification_row.dart';

class _Store implements AppSettingsRepository {
  AppSettings saved = const AppSettings();
  bool failLoad = false;
  bool failSave = false;
  int writes = 0;
  @override
  Future<AppSettings> load() async {
    if (failLoad) throw StateError('offline');
    return saved;
  }

  @override
  Future<void> save(AppSettings value) async {
    if (failSave) throw StateError('offline');
    saved = value;
    writes++;
    AppSettingsSession.current.value = value;
  }
}

class _Cache implements AppDisposableCache {
  int calls = 0;
  int fileCount = 3;
  bool fails = false;
  @override
  Future<int> clear() async {
    calls++;
    if (fails) throw StateError('cache unavailable');
    return fileCount;
  }
}

Finder _scrollable() => find.descendant(
  of: find.byKey(const Key('app-settings-scroll')),
  matching: find.byType(Scrollable),
).first;

Future<void> _findCard(WidgetTester tester, String name) async {
  final key = Key('app-settings-$name');
  await tester.scrollUntilVisible(find.byKey(key), 160,
    maxScrolls: 25, scrollable: _scrollable());
  await tester.pumpAndSettle();
}

Future<void> _option(WidgetTester tester, String field, String value) async {
  await _findCard(tester, field);
  await tester.tap(find.byKey(Key('app-settings-$field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppSettingsSession.current.value = const AppSettings());
  tearDown(() => AppSettingsSession.current.value = const AppSettings());

  test('App Settings serializes expected choices and theme modes', () {
    final settings = const AppSettings().copyWith(
      theme: 'System Default',
      documentType: 'Invoice', units: 'Imperial (ft, lb)',
      offlineMode: true);
    final copy = AppSettings.fromJson(settings.toJson());
    expect(copy.themeMode, ThemeMode.system);
    expect(copy.documentType, 'Invoice');
    expect(copy.units, 'Imperial (ft, lb)');
    expect(copy.offlineMode, true);
    expect(const AppSettings().themeMode, ThemeMode.light);
    expect(const AppSettings(theme: 'Dark').themeMode, ThemeMode.dark);
  });

  testWidgets('Matches shared header, five dropdown fields and More tab',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: AppSettingsScreen(
      repository: _Store(), cache: _Cache(),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(Sign2DigitalHeader), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Default Settings'), findsOneWidget);
    await _findCard(tester, 'document-type');
    expect(find.text('Default Document Type'), findsOneWidget);
    await _findCard(tester, 'currency');
    expect(find.text('CHF (swiss franc)'), findsOneWidget);
    await _findCard(tester, 'units');
    expect(find.text('Metric (m, kg)'), findsOneWidget);
    await _findCard(tester, 'clear-cache');
    expect(find.byType(ProfileNotificationRow), findsWidgets);
    expect(tester.widget<Sign2DigitalBottomNavigationBar>(
      find.byType(Sign2DigitalBottomNavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Theme changes immediately and survives reopening',
      (tester) async {
    final store = _Store();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        ElevatedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => AppSettingsScreen(
              repository: store, cache: _Cache(),
            ))),
          child: const Text('Open Settings'),
        ),
      )),
    ));
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    await _option(tester, 'theme', 'Dark');
    expect(store.saved.theme, 'Dark');
    expect(AppSettingsSession.current.value.themeMode, ThemeMode.dark);
    expect(store.writes, 1);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    await _option(tester, 'theme', 'System Default');
    expect(store.saved.themeMode, ThemeMode.system);
    expect(store.writes, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Document type and units persist with no currency conversion',
      (tester) async {
    final store = _Store();
    await tester.pumpWidget(MaterialApp(
      home: AppSettingsScreen(repository: store, cache: _Cache()),
    ));
    await tester.pumpAndSettle();
    await _option(tester, 'document-type', 'Invoice');
    await _option(tester, 'units', 'Imperial (ft, lb)');
    expect(store.saved.documentType, 'Invoice');
    expect(store.saved.units, 'Imperial (ft, lb)');
    expect(store.saved.currency, 'CHF (swiss franc)');
    await _findCard(tester, 'job-view');
    await tester.tap(find.byKey(const Key('app-settings-job-view')));
    await tester.pumpAndSettle();
    expect(find.text('List'), findsWidgets);
    expect(find.text('Grid'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Offline preference is independent from working offline data',
      (tester) async {
    final store = _Store();
    await tester.pumpWidget(MaterialApp(
      home: AppSettingsScreen(repository: store, cache: _Cache()),
    ));
    await tester.pumpAndSettle();
    await _findCard(tester, 'offline-mode');
    expect(tester.widget<ProfileNotificationRow>(
      find.byKey(const Key('app-settings-offline-mode'))).enabled, false);
    await tester.tap(find.byKey(const Key('app-settings-offline-mode')));
    await tester.pump();
    expect(store.saved.offlineMode, true);
    expect(find.textContaining('Offline access is not available'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clear Cache is confirmed one-time action and never persisted',
      (tester) async {
    final store = _Store();
    final cache = _Cache();
    await tester.pumpWidget(MaterialApp(
      home: AppSettingsScreen(repository: store, cache: cache),
    ));
    await tester.pumpAndSettle();
    await _findCard(tester, 'clear-cache');
    await tester.tap(find.byKey(const Key('app-settings-clear-cache')));
    await tester.pumpAndSettle();
    expect(find.text('Clear Cache?'), findsOneWidget);
    expect(cache.calls, 0);
    await tester.tap(find.byKey(const Key('app-settings-cache-cancel')));
    await tester.pumpAndSettle();
    expect(cache.calls, 0);
    await tester.tap(find.byKey(const Key('app-settings-clear-cache')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-settings-cache-confirm')));
    await tester.pump();
    expect(cache.calls, 1);
    expect(store.writes, 0);
    expect(tester.widget<ProfileNotificationRow>(
      find.byKey(const Key('app-settings-clear-cache'))).enabled, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed saves do not change the current setting',
      (tester) async {
    final store = _Store()..failSave = true;
    await tester.pumpWidget(MaterialApp(
      home: AppSettingsScreen(repository: store, cache: _Cache()),
    ));
    await tester.pumpAndSettle();
    await _option(tester, 'theme', 'Dark');
    expect(store.saved.theme, 'Light');
    expect(find.text('Light'), findsOneWidget);
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Load failure shows retry rather than replacing values',
      (tester) async {
    final store = _Store()..failLoad = true;
    await tester.pumpWidget(MaterialApp(
      home: AppSettingsScreen(repository: store, cache: _Cache()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-settings-retry')), findsOneWidget);
    store.failLoad = false;
    await tester.tap(find.byKey(const Key('app-settings-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1024),
  ]) {
    testWidgets('Settings fits and reaches cache action on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: AppSettingsScreen(
        repository: _Store(), cache: _Cache(),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _findCard(tester, 'clear-cache');
      expect(find.byKey(const Key('app-settings-clear-cache')),
        findsOneWidget);
      expect(find.byType(Sign2DigitalBottomNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
