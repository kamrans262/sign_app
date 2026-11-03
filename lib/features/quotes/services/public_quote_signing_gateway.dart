import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/quote_document_tracking.dart';
import '../domain/quote_review_models.dart';
import '../domain/quote_signature_draft.dart';
import '../domain/quote_signed_display_data.dart';
import '../domain/quote_signing_context.dart';

/// The public signing endpoint must validate the opaque, expiring token
/// server-side. Loading a quote is not authentication or proof of signing.
class PublicQuoteSigningSession {
  const PublicQuoteSigningSession({
    required this.quote,
    required this.tracking,
    required this.signer,
  });
  final QuoteReviewDraft quote;
  final QuoteDocumentTracking tracking;
  final QuoteSigningContext signer;
}

abstract class PublicQuoteSigningGateway {
  Future<PublicQuoteSigningSession> open(String token);
  Future<QuoteSignedDisplayData?> submit(
    String token,
    QuoteSignatureDraft signature,
  );
}

/// Configurable Laravel API contract. There is no production backend in this
/// Flutter repository. Never put API secrets inside the app or the URL.
///
/// Expected endpoints:
/// GET  /api/public/signing/{opaqueToken}
/// POST /api/public/signing/{opaqueToken}/submit
/// The server must bind token, signer, document version, consent reference,
/// expiry and signed PDF to the exact immutable document under its job.
class HttpPublicQuoteSigningGateway implements PublicQuoteSigningGateway {
  HttpPublicQuoteSigningGateway({required Uri apiBase, http.Client? client})
      : _base = apiBase,
        _client = client ?? http.Client() {
    if (_base.scheme != 'https' || _base.host.isEmpty) {
      throw ArgumentError('A trusted HTTPS signing API is required.');
    }
  }

  final Uri _base;
  final http.Client _client;

