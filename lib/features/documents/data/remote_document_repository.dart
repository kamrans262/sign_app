import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/document_record.dart';

/// M9 company-scoped document service. Server owns the source of truth:
/// approval PDFs, signed artifacts, versions and signed/recipient events.
class RemoteDocumentRepository implements DocumentRepository {
  RemoteDocumentRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteDocumentRepository();
  final SignApiClient _api;

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id <= 0) {
      throw const SignApiException('Select a company first.');
    }
    return id;
  }

  void _assertCompany(int original) {
    if (ActiveCompanySession.companyId != original) {
      throw const SignApiException('Company changed while loading documents.');
    }
  }

  static Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final raw = response['data'];
    if (raw is! Map) {
      throw const SignApiException('Invalid document service response.');
    }
    return Map<String, dynamic>.from(raw);
  }

  static int _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static DocumentCategory _category(Object? value) {
    final code = (value ?? '').toString();
    for (final category in DocumentCategory.values) {
      if (category.name == code) return category;
    }
    return DocumentCategory.other;
  }

  static DocumentHistoryType? _historyType(Object? value) {
    return switch (value?.toString()) {
      'created' => DocumentHistoryType.created,
      'edited' => DocumentHistoryType.edited,
      'version_changed' => DocumentHistoryType.versionChanged,
      'attachment_added' => DocumentHistoryType.attachmentAdded,
      'approved' => DocumentHistoryType.approved,
      'archived' => DocumentHistoryType.archived,
      'sent' => DocumentHistoryType.sent,
      'viewed' => DocumentHistoryType.viewed,
      'signed' => DocumentHistoryType.signed,
      'downloaded' => DocumentHistoryType.downloaded,
      _ => null,
    };
  }

  static List<DocumentHistoryEvent> _events(
      Object? raw, String documentId) {
    if (raw is! List) return const [];
    final result = <DocumentHistoryEvent>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      final type = _historyType(map['type']);
      final time = DateTime.tryParse((map['occurred_at'] ?? '').toString());
      if (type == null || time == null) continue;
      result.add(DocumentHistoryEvent(
        id: (map['id'] ?? '').toString(),
        documentId: documentId,
        type: type,
        occurredAt: time,
        actorName: map['actor_name']?.toString(),
      ));
    }
    return List.unmodifiable(result);
  }

  static DocumentRecord _record(Map<String, dynamic> raw, {
    Object? history,
    Object? attachments,
    List<DocumentRecord> related = const [],
  }) {
    final id = (raw['id'] ?? '').toString();
    if (!RegExp(r'^(quote|signed|managed)-[1-9][0-9]*$').hasMatch(id)) {
      throw const SignApiException('Invalid document identity.');
    }
    final created = DateTime.tryParse((raw['created_at'] ?? '').toString());
    if (created == null) {
      throw const SignApiException('Document has no verified creation date.');
    }
    final digest = (raw['sha256'] ?? '').toString();
    final hasPdf = raw['has_pdf'] == true;
    if (hasPdf && !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw const SignApiException('Invalid verified PDF digest.');
    }
    return DocumentRecord(
      id: id,
      category: _category(raw['category']),
      number: (raw['number'] ?? '').toString(),
      title: (raw['title'] ?? '').toString(),
      project: (raw['project'] ?? '').toString().trim().isEmpty
          ? 'Not linked to a job' : (raw['project'] ?? '').toString(),
      customer: (raw['customer'] ?? '').toString(),
      timestamp: created,
      status: (raw['status'] ?? '').toString(),
      version: _int(raw['version']),
      jobId: raw['job_id']?.toString(),
      verifiedSignedPdfAvailable: hasPdf,
      createdAt: created,
      updatedAt: DateTime.tryParse((raw['updated_at'] ?? '').toString()),
      history: _events(history, id),
      related: List.unmodifiable(related),
      attachmentNames: attachments is List
          ? List.unmodifiable(attachments.whereType<Map>()
              .map((value) => (value['original_name'] ?? '').toString())
              .where((name) => name.isNotEmpty))
          : const [],
    );
  }

  @override
  Future<List<DocumentRecord>> listDocuments({String? jobId}) async {
    final company = _company();
    final records = <DocumentRecord>[];
    var page = 1;
    var lastPage = 1;
    // Defensive upper bound: never loop indefinitely on a bad API response.
    do {
      final response = await _api.request(
        'GET', '/api/v1/documents',
        companyScoped: true,
        queryParameters: {
          'page': '$page',
          'per_page': '100',
          if (jobId != null && jobId.isNotEmpty) 'job_id': jobId,
        },
      );
      _assertCompany(company);
      final data = _payload(response);
      final rawDocuments = data['documents'];
      if (rawDocuments is! List) {
        throw const SignApiException('Invalid document list.');
      }
      for (final raw in rawDocuments) {
        if (raw is! Map) continue;
        final doc = _record(Map<String, dynamic>.from(raw));
        if (jobId != null && doc.jobId != jobId) {
          throw const SignApiException('Document belongs to another job.');
        }
        records.add(doc);
      }
      lastPage = _int(data['last_page']);
      if (lastPage < 1 || lastPage > 100) {
        throw const SignApiException('Document pagination is invalid.');
      }
      page++;
    } while (page <= lastPage);
    return List.unmodifiable(records);
  }

  Future<DocumentRecord> details(String id) async {
    final company = _company();
    final result = await _api.request(
      'GET', '/api/v1/documents/$id', companyScoped: true,
    );
    _assertCompany(company);
    final payload = _payload(result);
    final raw = payload['document'];
    if (raw is! Map) {
      throw const SignApiException('Document details are unavailable.');
    }
    final relatedData = payload['related'];
    final linked = <DocumentRecord>[];
    if (relatedData is List) {
      for (final entry in relatedData) {
        if (entry is Map) {
          linked.add(_record(Map<String, dynamic>.from(entry)));
        }
      }
    }
    final document = _record(Map<String, dynamic>.from(raw),
        history: payload['history'], attachments: payload['attachments'],
        related: linked);
    if (document.id != id) {
      throw const SignApiException('Document identity changed.');
    }
    return document;
  }

  Future<Uint8List> downloadPdf(DocumentRecord document) async {
    final company = _company();
    if (!document.verifiedSignedPdfAvailable) {
      throw const SignApiException('No verified PDF is available.');
    }
    // SHA supplied by authoritative document details, not a local demo file.
    final detailResponse = await _api.request(
      'GET', '/api/v1/documents/' + document.id,
      companyScoped: true,
    );
    _assertCompany(company);
    final raw = _payload(detailResponse)['document'];
    if (raw is! Map || raw['id'] != document.id || raw['has_pdf'] != true) {
      throw const SignApiException('Document changed before download.');
    }
    final digest = (raw['sha256'] ?? '').toString();
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw const SignApiException('Document digest is invalid.');
    }
    final bytes = await _api.getPdf(
      '/api/v1/documents/' + document.id + '/pdf',
      companyScoped: true,
      maxBytes: 12 * 1024 * 1024,
    );
    _assertCompany(company);
    if (sha256.convert(bytes).toString().toLowerCase() !=
        digest.toLowerCase()) {
      throw const SignApiException('Document PDF integrity check failed.');
    }
    return bytes;
  }

  Future<DocumentRecord> uploadPdf({
    required String name,
    required Uint8List bytes,
    required String title,
    required DocumentCategory category,
    String? jobId,
  }) async {
    if (category == DocumentCategory.quotes) {
      throw const SignApiException('Create quotes using the quote workflow.');
    }
    final company = _company();
    final response = await _api.postMultipart(
      '/api/v1/documents',
      filename: name,
      bytes: bytes,
      companyScoped: true,
      maxBytes: 10 * 1024 * 1024,
      fields: {
        'title': title,
        'category': category.name,
        if (jobId != null && jobId.isNotEmpty) 'job_id': jobId,
      },
    );
    _assertCompany(company);
    final doc = _payload(response)['document'];
    if (doc is! Map) throw const SignApiException('Document upload failed.');
    return _record(Map<String, dynamic>.from(doc));
  }

  Future<DocumentRecord> addVersion(
      DocumentRecord document, String name, Uint8List bytes) async {
    if (!document.id.startsWith('managed-')) {
      throw const SignApiException('Signed and approved originals cannot be replaced.');
    }
    final company = _company();
    final response = await _api.postMultipart(
      '/api/v1/documents/' + document.id + '/versions',
      filename: name,
      bytes: bytes,
      companyScoped: true,
      maxBytes: 10 * 1024 * 1024,
    );
    _assertCompany(company);
    final result = _payload(response)['document'];
    if (result is! Map || result['id'] != document.id) {
      throw const SignApiException('Document version update failed.');
    }
    return _record(Map<String, dynamic>.from(result));
  }

  Future<void> addAttachment(
      DocumentRecord document, String name, Uint8List bytes) async {
    final company = _company();
    await _api.postMultipart(
      '/api/v1/documents/' + document.id + '/attachments',
      filename: name,
      bytes: bytes,
      companyScoped: true,
      maxBytes: 10 * 1024 * 1024,
    );
    _assertCompany(company);
  }
}
