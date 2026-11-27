import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Canonical preference values remain compatible with the existing API.
abstract final class AppLanguages {
  static const names = ['English', 'French', 'German', 'Italian'];
  static const supportedLocales = [
    Locale('en'), Locale('fr'), Locale('de'), Locale('it'),
  ];

  static Locale? fromName(String name) {
    final index = names.indexOf(name);
    return index < 0 ? null : supportedLocales[index];
  }

  static Locale? fromCode(String? code) {
    for (final locale in supportedLocales) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }

  static Locale resolve(Iterable<Locale> preferred) {
    for (final locale in preferred) {
      final supported = fromCode(locale.languageCode);
      if (supported != null) return supported;
    }
    return supportedLocales.first;
  }

  static String nameFor(Locale locale) =>
      names[supportedLocales.indexOf(resolve([locale]))];
}

/// Device-local interface language only; never stores account or company data.
/// A null choice follows the device's supported language, with English fallback.
class AppLanguageController extends ValueNotifier<Locale?> {
  AppLanguageController({
    required Future<String?> Function() readCode,
    required Future<void> Function(String) writeCode,
  }) : _readCode = readCode, _writeCode = writeCode, super(null);

  static final shared = AppLanguageController(
    readCode: _readDeviceCode, writeCode: _writeDeviceCode,
  );

  final Future<String?> Function() _readCode;
  final Future<void> Function(String) _writeCode;

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}'
        'sign2digital_interface_language.txt');
  }

  static Future<String?> _readDeviceCode() async {
    if (kIsWeb) return null;
    final file = await _file();
    return await file.exists() ? (await file.readAsString()).trim() : null;
  }

  static Future<void> _writeDeviceCode(String code) async {
    if (kIsWeb) return;
    final file = await _file();
    await file.parent.create(recursive: true);
    // Write to a sibling first so a failed write cannot truncate the choice.
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(code, flush: true);
    await pending.rename(file.path);
  }

  Future<void> restore() async {
    try {
      value = AppLanguages.fromCode(await _readCode());
    } catch (_) {
      // Corrupt/unavailable storage must not prevent app startup.
      value = null;
    }
  }

  Locale effectiveLocale(Iterable<Locale> deviceLocales) =>
      value ?? AppLanguages.resolve(deviceLocales);

  Future<void> select(String name) async {
    final locale = AppLanguages.fromName(name);
    if (locale == null) throw ArgumentError.value(name, 'name');
    await _writeCode(locale.languageCode);
    value = locale;
  }
}
