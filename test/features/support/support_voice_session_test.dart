import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';
import 'package:sign2digital/features/support/data/support_assistant_repository.dart';
import 'package:sign2digital/features/support/data/support_chat_session.dart';
import 'package:sign2digital/features/support/data/support_voice_transcription.dart';
import 'package:sign2digital/features/support/presentation/widgets/support_ai_prompt_hint.dart';
import 'package:sign2digital/features/support/presentation/widgets/support_assistant_sheet.dart';

class _FakeSupport implements SupportAssistantRepository {
  final questions = <String>[];
  @override
  Future<AssistantAnswer> ask({required String message, required String screen,
      required List<AssistantTurn> history}) async {
    questions.add(message);
    return const AssistantAnswer(
      answer: 'Open Jobs, select the job and choose Quotes.',
      screen: 'jobs',
      samplePrompt: 'Create a quotation for three wooden doors.');
  }

  @override
  Future<GettingStartedProgress> progress() async =>
      const GettingStartedProgress(eligible: true, completed: {});
}

class _FakeRecorder implements VoiceRecorderService {
  _FakeRecorder(this.path);
  final String path;
  bool started = false;
  bool disposed = false;

  @override
  Stream<double> get amplitude => const Stream<double>.empty();

  @override
  Future<void> start() async => started = true;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> save() async {
    await File(path).writeAsBytes([0, 0, 0, 20, 102, 116, 121, 112, 0, 0, 0, 0]);
    return path;
  }
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async => disposed = true;
}

class _FakeTranscriber implements SupportVoiceTranscription {
  int calls = 0;
  @override
  Future<String> transcribe(String audioPath) async {
    calls++;
    expect(await File(audioPath).exists(), isTrue);
    return 'How do I create a quote for an existing job?';
  }
}

void main() {
  setUp(() {
    ActiveCompanySession.clear();
    SupportChatSession.clear();
  });

  testWidgets('Support conversation and sample survive closing and reopening',
      (tester) async {
    final fake = _FakeSupport();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SupportAssistantSheet(key: const ValueKey('chat-first'),
        screen: 'home', repository: fake))));
    await tester.tap(find.byKey(const Key('support-question-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open Jobs, select the job'), findsOneWidget);
    expect(find.textContaining('Create a quotation for three wooden doors.'),
      findsOneWidget);
    expect(find.byKey(const Key('support-open-jobs')), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SupportAssistantSheet(key: const ValueKey('chat-second'),
        screen: 'jobs', repository: fake))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open Jobs, select the job'), findsOneWidget);
    expect(find.byKey(const Key('support-open-jobs')), findsOneWidget);
    expect(fake.questions, hasLength(1));
  });

  testWidgets('Voice microphone transcribes and asks AI without typing',
      (tester) async {
    final dir = await Directory.systemTemp.createTemp('s2d-support-voice');
    addTearDown(() async => dir.delete(recursive: true));
    final recorder = _FakeRecorder('${dir.path}/support.m4a');
    final transcriber = _FakeTranscriber();
    final support = _FakeSupport();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SupportAssistantSheet(
        screen: 'home', repository: support,
        voiceRecorderFactory: () => recorder,
        transcription: transcriber,
      ))));
    await tester.tap(find.byKey(const Key('support-voice')));
    await tester.pumpAndSettle();
    expect(recorder.started, isTrue);
    expect(find.textContaining('Recording...'), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-voice')));
    await tester.pumpAndSettle();
    expect(transcriber.calls, 1);
    expect(support.questions,
      ['How do I create a quote for an existing job?']);
    expect(find.textContaining('Open Jobs, select the job'), findsOneWidget);
    expect(await File(recorder.path).exists(), isFalse);
    expect(recorder.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Company switch and logout erase in-memory assistant messages',
      (tester) async {
    final revision = SupportChatSession.revision;
    expect(SupportChatSession.append(const SupportChatMessage(
      role: 'user', content: 'private company context'),
      revision: revision), isTrue);
    expect(SupportChatSession.snapshot(), hasLength(1));
    ActiveCompanySession.set(42);
    expect(SupportChatSession.snapshot(), isEmpty);
    final next = SupportChatSession.revision;
    SupportChatSession.append(const SupportChatMessage(
      role: 'assistant', content: 'new company'), revision: next);
    SupportChatSession.clear();
    expect(SupportChatSession.snapshot(), isEmpty);
    expect(SupportChatSession.append(const SupportChatMessage(
      role: 'assistant', content: 'late old response'),
      revision: next), isFalse);
  });

  testWidgets('Prompt hint is shown only for a verified voice module',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(
      children: [
        SupportAiPromptHint(module: 'quotes', onTap: () => opened++),
        SupportAiPromptHint(module: 'reports', onTap: () => opened++),
      ],
    ))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-support-sample-quotes')), findsOneWidget);
    expect(find.byKey(const Key('ai-support-sample-reports')), findsNothing);
    await tester.tap(find.byKey(const Key('ai-support-sample-quotes')));
    expect(opened, 1);
  });
}
