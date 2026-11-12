import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/documents/data/remote_addendum_repository.dart';
import 'package:sign2digital/features/documents/domain/addendum_draft.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';

void main() {
  setUp(() {
    ActiveCompanySession.set(5);
    AddendumDraftSession.clear();
  });
  tearDown(() {
    ActiveCompanySession.clear();
    AddendumDraftSession.clear();
  });

  Map<String, dynamic> saved({int revision = 1, String status = 'draft',
      int company = 5}) => {
    'id': 8, 'company_id': company, 'source_document_id': 'signed-4',
    'source_pdf_sha256': List.filled(64, 'a').join(),
    'source_revision': 2, 'quote_id': 11,
    'number': 'A-8', 'title': 'Roof extension',
    'change_description': 'Add tiles', 'effective_date': '2026-11-04',
    'additional_work': 'Extra waterproof tiles',
    'quantity': 2, 'unit_price_minor': 12000, 'vat_basis_points': 810,
    'subtotal_minor': 24000, 'vat_minor': 1944, 'total_minor': 25944,
    'currency': 'CHF', 'status': status, 'revision': revision,
  };

  AddendumDraft newDraft() => AddendumDraft(
    id: 'local-1', number: 'A-8', title: 'Roof extension',
    description: 'Add tiles', linkedDocumentId: 'signed-4',
    effectiveDate: DateTime(2026, 11, 4),
    additionalWork: 'Extra waterproof tiles',
    quantity: '2', unitPrice: '120.00', vatBasisPoints: 810,
  );

  test('company scoped create and approval do not fake a local signed PDF',
      () async {
    final calls = <String>[];
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'secure-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        expect(request.headers['X-Company-Id'], '5');
        expect(request.headers['Authorization'], 'Bearer secure-token');
        if (request.url.path == '/api/v1/addenda') {
          expect(jsonDecode(request.body)['source_signed_artifact_id'], 4);
          expect(jsonDecode(request.body)['unit_price_minor'], 12000);
          expect(jsonDecode(request.body)['vat_basis_points'], 810);
          return http.Response(jsonEncode({'data': {
            'addendum': saved(),
          }}), 201);
        }
        if (request.url.path == '/api/v1/addenda/8/approve') {
          expect(jsonDecode(request.body)['expected_revision'], 1);
          expect(jsonDecode(request.body)['confirmed'], isTrue);
          return http.Response(jsonEncode({'data': {
            'addendum': saved(status: 'approved'),
          }}), 200);
        }
        throw StateError('Unexpected addendum route');
      }),
    );
    final repo = RemoteAddendumRepository(api: api);
    final draft = await repo.save(newDraft());
    expect(draft.serverId, 8);
    expect(draft.serverRevision, 1);
    expect(draft.totalMinor, 25944);
    expect(draft.linkedDocumentId, 'signed-4');
    final approved = await repo.approve(draft);
    expect(approved.serverStatus, 'approved');
    expect(AddendumDraftSession.isLocked(approved.id), isTrue);
    expect(calls, [
      'POST /api/v1/addenda', 'POST /api/v1/addenda/8/approve',
    ]);
  });

  test('server records cannot cross company or mismatch trusted totals',
      () async {
    for (final result in [
      saved(company: 9),
      {...saved(), 'total_minor': 1},
    ]) {
      final api = SignApiClient(
        baseUrl: Uri.parse('https://example.test'),
        tokenProvider: () async => 'secure-token',
        activeCompanyId: () => ActiveCompanySession.companyId,
        httpClient: MockClient((_) async => http.Response(
          jsonEncode({'data': {'addendum': result}}), 200)),
      );
      await expectLater(RemoteAddendumRepository(api: api).get(8),
          throwsA(isA<SignApiException>()));
    }
  });

  test('do not create addenda against an unsigned quote', () async {
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'secure-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((_) async => throw StateError('No API call permitted')),
    );
    await expectLater(RemoteAddendumRepository(api: api).save(
      newDraft().copyWith(linkedDocumentId: 'quote-11'),
    ), throwsA(isA<SignApiException>()));
  });

  test('revision guarded update uses persisted server ID, never local ID',
      () async {
    final calls = <String>[];
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'secure-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        if (request.method == 'PATCH') {
          expect(jsonDecode(request.body)['expected_revision'], 2);
          expect(jsonDecode(request.body).containsKey('source_signed_artifact_id'),
              isFalse);
        }
        return http.Response(jsonEncode({'data': {
          'addendum': saved(revision: 3),
        }}), 200);
      }),
    );
    final draft = AddendumDraft(
      id: 'addendum-8', serverId: 8, serverRevision: 2,
      number: 'A-8', title: 'Roof extension',
      description: 'Add tiles', linkedDocumentId: 'signed-4',
      effectiveDate: DateTime(2026, 11, 4),
      additionalWork: 'Extra waterproof tiles',
      quantity: '2', unitPrice: '120.00', vatBasisPoints: 810,
    );
    final updated = await RemoteAddendumRepository(api: api).save(draft);
    expect(updated.serverRevision, 3);
    expect(calls.single, '/api/v1/addenda/8');
  });

  test('email signing receipt has no URL and is accepted only when SMTP confirms', () async {
    final posts = <Map<String, dynamic>>[];
    final expires = DateTime.now().add(const Duration(days: 3)).toUtc();
    final sent = DateTime.now().toUtc();
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'secure-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/quotes/11') {
          return http.Response(jsonEncode({'data': {'quote': {
            'id': 11, 'company_id': 5, 'items': [],
            'client_name': 'Original Customer',
            'client_email': 'customer@example.test',
            'quote_date': '2026-11-04', 'reference_number': 'Q-11',
            'status': 'sent',
          }}}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/addenda/8/signature-requests') {
          posts.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'data': {
            'request': {
              'id': 99, 'request_id': 'request-99', 'addendum_id': 8,
              'status': 'sent', 'expires_at': expires.toIso8601String(),
              'sent_at': sent.toIso8601String(),
            },
            'secure_link': null, 'transport_accepted': true,
            'delivered': false,
          }}), 201);
        }
        throw StateError('Unexpected request: ${request.url.path}');
      }),
    );
    final source = DocumentRecord(
      id: 'signed-4', category: DocumentCategory.quotes,
      number: 'Q-11', title: 'Signed quote',
      project: 'Roof', customer: 'Customer',
      timestamp: DateTime(2026, 11, 4), status: 'signed',
      verifiedSignedPdfAvailable: true,
    );
    final draft = newDraft().copyWith(
      serverId: 8, serverRevision: 1, quoteServerId: 11,
      serverStatus: 'approved',
    );
    final repo = RemoteAddendumRepository(api: api);
    final receipt = await repo.requestSignature(draft, source);
    expect(posts.single['delivery'], 'email');
    expect(posts.single.containsKey('replace_ready_link'), isFalse);
    expect(receipt?.valid, isTrue);
    expect(receipt?.emailTransportAccepted, isTrue);
    expect(receipt?.secureUrl, isNull);
    expect(receipt?.confirmedSentAt, isNotNull);

    final replaced = await repo.requestSignature(draft, source,
        replaceReadyLink: true);
    expect(posts.last['replace_ready_link'], isTrue);
    expect(replaced?.valid, isTrue);
  });

  test('email request never treats an unsigned ready-link response as sent', () async {
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'secure-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/quotes/11') {
          return http.Response(jsonEncode({'data': {'quote': {
            'id': 11, 'company_id': 5, 'items': [],
            'client_name': 'Original Customer',
            'client_email': 'customer@example.test',
            'quote_date': '2026-11-04',
          }}}), 200);
        }
        return http.Response(jsonEncode({'data': {
          'request': {
            'id': 99, 'request_id': 'request-99', 'addendum_id': 8,
            'status': 'ready',
            'expires_at': DateTime.now().add(const Duration(days: 3))
                .toUtc().toIso8601String(),
            'sent_at': null,
          },
          'secure_link': 'https://example.test/addendum-sign/token',
          'transport_accepted': false,
        }}), 201);
      }),
    );
    final source = DocumentRecord(
      id: 'signed-4', category: DocumentCategory.quotes,
      number: 'Q-11', title: 'Signed quote',
      project: 'Roof', customer: 'Customer',
      timestamp: DateTime(2026, 11, 4), status: 'signed',
      verifiedSignedPdfAvailable: true,
    );
    await expectLater(
      RemoteAddendumRepository(api: api).requestSignature(
        newDraft().copyWith(serverId: 8, serverRevision: 1,
          quoteServerId: 11, serverStatus: 'approved'), source),
      throwsA(isA<SignApiException>()),
    );
  });

  test('request signature needs verified signed original and approved state',
      () async {
    final api = SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      tokenProvider: () async => 'secure-token',
      activeCompanyId: () => ActiveCompanySession.companyId,
      httpClient: MockClient((_) async => throw StateError('No API call permitted')),
    );
    final draft = newDraft().copyWith(
      serverId: 8, serverRevision: 1, quoteServerId: 11,
      serverStatus: 'draft',
    );
    final source = DocumentRecord(
      id: 'signed-4', category: DocumentCategory.quotes,
      number: 'Q-11', title: 'Signed quote',
      project: 'Roof', customer: 'Customer',
      timestamp: DateTime(2026, 11, 4), status: 'signed',
      verifiedSignedPdfAvailable: true,
    );
    await expectLater(
      RemoteAddendumRepository(api: api).requestSignature(draft, source),
      throwsA(isA<SignApiException>()),
    );
  });
}
