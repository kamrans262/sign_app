import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Device-local display choices. Values do not modify existing records.
@immutable
class AppSettings {
  const AppSettings({
    this.theme = 'Light',
    this.jobView = 'List',
    this.documentType = 'Quote',
    this.currency = 'CHF (Swiss franc)',
    this.units = 'Metric (m, kg)',
    this.offlineMode = false,
  });

  final String theme;
  final String jobView;
  final String documentType;
  final String currency;
  /// ISO code for new quotations; never use this to relabel saved CHF records.
  String get currencyCode => switch (currency.toUpperCase().split(' ').first) {
    'EUR' => 'EUR', 'GBP' => 'GBP', 'USD' => 'USD', _ => 'CHF',
  };
  final String units;
  /// Preference only: offline access requires a separate cache/sync service.
  final bool offlineMode;

  ThemeMode get themeMode => switch (theme) {
    'Dark' => ThemeMode.dark,
    'System Default' => ThemeMode.system,
    _ => ThemeMode.light,
  };

  AppSettings copyWith({
    String? theme,
    String? jobView,
    String? documentType,
    String? currency,
    String? units,
    bool? offlineMode,
  }) => AppSettings(
    theme: theme ?? this.theme,
    jobView: jobView ?? this.jobView,
    documentType: documentType ?? this.documentType,
    currency: currency ?? this.currency,
    units: units ?? this.units,
    offlineMode: offlineMode ?? this.offlineMode,
  );

  Map<String, Object> toJson() => {
    'theme': theme,
    'jobView': jobView,
    'documentType': documentType,
    'currency': currency,
    'units': units,
    'offlineMode': offlineMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const defaults = AppSettings();
    String read(String key, String fallback) =>
        json[key] is String ? json[key] as String : fallback;
    return AppSettings(
      theme: read('theme', defaults.theme),
      jobView: read('jobView', defaults.jobView),
      documentType: read('documentType', defaults.documentType),
      currency: read('currency', defaults.currency)
          .replaceFirst('CHF (swiss franc)', 'CHF (Swiss franc)'),
      units: read('units', defaults.units),
      offlineMode: json['offlineMode'] is bool
          ? json['offlineMode'] as bool : defaults.offlineMode,
    );
  }
}

abstract class AppSettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// App-wide observable settings. Updated only after successful file writes.
abstract final class AppSettingsSession {
  static final ValueNotifier<AppSettings> current =
      ValueNotifier<AppSettings>(const AppSettings());
}

class LocalAppSettingsRepository implements AppSettingsRepository {
  const LocalAppSettingsRepository();
  static const shared = LocalAppSettingsRepository();

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}'
        'sign2digital_app_settings.json');
  }

  @override
  Future<AppSettings> load() async {
    final file = await _file();
    if (!await file.exists()) {
      AppSettingsSession.current.value = const AppSettings();
      return const AppSettings();
    }
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid app settings');
    }
    final result = AppSettings.fromJson(json);
    AppSettingsSession.current.value = result;
    return result;
  }

  @override
  Future<void> save(AppSettings settings) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
    AppSettingsSession.current.value = settings;
  }
}

/// Cache cleaner can only delete files from our *dedicated disposable cache
/// directory*, never user documents, account data, drafts, or unsynced work.
abstract class AppDisposableCache {
  Future<int> clear();
}

class LocalDisposableCache implements AppDisposableCache {
  const LocalDisposableCache();
  static const shared = LocalDisposableCache();

  @override
  Future<int> clear() async {
    final temp = await getTemporaryDirectory();
    final cache = Directory('${temp.path}${Platform.pathSeparator}'
        'sign2digital_disposable_cache');
    if (!await cache.exists()) {
      return 0;
    }
    var count = 0;
    await for (final entry in cache.list(followLinks: false)) {
      // Only direct disposable entries under our own cache folder.
      await entry.delete(recursive: true);
      count++;
    }
    return count;
  }
}
