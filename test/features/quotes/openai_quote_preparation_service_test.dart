import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/features/quotes/domain/quote_draft_input.dart';
import 'package:sign2digital/features/quotes/domain/quote_extraction_models.dart';
import 'package:sign2digital/features/quotes/domain/quote_review_models.dart';
import 'package:sign2digital/features/quotes/services/openai_quote_preparation_service.dart';

QuoteDraftInput source(QuoteInputMethod method, {String? text, String? audio, String? photo}) =>
    QuoteDraftInput(method: method, createdAt: DateTime(2026, 10, 13),
        description: text, audioPath: audio, photoPath: photo);

http.Response aiResponse(Map<String, dynamic> data) => http.Response(jsonEncode({
  'choices': [
    {'message': {'content': jsonEncode(data)}}
  ],
}), 200);

final exampleExtraction = <String, dynamic>{
  'items': [
    {'title': 'Window installation', 'description': 'White PVC frames',
      'quantity': 3, 'dimensions': '1.2 m x 1.5 m', 'unitPrice': '999999'},
    {'title': 'Old window removal', 'description': 'Remove frames',
      'quantity': null, 'dimensions': null},
  ],
  'location': '12 Oak Road', 'currency': 'GBP', 'notes': null,
};

void main() {
  test('typed instructions use real API request and return two unpriced items', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/chat/completions');
      expect(request.headers['authorization'] ?? request.headers['Authorization'], 'Bearer development-test-key');
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      expect(data['model'], 'gpt-4o-mini');
      expect(jsonEncode(data['messages']), contains('Install 3 windows'));
      return aiResponse(exampleExtraction);
    });
    final service = OpenAiQuotePreparationService(
      temporaryApiKey: 'development-test-key', client: client);
    final snapshots = await service.prepare(source(QuoteInputMethod.text,
      text: 'Install 3 windows and remove old frames at 12 Oak Road.')).toList();
    expect(snapshots.first.stage, QuotePreparationStage.extracting);
    final last = snapshots.last;
    expect(last.stage, QuotePreparationStage.completed);
    expect(last.progressPercentage, isNull);
    expect(last.isDemo, isFalse);
    expect(last.items.length, 2);
    expect(last.items.first.quantity, 3);
    expect(last.items.last.quantity, isNull);
    expect(last.fields.every((f) => f.status != QuoteExtractionStatus.verified), isTrue);
    expect(last.fields.first.label, 'Items');
    expect(last.fields.first.value, '2 work items');
    expect(last.fields.first.status, QuoteExtractionStatus.needsReview);
    expect(last.fields[1].label, 'Quantity');
    expect(last.fields[1].status, QuoteExtractionStatus.unclear);
    expect(last.fields.any((f) => f.label == 'Dimensions'), isTrue);
    expect(last.fields.any((f) => f.id == 'ai-location'), isTrue);
    expect(last.fields.where((f) => f.status == QuoteExtractionStatus.missing)
        .map((f) => f.label), ['Pricing']);
    expect(last.fields.every((f) => !f.label.startsWith('Work item ')), isTrue);
    final draft = QuoteReviewDraft.fromExtraction(last, null);
    expect(draft.items.length, 2);
    expect(draft.items.first.unitPrice, isEmpty);
    expect(draft.items.last.unitPrice, isEmpty);
    expect(draft.currency, 'GBP');
    client.close();
  });

  test('voice audio is transcribed and then extracted as quote, not job', () async {
    final directory = await Directory.systemTemp.createTemp('quote_audio_ai_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}voice.m4a');
    await file.writeAsBytes([1, 2, 3, 4]);
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.contains('/audio/transcriptions')) {
        expect(request.method, 'POST');
        return http.Response(jsonEncode({'text': 'Replace two doors.'}), 200);
      }
      expect(jsonEncode(jsonDecode(request.body)), contains('Replace two doors'));
      return aiResponse({
        'items': [{'title': 'Replace doors', 'description': 'Two doors',
          'quantity': 2, 'dimensions': null}],
        'location': null, 'notes': null, 'currency': null,
      });
    });
    final events = await OpenAiQuotePreparationService(
      temporaryApiKey: 'development-test-key', client: client)
      .prepare(source(QuoteInputMethod.voice, audio: file.path)).toList();
    expect(paths, ['/v1/audio/transcriptions', '/v1/chat/completions']);
    expect(events.last.items.single.title, 'Replace doors');
    client.close();
  });

  test('handwritten photo is sent as actual image content', () async {
    final directory = await Directory.systemTemp.createTemp('quote_photo_ai_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}notes.png');
    await file.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    final client = MockClient((request) async {
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      final user = (data['messages'] as List).last as Map;
      final content = user['content'] as List;
      final image = content.last as Map;
      expect(image['type'], 'image_url');
      expect((image['image_url'] as Map)['url'], startsWith('data:image/png;base64,'));
      return aiResponse(exampleExtraction);
    });
    final events = await OpenAiQuotePreparationService(
      temporaryApiKey: 'development-test-key', client: client)
      .prepare(source(QuoteInputMethod.handwrittenPhoto, photo: file.path))
      .toList();
    expect(events.last.items.length, 2);
    client.close();
  });

  test('an API authentication failure is an error, never a fake quote', () async {
    final client = MockClient((_) async => http.Response('unauthorized', 401));
    final service = OpenAiQuotePreparationService(
      temporaryApiKey: 'expired-test-key', client: client);
    await expectLater(
      service.prepare(source(QuoteInputMethod.text, text: 'Paint the room')),
      emitsInOrder([isA<QuotePreparationSnapshot>(), emitsError(isA<StateError>())]),
    );
    client.close();
  });

  test('rejects absent text rather than manufacturing a quote', () async {
    final client = MockClient((_) async => throw StateError('Should not call API'));
    final service = OpenAiQuotePreparationService(
      temporaryApiKey: 'development-test-key', client: client);
    await expectLater(service.prepare(source(QuoteInputMethod.text, text: '')),
        emitsInOrder([isA<QuotePreparationSnapshot>(), emitsError(isA<StateError>())]));
    client.close();
  });
}
