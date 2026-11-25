import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_field.dart';
import 'package:sign2digital/core/widgets/sign2digital_primary_button.dart';
import 'package:sign2digital/core/widgets/sign2digital_outlined_button.dart';
import 'package:sign2digital/features/auth/data/demo_account_repository.dart';
import 'package:sign2digital/features/auth/data/remote_account_repository.dart';
import 'package:sign2digital/features/profile/data/app_settings_repository.dart';
import 'package:sign2digital/features/profile/data/profile_preferences_repository.dart';
import 'package:sign2digital/features/profile/data/remote_support_repository.dart';
import 'package:sign2digital/features/profile/presentation/screens/app_settings_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/change_account_password_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/help_support_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/privacy_data_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_preferences_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/security_access_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/verified_email_change_screen.dart';

class _LocalPreferences implements ProfilePreferencesRepository {
  @override
  Future<ProfilePreferences> load() async => const ProfilePreferences();
  @override
  Future<void> save(ProfilePreferences value) async {}
}

class _LocalSettings implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> save(AppSettings value) async {}
}

RemoteSupportRepository _support() {
  final api = SignApiClient(
    baseUrl: Uri.parse('https://example.test'),
    tokenProvider: () async => 'stage-two-test-token',
    httpClient: MockClient((request) async {
      final data = switch (request.url.path) {
        '/api/v1/support/faqs' => {'records': <Object>[]},
        '/api/v1/support/tickets' => {
          'records': <Object>[],
          'pagination': {'page': 1, 'total': 0, 'has_more': false},
        },
        '/api/v1/support/tickets/7' => {
          'ticket': {
            'id': 7, 'reference': 'S2D-7', 'subject': 'Screen check',
            'description': 'Landscape support ticket',
            'status': 'open', 'category': 'technical',
            'created_at': '2026-11-06',
          },
          'replies': <Object>[],
          'attachments': <Object>[],
        },
        _ => throw StateError('Unexpected support request: ${request.url.path}'),
      };
      return http.Response(jsonEncode({'data': data}), 200,
        headers: {'content-type': 'application/json'});
    }),
  );
  return RemoteSupportRepository(api: api);
}

