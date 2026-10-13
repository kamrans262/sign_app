import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/clients/data/demo_client_repository.dart';
import 'package:sign2digital/features/clients/domain/client_profile.dart';
import 'package:sign2digital/features/clients/presentation/screens/client_details_screen.dart';
import 'package:sign2digital/features/jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';
import 'package:sign2digital/features/quotes/domain/quote_draft_input.dart';
import 'package:sign2digital/features/quotes/presentation/screens/create_quote_screen.dart';
import 'package:sign2digital/features/quotes/presentation/widgets/sign2digital_quote_input_method_card.dart';

class _FakeRecorder implements VoiceRecorderService {
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int cancels = 0;
  int saves = 0;

  @override
  Stream<double> get amplitude => const Stream<double>.empty();
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<String> save() async {
    saves++;
    return '/test/captured_audio.m4a';
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('New Quote in Client Details opens new screen', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ClientDetailsScreen(
          client: const ClientProfile(
            id: 'client-1',
            companyName: 'Alpine Builds',
            companyType: 'Business',
            email: 'a@example.com',
            phone: '',
            jobCount: 0,
          ),
          repository: DemoClientRepository(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('New Quote'));
    await tester.tap(find.text('New Quote'));
    await tester.pumpAndSettle();
    expect(find.text('Create Quote'), findsOneWidget);
    expect(find.byKey(const Key('quote-method-voice')), findsOneWidget);
  });

  testWidgets('new Create Quote screen matches method defaults and selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CreateQuoteScreen()));
    expect(find.text('Create Quote'), findsOneWidget);
    expect(find.text('Example Prompt'), findsNothing);
    final voice = tester.widget<Sign2DigitalQuoteInputMethodCard>(
      find.byKey(const Key('quote-method-voice')),
    );
    expect(voice.selected, isTrue);
    await tester.tap(find.byKey(const Key('quote-method-text')));
    await tester.pump();
    expect(
      tester
          .widget<Sign2DigitalQuoteInputMethodCard>(
            find.byKey(const Key('quote-method-text')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<Sign2DigitalQuoteInputMethodCard>(
            find.byKey(const Key('quote-method-voice')),
          )
          .selected,
      isFalse,
    );
    expect(find.byKey(const Key('quote-text-input')), findsOneWidget);
    expect(find.text('Example Prompt'), findsOneWidget);
    expect(find.text('Project Details'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('text input is validated and prepared with originating client', (
    tester,
  ) async {
    QuoteDraftInput? prepared;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateQuoteScreen(
          clientId: 'client-test-1',
          onInputPrepared: (input) => prepared = input,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('quote-method-text')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('quote-generate-draft')));
    await tester.tap(find.byKey(const Key('quote-generate-draft')));
    await tester.pump();
    expect(prepared, isNull);
    await tester.enterText(
      find.byKey(const Key('quote-text-input')),
      'Replace the windows, including removal and disposal.',
    );
    await tester.ensureVisible(find.byKey(const Key('quote-generate-draft')));
    await tester.tap(find.byKey(const Key('quote-generate-draft')));
    await tester.pump();
    expect(prepared?.clientId, 'client-test-1');
    expect(prepared?.method, QuoteInputMethod.text);
    expect(prepared?.description, contains('Replace the windows'));
  });

  testWidgets(
    'Voice card opens the shared popup immediately and cancel works',
    (tester) async {
      final recorder = _FakeRecorder();
      await tester.pumpWidget(
        MaterialApp(
          home: CreateQuoteScreen(voiceRecorderFactory: () => recorder),
        ),
      );
      await tester.tap(find.byKey(const Key('quote-method-voice')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AiVoiceFlowDialog), findsOneWidget);
      expect(recorder.starts, 1);
      expect(find.text('Record Quote Details'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-cancel')));
      await tester.pumpAndSettle();
      expect(recorder.cancels, 1);
      expect(find.byType(AiVoiceFlowDialog), findsNothing);
    },
  );

  testWidgets(
    'Save preserves captured audio without pretending a quote exists',
    (tester) async {
      final recorder = _FakeRecorder();
      QuoteDraftInput? prepared;
      await tester.pumpWidget(
        MaterialApp(
          home: CreateQuoteScreen(
            voiceRecorderFactory: () => recorder,
            onInputPrepared: (input) => prepared = input,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('quote-method-voice')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('voice-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(recorder.saves, 1);
      expect(find.byType(AiVoiceFlowDialog), findsNothing);
      expect(prepared?.audioPath, '/test/captured_audio.m4a');
      expect(prepared?.method, QuoteInputMethod.voice);
    },
  );

  testWidgets('Photo method displays reusable full-width upload card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateQuoteScreen(pickImage: (source) async => null)),
    );
    await tester.tap(find.byKey(const Key('quote-method-photo')));
    await tester.pump();
    expect(find.byKey(const Key('quote-photo-upload')), findsOneWidget);
    expect(find.text('Upload Image'), findsOneWidget);
    expect(find.text('Example Prompt'), findsNothing);
    expect(find.text('Project Details'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('quote-photo-upload')));
    await tester.tap(find.byKey(const Key('quote-photo-upload')));
    await tester.pumpAndSettle();
    expect(find.text('Choose from Gallery'), findsOneWidget);
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-remove-photo')), findsNothing);
  });

  testWidgets('upload image retains the selected file for AI', (tester) async {
    final directory = await Directory.systemTemp.createTemp('quote_photo_');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}notes.png';
    await File(path).writeAsBytes(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6j2EAAAAASUVORK5CYII='
    ));
    QuoteDraftInput? captured;
    await tester.pumpWidget(MaterialApp(home: CreateQuoteScreen(
      pickImage: (source) async => XFile(path),
      onInputPrepared: (input) => captured = input,
    )));
    await tester.tap(find.byKey(const Key('quote-method-photo')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('quote-photo-upload')));
    await tester.tap(find.byKey(const Key('quote-photo-upload')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-remove-photo')), findsOneWidget);
    expect(find.text('Change Image'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('quote-generate-draft')));
    await tester.tap(find.byKey(const Key('quote-generate-draft')));
    await tester.pump();
    expect(captured?.method, QuoteInputMethod.handwrittenPhoto);
    expect(captured?.photoPath, path);
  });

  testWidgets('Text Generate requires temporary OpenAI key, cancel is safe', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateQuoteScreen()));
    await tester.tap(find.byKey(const Key('quote-method-text')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('quote-text-input')),
        'Remove damaged tiles and install 10 new ceramic tiles.');
    await tester.ensureVisible(find.byKey(const Key('quote-generate-draft')));
    await tester.tap(find.byKey(const Key('quote-generate-draft')));
    await tester.pumpAndSettle();
    expect(find.text('Connect Quote AI'), findsOneWidget);
    expect(find.byKey(const Key('quote-openai-api-key')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Quote AI'), findsNothing);
    expect(find.text('Remove damaged tiles and install 10 new ceramic tiles.'),
        findsOneWidget);
  });

  testWidgets('no layout exceptions in narrow portrait or landscape', (
    tester,
  ) async {
    for (final size in [const Size(320, 640), const Size(740, 370)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: CreateQuoteScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
