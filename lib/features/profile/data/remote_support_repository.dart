import 'dart:typed_data';

import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

class SupportFaq {
  const SupportFaq({required this.id, required this.question,
    required this.answer, required this.category});
  final int id;
  final String question, answer, category;
}

class SupportTicket {
  const SupportTicket({required this.id, required this.reference,
    required this.subject, required this.description, required this.status,
    required this.category, required this.createdAt});
  final int id;
  final String reference, subject, description, status, category, createdAt;
}

class SupportReply {
  const SupportReply({required this.id, required this.body,
    required this.createdAt, required this.authorUserId});
  final int id, authorUserId;
  final String body, createdAt;
}

class SupportAttachment {
  const SupportAttachment({required this.id, required this.originalName,
    required this.mimeType, required this.byteSize});
  final int id, byteSize;
  final String originalName, mimeType;
}

class SupportTicketDetail {
  const SupportTicketDetail({required this.ticket, required this.replies,
    this.attachments = const []});
  final SupportTicket ticket;
  final List<SupportReply> replies;
  final List<SupportAttachment> attachments;
}

class RemoteSupportRepository {
  RemoteSupportRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteSupportRepository();
  final SignApiClient _api;

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    throw const SignApiException('Invalid support server response.');
  }

  static int _int(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;

  static String _text(Object? raw) => (raw ?? '').toString();

  static SupportTicket _ticket(Object? raw) {
    final row = _map(raw);
    final id = _int(row['id']);
    if (id < 1) throw const SignApiException('Invalid ticket reference.');
    return SupportTicket(
      id: id, reference: _text(row['reference']),
      subject: _text(row['subject']),
      description: _text(row['description']),
      status: _text(row['status']),
      category: _text(row['category']),
      createdAt: _text(row['created_at']),
    );
  }

  static List<SupportAttachment> _attachments(Map<String, dynamic> data) {
    final rows = data['attachments'];
    if (rows == null) return const [];
    if (rows is! List) throw const SignApiException('Invalid attachment list.');
    return [
      for (final raw in rows)
        SupportAttachment(
          id: _int(_map(raw)['id']),
          originalName: _text(_map(raw)['original_name']),
          mimeType: _text(_map(raw)['mime_type']),
          byteSize: _int(_map(raw)['byte_size']),
        ),
    ];
  }

  Future<Uint8List> downloadAttachment(int ticketId,
      SupportAttachment attachment) async {
    if (ticketId <= 0 || attachment.id <= 0 ||
        attachment.byteSize <= 0 || attachment.byteSize > 5 * 1024 * 1024 ||
        !['image/jpeg','image/png','application/pdf']
            .contains(attachment.mimeType)) {
      throw const SignApiException('Invalid support attachment.');
    }
    return _api.getPrivateAttachment(
      '/api/v1/support/tickets/$ticketId/attachments/${attachment.id}',
      mimeType: attachment.mimeType,
      companyScoped: false,
      maxBytes: 5 * 1024 * 1024,
    );
  }

  Future<List<SupportFaq>> faqs({String locale = 'en'}) async {
    final response = await _api.get('/api/v1/support/faqs',
      queryParameters: {'locale':locale});
    final rows = _map(response['data'])['records'];
    if (rows is! List) throw const SignApiException('Invalid FAQ list.');
    return [
      for (final raw in rows)
        SupportFaq(
          id: _int(_map(raw)['id']),
          question: _text(_map(raw)['question']),
          answer: _text(_map(raw)['answer']),
          category: _text(_map(raw)['category']),
        ),
    ];
  }

  Future<List<SupportTicket>> tickets() async {
    final all = <SupportTicket>[];
    for (var page = 1; page <= 100; page++) {
      final response = await _api.get('/api/v1/support/tickets',
        queryParameters: {'page':'$page', 'per_page':'100'});
      final data = _map(response['data']);
      final rows = data['records'];
      if (rows is! List) throw const SignApiException('Invalid ticket list.');
      all.addAll(rows.map(_ticket));
      final pagination = _map(data['pagination']);
      if (pagination['has_more'] != true) break;
    }
    return List.unmodifiable(all);
  }

  Future<SupportTicketDetail> details(int id) async {
    if (id < 1) throw const SignApiException('Invalid ticket ID.');
    final response = await _api.get('/api/v1/support/tickets/$id');
    final data = _map(response['data']);
    final rows = data['replies'];
    if (rows is! List) throw const SignApiException('Invalid conversation.');
    return SupportTicketDetail(
      ticket: _ticket(data['ticket']),
      attachments: _attachments(data),
      replies: [
        for (final raw in rows)
          SupportReply(
            id: _int(_map(raw)['id']),
            body: _text(_map(raw)['body']),
            createdAt: _text(_map(raw)['created_at']),
            authorUserId: _int(_map(raw)['author_user_id']),
          ),
      ],
    );
  }

  Future<SupportTicket> create({
    required String category,
    required String subject,
    required String description,
  }) async {
    final response = await _api.post('/api/v1/support/tickets',
      data: {
        'category': category,
        'subject': subject.trim(),
        'description': description.trim(),
      });
    return _ticket(_map(response['data'])['ticket']);
  }

  Future<SupportTicketDetail> reply(int ticketId,String body) async {
    final response=await _api.post(
      '/api/v1/support/tickets/$ticketId/replies',
      data: {'body': body.trim()},
    );
    final data=_map(response['data']);
    final rows=data['replies'];
    if (rows is! List) throw const SignApiException('Invalid reply response.');
    return SupportTicketDetail(
      ticket:_ticket(data['ticket']),
      attachments:_attachments(data),
      replies:[
        for(final raw in rows)
          SupportReply(id:_int(_map(raw)['id']),
            body:_text(_map(raw)['body']),
            createdAt:_text(_map(raw)['created_at']),
            authorUserId:_int(_map(raw)['author_user_id'])),
      ],
    );
  }

  Future<void> uploadScreenshot(int ticketId, Uint8List jpegBytes) async {
    if(ticketId<=0) throw const SignApiException('Invalid ticket.');
    final response=await _api.postMultipart(
      '/api/v1/support/tickets/$ticketId/attachments',
      filename:'screenshot.jpg',bytes:jpegBytes,
      maxBytes:5*1024*1024,
    );
    final data=response['data'];
    if(data is! Map<String,dynamic> || data['id'] is! num) {
      throw const SignApiException('Attachment could not be saved.');
    }
  }
}