void main() {
  final profiles = <(String, Widget, Key)>[
    ('profile', ProfileSettingsScreen(
      accountRepository: DemoAccountRepository()), const Key('profile-settings-scroll')),
    ('edit profile', EditProfileScreen(
      repository: DemoAccountRepository()), const Key('profile-edit-scroll')),
    ('preferences', ProfilePreferencesScreen(
      repository: _LocalPreferences()), const Key('preferences-scroll')),
    ('security', const SecurityAccessScreen(), const Key('security-scroll')),
    ('settings', AppSettingsScreen(
      repository: _LocalSettings()), const Key('app-settings-scroll')),
    ('privacy', const PrivacyDataScreen(), const Key('m22-privacy-scroll')),
    ('help center', HelpSupportScreen(repository: _support()),
      const Key('m22-help-scroll')),
    ('support ticket details', SupportTicketDetailsScreen(
      ticketId: 7, repository: _support()), const Key('m22-ticket-detail')),
  ];

  for (final entry in profiles) {
    testWidgets('${entry.$1} is full-width in tablet landscape', (tester) async {
      tester.view.physicalSize = const Size(1180, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: entry.$2));
      await tester.pumpAndSettle();
      expect(find.byKey(entry.$3), findsOneWidget);
      final width = tester.getSize(find.byKey(entry.$3)).width;
      expect(width, greaterThan(1000),
          reason: '${entry.$1} must not be capped at 720px in landscape');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('portrait retains the approved constrained profile layout',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: ProfileSettingsScreen(
      accountRepository: DemoAccountRepository())));
    await tester.pumpAndSettle();
    final width = tester.getSize(
      find.byKey(const Key('profile-settings-scroll'))).width;
    expect(width, lessThanOrEqualTo(720));
    expect(tester.takeException(), isNull);
  });

  testWidgets('verification and password forms use landscape width',
      (tester) async {
    tester.view.physicalSize = const Size(1180, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: ChangeAccountPasswordScreen()));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('m22-pass-current'))).width,
      greaterThan(1000));
    await tester.pumpWidget(MaterialApp(
      home: VerifiedEmailChangeScreen(
        newEmail: 'new@example.test', repository: RemoteAccountRepository())));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('m22-email-password'))).width,
      greaterThan(1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('security and verification fields use approved icon input and primary action',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ChangeAccountPasswordScreen()));
    await tester.pumpAndSettle();
    for (final entry in [
      (const Key('m22-pass-current'), Icons.lock_outline_rounded),
      (const Key('m22-pass-new'), Icons.key_outlined),
      (const Key('m22-pass-confirm'), Icons.verified_user_outlined),
    ]) {
      expect(tester.widget<Sign2DigitalInputField>(
          find.byKey(entry.$1)).leadingIcon, entry.$2);
    }
    expect(find.byKey(const Key('m22-pass-save')), findsOneWidget);
    expect(tester.widget<Sign2DigitalPrimaryButton>(
        find.byKey(const Key('m22-pass-save'))).label, 'Change Password');

    await tester.pumpWidget(MaterialApp(
      home: VerifiedEmailChangeScreen(
        newEmail: 'verified@example.test',
        repository: RemoteAccountRepository())));
    await tester.pumpAndSettle();
    expect(tester.widget<Sign2DigitalInputField>(
        find.byKey(const Key('m22-email-password'))).leadingIcon,
        Icons.lock_outline_rounded);
    expect(tester.widget<Sign2DigitalPrimaryButton>(
        find.byKey(const Key('m22-email-next'))).label,
        'Send verification code');
    expect(tester.takeException(), isNull);
  });

  testWidgets('support form uses icon fields and approved action buttons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NewSupportTicketScreen(repository: _support())));
    await tester.pumpAndSettle();
    expect(tester.widget<Sign2DigitalSelectionField>(
        find.byKey(const Key('m22-support-category'))).leadingIcon,
        Icons.support_agent_outlined);
    expect(tester.widget<Sign2DigitalInputField>(
        find.byKey(const Key('m22-support-subject'))).leadingIcon,
        Icons.subject_outlined);
    expect(tester.widget<Sign2DigitalInputField>(
        find.byKey(const Key('m22-support-description'))).leadingIcon,
        Icons.description_outlined);
    expect(find.byKey(const Key('m22-support-screenshot')), findsOneWidget);
    expect(tester.widget<Sign2DigitalOutlinedButton>(
        find.byKey(const Key('m22-support-screenshot'))).primaryOutline,
        isTrue);
    expect(tester.widget<Sign2DigitalPrimaryButton>(
        find.byKey(const Key('m22-support-submit'))).label,
        'Submit Support Ticket');
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy actions keep branded primary and destructive buttons',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PrivacyDataScreen()));
    await tester.pumpAndSettle();
    expect(tester.widget<Sign2DigitalPrimaryButton>(
        find.byKey(const Key('m22-privacy-export'))).label,
        'Copy My Account Data');
    expect(tester.widget<Sign2DigitalOutlinedButton>(
        find.byKey(const Key('m22-privacy-deactivate'))).primaryOutline,
        isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const Key('m22-privacy-delete')), 160,
      scrollable: find.byType(Scrollable).first);
    expect(tester.widget<Sign2DigitalOutlinedButton>(
        find.byKey(const Key('m22-privacy-delete'))).destructive,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create support ticket uses tablet landscape width',
      (tester) async {
    tester.view.physicalSize = const Size(1180, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: NewSupportTicketScreen(repository: _support())));
    await tester.pumpAndSettle();
    final width = tester.getSize(
      find.byKey(const Key('m22-support-category'))).width;
    expect(width, greaterThan(1000));
    expect(tester.takeException(), isNull);
  });
}
