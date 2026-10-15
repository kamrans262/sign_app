import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local app preferences. These values are application choices, not a claim
/// that OS-level notification permissions have been granted.
@immutable
class ProfilePreferences {
  const ProfilePreferences({
    this.language = 'English',
    this.dateFormat = 'DD/MM/YYYY',
    this.timeFormat = '24 hours',
    this.timeZone = 'Europe/Zurich',
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
  });

  final String language;
  final String dateFormat;
  final String timeFormat;
  final String timeZone;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;

  ProfilePreferences copyWith({
    String? language,
    String? dateFormat,
    String? timeFormat,
    String? timeZone,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
  }) => ProfilePreferences(
    language: language ?? this.language,
    dateFormat: dateFormat ?? this.dateFormat,
    timeFormat: timeFormat ?? this.timeFormat,
    timeZone: timeZone ?? this.timeZone,
    pushNotifications: pushNotifications ?? this.pushNotifications,
    emailNotifications: emailNotifications ?? this.emailNotifications,
    smsNotifications: smsNotifications ?? this.smsNotifications,
  );

  Map<String, Object> toJson() => {
    'language': language,
    'dateFormat': dateFormat,
    'timeFormat': timeFormat,
    'timeZone': timeZone,
    'pushNotifications': pushNotifications,
    'emailNotifications': emailNotifications,
    'smsNotifications': smsNotifications,
  };

  factory ProfilePreferences.fromJson(Map<String, dynamic> data) {
    const defaults = ProfilePreferences();
    return ProfilePreferences(
      language: data['language'] is String
          ? data['language'] as String : defaults.language,
      dateFormat: data['dateFormat'] is String
          ? data['dateFormat'] as String : defaults.dateFormat,
      timeFormat: data['timeFormat'] is String
          ? data['timeFormat'] as String : defaults.timeFormat,
      timeZone: data['timeZone'] is String
          ? data['timeZone'] as String : defaults.timeZone,
      pushNotifications: data['pushNotifications'] is bool
          ? data['pushNotifications'] as bool : defaults.pushNotifications,
      emailNotifications: data['emailNotifications'] is bool
          ? data['emailNotifications'] as bool : defaults.emailNotifications,
      smsNotifications: data['smsNotifications'] is bool
          ? data['smsNotifications'] as bool : defaults.smsNotifications,
    );
  }
}

abstract class ProfilePreferencesRepository {
  Future<ProfilePreferences> load();
  Future<void> save(ProfilePreferences preferences);
}

/// Shared in-process state can be listened to by future date/time formatters
/// and notification clients. Do not update it until a save succeeds.
abstract final class ProfilePreferencesSession {
  static final ValueNotifier<ProfilePreferences> current =
      ValueNotifier<ProfilePreferences>(const ProfilePreferences());
}

/// Uses the app's existing path_provider dependency; no additional package.
/// Store is device-local, not synchronized to a user account or a server.
class LocalProfilePreferencesRepository
    implements ProfilePreferencesRepository {
  const LocalProfilePreferencesRepository();

  static const shared = LocalProfilePreferencesRepository();

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}'
        'sign2digital_profile_preferences.json');
  }

  @override
  Future<ProfilePreferences> load() async {
    final file = await _file();
    if (!await file.exists()) {
      ProfilePreferencesSession.current.value = const ProfilePreferences();
      return const ProfilePreferences();
    }
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid preferences data');
    }
    final preferences = ProfilePreferences.fromJson(json);
    ProfilePreferencesSession.current.value = preferences;
    return preferences;
  }

  @override
  Future<void> save(ProfilePreferences preferences) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(preferences.toJson()), flush: true);
    ProfilePreferencesSession.current.value = preferences;
  }
}