  Uri _endpoint(String token, [String? action]) {
    if (token.isEmpty || token.length > 4096) {
      throw const FormatException('Invalid signing token.');
    }
    final root = _base.replace(
      path: '${_base.path.replaceAll(RegExp(r"/+$"), "")}/api/public/signing',
      query: null,
      fragment: null,
    );
    return root.replace(pathSegments: [
      ...root.pathSegments.where((part) => part.isNotEmpty),
      token,
      ?action,
    ]);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) throw const FormatException('Invalid API response.');
    return Map<String, dynamic>.from(value);
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing signing field: $key');
    }
    return value;
  }

  static DateTime _date(Map<String, dynamic> data, String key) =>
      DateTime.parse(_string(data, key));

  @override
  Future<PublicQuoteSigningSession> open(String token) async {
    final response = await _client.get(
      _endpoint(token),
      headers: const {'Accept': 'application/json', 'Cache-Control': 'no-store'},
    );
    if (response.statusCode != 200) {
      throw StateError('This document cannot be accessed or the link has expired.');
    }
    final json = _map(jsonDecode(response.body));
    final source = _map(json['quote']);
    final request = _map(json['request']);
    final signer = _map(json['signer']);
    final items = source['items'];
    if (items is! List || items.isEmpty) {
      throw const FormatException('The document contains no work items.');
    }
    final quote = QuoteReviewDraft(
      id: _string(source, 'id'),
      clientId: source['clientId'] as String?,
      jobId: source['jobId'] as String?,
      companyId: source['companyId'] as String?,
      clientName: _string(source, 'clientName'),
      clientEmail: source['clientEmail'] as String? ?? '',
      clientPhone: source['clientPhone'] as String? ?? '',
      billingAddress: source['billingAddress'] as String? ?? '',
      quoteNumber: _string(source, 'quoteNumber'),
      date: _date(source, 'date'),
      terms: _string(source, 'terms'),
      currency: source['currency'] as String? ?? 'CHF',
      vatBasisPoints: (source['vatBasisPoints'] as num?)?.toInt() ?? 0,
      depositBasisPoints: (source['depositBasisPoints'] as num?)?.toInt() ?? 0,
      items: [
        for (final raw in items)
          QuoteReviewWorkItem(
            id: _string(_map(raw), 'id'),
            title: _string(_map(raw), 'title'),
            description: _map(raw)['description'] as String? ?? '',
            quantity: _string(_map(raw), 'quantity'),
            unitPrice: _string(_map(raw), 'unitPrice'),
            dimensions: _map(raw)['dimensions'] as String?,
          ),
      ],
      approvedLocally: true,
    );
    final requestId = _string(request, 'requestId');
    final linkString = _string(request, 'secureUrl');
    final link = Uri.parse(linkString);
    final expiration = _date(request, 'expiresAt');
    if (link.scheme != 'https' || link.host.isEmpty ||
        !DateTime.now().isBefore(expiration)) {
      throw StateError('This signing request has expired.');
    }
    final events = <QuoteDocumentEvent>[];
    if (request['events'] is List) {
      for (final raw in request['events'] as List) {
        final event = _map(raw);
        final typeName = _string(event, 'type');
        final matches = QuoteDocumentEventType.values.where(
          (item) => item.name == typeName,
        );
        if (matches.isEmpty) continue;
        events.add(QuoteDocumentEvent(
          id: _string(event, 'id'),
          type: matches.first,
          occurredAt: _date(event, 'occurredAt'),
        ));
      }
    }
    final tracking = QuoteDocumentTracking(
      quoteId: quote.id, requestId: requestId,
      secureUrl: link, expiresAt: expiration,
      events: events,
    );
    if (!tracking.requestIsActive) {
      throw StateError('There is no active signature request.');
    }
    return PublicQuoteSigningSession(
      quote: quote,
      tracking: tracking,
      signer: QuoteSigningContext(
        documentId: _string(signer, 'documentId'),
        signerId: _string(signer, 'signerId'),
        documentVersion: _string(signer, 'documentVersion'),
        consentReference: _string(signer, 'consentReference'),
      ),
    );
  }

  @override
  Future<QuoteSignedDisplayData?> submit(
    String token,
    QuoteSignatureDraft signature,
  ) async {
    if (!signature.consentAccepted || signature.pngBytes.isEmpty ||
        signature.quoteId.isEmpty || signature.requestId.isEmpty ||
        signature.signerId.isEmpty || signature.documentVersion.isEmpty) {
      throw const FormatException('Incomplete signature submission.');
    }
    final response = await _client.post(
      _endpoint(token, 'submit'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
      body: jsonEncode({
        'quoteId': signature.quoteId,
        'documentId': signature.documentId,
        'requestId': signature.requestId,
        'signerId': signature.signerId,
        'documentVersion': signature.documentVersion,
        'consentReference': signature.consentReference,
        'method': signature.method.name,
        'typedName': signature.typedName,
        'signaturePngBase64': base64Encode(signature.pngBytes),
        'capturedAt': signature.capturedAt.toUtc().toIso8601String(),
        'consentAccepted': signature.consentAccepted,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError('The signing service did not confirm the signature.');
    }
    final json = _map(jsonDecode(response.body));
    final pdf = json['signedPdfBase64'];
    if (pdf is! String || pdf.isEmpty) {
      throw const FormatException('The server did not return the signed PDF.');
    }
    final bytes = Uint8List.fromList(base64Decode(pdf));
    if (bytes.length < 5 ||
        bytes[0] != 0x25 || bytes[1] != 0x50 ||
        bytes[2] != 0x44 || bytes[3] != 0x46 || bytes[4] != 0x2d) {
      throw const FormatException('Invalid signed PDF from signing service.');
    }
    final receipt = QuoteSignedDisplayData(
      documentId: _string(json, 'documentId'),
      quoteId: _string(json, 'quoteId'),
      jobId: _string(json, 'jobId'),
      quoteNumber: _string(json, 'quoteNumber'),
      projectName: _string(json, 'projectName'),
      signerName: _string(json, 'signerName'),
      signedAt: _date(json, 'signedAt'),
      ipAddress: json['ipAddress'] as String?,
      signedPdfBytes: bytes,
    );
    if (receipt.documentId != signature.documentId ||
        receipt.quoteId != signature.quoteId) {
      throw const FormatException('Signing receipt does not match the document.');
    }
    return receipt;
  }
}
