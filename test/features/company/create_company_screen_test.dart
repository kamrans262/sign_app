// Sign2Digital — Create Company UI regression tests.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/scroll_to_visible_action.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import '../../support/fake_voice_services.dart';
import 'package:sign2digital/core/widgets/sign2digital_country_selector.dart';
import 'package:sign2digital/core/widgets/sign2digital_document_upload.dart';
import 'package:sign2digital/core/widgets/sign2digital_image_upload.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/features/company/presentation/screens/create_company_screen.dart';
import 'package:sign2digital/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:sign2digital/features/auth/presentation/screens/otp_verification_screen.dart';

class _SavedCompanyVoiceRecorder extends FakeVoiceRecorder {
  _SavedCompanyVoiceRecorder(this.path);
  final String path;
  @override
  Future<String> save() async {
    await super.save();
    return path;
  }
}

void configureSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('company form reuses nine fields and both upload controls', (
    tester,
  ) async {
    configureSize(tester, const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: CreateCompanyScreen()));
    expect(find.text('Create Your Company'), findsOneWidget);
    expect(find.byKey(const Key('create-company-ai-voice')), findsOneWidget);
    expect(find.text('Create with AI Voice'), findsOneWidget);
    expect(find.byType(Sign2DigitalInputField), findsNWidgets(9));
    expect(find.byType(Sign2DigitalImageUpload), findsOneWidget);
    expect(find.byType(Sign2DigitalDocumentUpload), findsOneWidget);
    expect(find.byType(Sign2DigitalCountrySelector), findsOneWidget);
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-company-scroll'),
      target: find.byKey(const Key('save-company-button')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('company form remains scrollable on compact phone', (
    tester,
  ) async {
    configureSize(tester, const Size(320, 640));
    await tester.pumpWidget(const MaterialApp(home: CreateCompanyScreen()));
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-company-scroll'),
      target: find.byKey(const Key('skip-company-optional')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('local save exposes draft, no backend call is made', (
    tester,
  ) async {
    configureSize(tester, const Size(430, 932));
    CompanyDraft? draft;
    await tester.pumpWidget(
      MaterialApp(home: CreateCompanyScreen(onSave: (value) => draft = value)),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alpine Studio');
    await tester.enterText(fields.at(3), 'hello@alpine.ch');
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-company-scroll'),
      target: find.byKey(const Key('save-company-button')),
    );
    await tester.tap(find.byKey(const Key('save-company-button')));
    await tester.pump();
    expect(draft?.companyName, 'Alpine Studio');
    expect(draft?.country.dialCode, '+41');
    expect(draft?.email, 'hello@alpine.ch');
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid email is rejected locally', (tester) async {
    configureSize(tester, const Size(430, 932));
    var called = false;
    await tester.pumpWidget(
      MaterialApp(home: CreateCompanyScreen(onSave: (_) => called = true)),
    );
    await tester.enterText(find.byType(TextFormField).at(3), 'not-an-email');
    await scrollToVisibleAction(
      tester,
      scrollKey: const Key('create-company-scroll'),
      target: find.byKey(const Key('save-company-button')),
    );
    await tester.tap(find.byKey(const Key('save-company-button')));
    await tester.pump();
    expect(called, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Send Reset Link opens OTP preview with valid email', (
    tester,
  ) async {
    configureSize(tester, const Size(430, 932));
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.enterText(find.byType(TextFormField).first, 'marc@company.ch');
    await tester.ensureVisible(find.text('Send Reset Link'));
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('company AI dictation fills blank fields but preserves manual entries',
      (tester) async {
    configureSize(tester, const Size(430, 932));
    final temp = await Directory.systemTemp.createTemp('s2d-company-ai');
    addTearDown(() => temp.delete(recursive: true));
    final voice = File('${temp.path}/company.m4a');
    await voice.writeAsBytes(List<int>.filled(24, 1));
    final recorder = _SavedCompanyVoiceRecorder(voice.path);
    var uploads = 0;
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        uploads++;
        expect(request.url.path, '/api/v1/ai/companies/voice');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(jsonEncode({
          'data': {
            'suggestions': {
              'companyName': 'Should not replace manual entry',
              'address': 'Rue de Lausanne 3',
              'email': 'office@alpine.ch',
              'countryIsoCode': 'CH',
            },
            'requires_user_review': true,
          },
        }), 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: CreateCompanyScreen(
      aiClient: api,
      voiceRecorderFactory: () => recorder,
      onSave: (_) {},
    )));
    final company = tester.widget<Sign2DigitalInputField>(
      find.widgetWithText(Sign2DigitalInputField, 'Company Name'));
    company.controller.text = 'My Existing Company';

    await tester.tap(find.byKey(const Key('create-with-ai-voice-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Record Company Details'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-save')));
    await tester.pumpAndSettle();

    final address = tester.widget<Sign2DigitalInputField>(
      find.widgetWithText(Sign2DigitalInputField, 'Address'));
    final email = tester.widget<Sign2DigitalInputField>(
      find.widgetWithText(Sign2DigitalInputField, 'E-mail'));
    expect(company.controller.text, 'My Existing Company');
    expect(address.controller.text, 'Rue de Lausanne 3');
    expect(email.controller.text, 'office@alpine.ch');
    expect(uploads, 1);
    expect(recorder.disposed, isTrue);
    api.dispose();
  });
}
