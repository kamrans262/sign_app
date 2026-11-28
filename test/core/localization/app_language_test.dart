import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/localization/app_language_controller.dart';
import 'package:sign2digital/core/localization/app_strings.dart';
import 'package:sign2digital/core/widgets/sign2digital_bottom_navigation_bar.dart';
import 'package:sign2digital/features/profile/data/profile_preferences_repository.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_preferences_screen.dart';

class _Repo implements ProfilePreferencesRepository {
  ProfilePreferences saved = const ProfilePreferences();
  bool fail = false;

  @override
  Future<ProfilePreferences> load() async => saved;

  @override
  Future<void> save(ProfilePreferences preferences) async {
    if (fail) throw StateError('offline');
    saved = preferences;
  }
}

void main() {
  test('Supported language names and device locale resolution', () {
    expect(AppLanguages.names, ['English', 'French', 'German', 'Italian']);
    for (final name in AppLanguages.names) {
      expect(AppLanguages.nameFor(AppLanguages.fromName(name)!), name);
    }
    expect(AppLanguages.resolve([const Locale('fr', 'CH')]), const Locale('fr'));
    expect(AppLanguages.resolve([const Locale('es'), const Locale('de', 'CH')]),
        const Locale('de'));
    expect(AppLanguages.resolve([const Locale('it', 'CH')]), const Locale('it'));
    expect(AppLanguages.resolve([const Locale('ur')]), const Locale('en'));
    expect(AppLanguages.modeDefault(release: false), const Locale('en'));
    expect(AppLanguages.modeDefault(release: true), const Locale('fr'));
    expect(AppLanguages.resolve(const [Locale('ur')], release: true),
        const Locale('fr'));
    expect(AppLanguages.resolve(const [Locale('de')], release: true),
        const Locale('de'));
  });

  test('An unsaved choice stays English in debug even on a French device', () async {
    final language = AppLanguageController(
      readCode: () async => null, writeCode: (_) async {},
    );
    await language.restore();
    expect(language.effectiveLocale([const Locale('fr', 'CH')]), const Locale('en'));
    language.dispose();
  });

  test('Explicit choice persists and invalid storage safely falls back', () async {
    String? stored;
    AppLanguageController controller() => AppLanguageController(
      readCode: () async => stored,
      writeCode: (code) async { stored = code; },
    );
    final first = controller();
    await first.restore();
    expect(first.value, isNull);
    await first.select('Italian');
    expect(stored, 'it');
    final restored = controller();
    await restored.restore();
    expect(restored.value, const Locale('it'));
    stored = 'unsupported';
    await restored.restore();
    expect(restored.value, isNull);
    first.dispose();
    restored.dispose();
  });

  test('Failed persistence does not change the live locale', () async {
    final language = AppLanguageController(
      readCode: () async => 'fr',
      writeCode: (_) async => throw StateError('disk error'),
    );
    await language.restore();
    await expectLater(language.select('German'), throwsStateError);
    expect(language.value, const Locale('fr'));
    language.dispose();
  });

  test('Catalogs preserve English and unknown keys', () {
    expect(const AppStrings(Locale('en')).tr('Save Preferences'), 'Save Preferences');
    expect(const AppStrings(Locale('fr')).tr('Save Preferences'), 'Enregistrer');
    expect(const AppStrings(Locale('de')).tr('Save Preferences'), 'Speichern');
    expect(const AppStrings(Locale('it')).tr('Save Preferences'), 'Salva preferenze');
    expect(const AppStrings(Locale('fr')).tr('untranslated'), 'untranslated');
  });

  testWidgets('Changing language retains route and existing bottom-nav style',
      (tester) async {
    final language = AppLanguageController(
      readCode: () async => 'en', writeCode: (_) async {},
    );
    await language.restore();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ValueListenableBuilder<Locale?>(
      valueListenable: language,
      builder: (_, locale, child) => MaterialApp(
        navigatorKey: nav,
        locale: locale,
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate, ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(bottomNavigationBar: Sign2DigitalBottomNavigationBar(
          selectedIndex: 0, onSelected: (_) {},
        )),
      ),
    ));
    await tester.pumpAndSettle();
    final style = tester.widget<Text>(find.text('Home')).style;
    final navigator = nav.currentState;
    for (final pair in [
      ('French', 'Accueil'), ('German', 'Start'), ('Italian', 'Home'),
      ('English', 'Home'),
    ]) {
      await language.select(pair.$1);
      await tester.pumpAndSettle();
      expect(find.text(pair.$2), findsOneWidget);
      expect(tester.widget<Text>(find.text(pair.$2)).style, style);
      expect(nav.currentState, same(navigator));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    language.dispose();
  });

  testWidgets('Language changes immediately even if account preference save fails',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo()..fail = true;
    String? stored;
    final language = AppLanguageController(
      readCode: () async => 'en',
      writeCode: (code) async { stored = code; },
    );
    await language.restore();
    await tester.pumpWidget(ValueListenableBuilder<Locale?>(
      valueListenable: language,
      builder: (_, locale, child) => MaterialApp(
        locale: locale,
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate, ...GlobalMaterialLocalizations.delegates,
        ],
        home: ProfilePreferencesScreen(repository: repo, languageController: language),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preferences-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preferences-option-French')));
    await tester.pumpAndSettle();
    expect(language.value, const Locale('fr'));
    expect(stored, 'fr');
    expect(repo.saved.language, 'English');
    expect(find.text('Préférences'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    final save = find.byKey(const Key('preferences-save'));
    if (save.evaluate().isEmpty) {
      await tester.scrollUntilVisible(save, 180, scrollable: find.descendant(
        of: find.byKey(const Key('preferences-scroll')),
        matching: find.byType(Scrollable),
      ).first);
    }
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(language.value, const Locale('fr'));
    expect(stored, 'fr');
    expect(repo.saved.language, 'English');
    repo.fail = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(stored, 'fr');
    expect(repo.saved.language, 'French');
    expect(language.value, const Locale('fr'));
    expect(find.text('Préférences'), findsOneWidget);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    language.dispose();
  });
}
