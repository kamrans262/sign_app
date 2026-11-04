import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/job_photo_model.dart';
import '../domain/job_note_model.dart';
import '../domain/note_document_draft.dart';
import 'local_job_photo_source.dart';

/// M11 persistent media. The original local/demo flows remain injected for UI tests.
class RemoteJobMediaRepository {
  RemoteJobMediaRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;
  static final shared = RemoteJobMediaRepository();
  final SignApiClient _api;

  static bool isLiveJob(String id) =>
      (int.tryParse(id) ?? 0) > 0 && ActiveCompanySession.companyId != null;

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id <= 0) {
      throw const SignApiException('Select a company before managing job media.');
    }
    return id;
  }

  void _check(int id) {
    if (ActiveCompanySession.companyId != id) {
      throw const SignApiException('Company changed during the request.');
    }
  }

  static Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SignApiException('Invalid job media response.');
    }
    return data;
  }

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) throw const SignApiException('Invalid record.');
    return Map<String, dynamic>.from(raw);
  }

  static JobPhotoCategory _category(Object? raw) => switch (raw) {
        'before' => JobPhotoCategory.before,
        'during' => JobPhotoCategory.during,
        'after' => JobPhotoCategory.after,
        _ => throw const SignApiException('Invalid photo category.'),
      };

  Future<List<JobPhotoModel>> listPhotos(String jobId) async {
    final company = _company();
    final data = _payload(await _api.get('/api/v1/jobs/$jobId/photos',
      companyScoped: true));
    _check(company);
    final rows = data['photos'];
    if (rows is! List) throw const SignApiException('Invalid photos response.');
    final photos = <JobPhotoModel>[];
    for (final value in rows) {
      final row = _map(value);
      final id = int.tryParse(row['id'].toString());
      final date = DateTime.tryParse((row['created_at'] ?? '').toString());
      final mime = (row['mime_type'] ?? '').toString();
      final digest = (row['sha256'] ?? '').toString().toLowerCase();
      if (id == null || id <= 0 ||
          row['company_id'].toString() != company.toString() ||
          row['job_id'].toString() != jobId || date == null ||
          !['image/jpeg', 'image/png'].contains(mime) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        throw const SignApiException('Invalid photo metadata.');
      }
      final bytes = await _api.getPrivateMedia(
        '/api/v1/jobs/$jobId/photos/$id/file',
        mimeType: mime, maxBytes: 20 * 1024 * 1024);
      _check(company);
      if (sha256.convert(bytes).toString() != digest) {
        throw const SignApiException('Photo integrity check failed.');
      }
      photos.add(JobPhotoModel(
        id: id.toString(), jobId: jobId,
        title: (row['title'] ?? 'Front View').toString(),
        caption: (row['caption'] ?? '').toString(),
        createdAt: date, category: _category(row['category']), bytes: bytes));
    }
    return List.unmodifiable(photos);
  }

  Future<JobPhotoModel> uploadPhoto(String jobId,
      LocalJobPhotoSelection file, JobPhotoCategory category,
      String caption) async {
    final company = _company();
    DeviceJobPhotoSource.validate(file.name, file.bytes);
    final data = _payload(await _api.postMultipart(
      '/api/v1/jobs/$jobId/photos', filename: file.name,
      bytes: file.bytes, companyScoped: true, maxBytes: 20 * 1024 * 1024,
      fields: {'category': category.name, 'caption': caption.trim()}));
    _check(company);
    final row = _map(data['photo']);
    if (row['company_id'].toString() != company.toString() ||
        row['job_id'].toString() != jobId ||
        row['sha256'].toString().toLowerCase() !=
            sha256.convert(file.bytes).toString()) {
      throw const SignApiException('Photo upload could not be verified.');
    }
    return JobPhotoModel(
      id: row['id'].toString(), jobId: jobId,
      title: caption.trim().isEmpty ? 'Front View' : caption.trim(),
      caption: caption.trim(), category: category,
      createdAt: DateTime.now(), bytes: file.bytes, sourceKey: file.sourceKey);
  }

  JobNoteModel _note(Object? raw, int company, String jobId) {
    final row = _map(raw);
    final date = DateTime.tryParse((row['created_at'] ?? '').toString());
    if (row['company_id'].toString() != company.toString() ||
        row['job_id'].toString() != jobId || date == null) {
      throw const SignApiException('Invalid job note identity.');
    }
    final type = switch (row['type']) {
      'text' => JobNoteType.text,
      'voice' => JobNoteType.voice,
      'textWithAudio' => JobNoteType.textWithAudio,
      _ => throw const SignApiException('Invalid note type.'),
    };
    final visibility = switch (row['visibility']) {
      'private' => JobNoteVisibility.privateNote,
      'customer_facing' => JobNoteVisibility.customerFacing,
      _ => throw const SignApiException('Invalid note visibility.'),
    };
    return JobNoteModel(
      id: row['id'].toString(), jobId: jobId,
      title: (row['title'] ?? '').toString(),
      body: (row['body'] ?? '').toString(), createdAt: date,
      type: type, visibility: visibility,
      audioPath: row['has_audio'] == true ? 'remote:' + row['id'].toString() : null);
  }

  Future<List<JobNoteModel>> listNotes(String jobId) async {
    final company = _company();
    final response = _payload(await _api.get('/api/v1/jobs/$jobId/notes',
      companyScoped: true));
    _check(company);
    if (response['notes'] is! List) {
      throw const SignApiException('Invalid notes response.');
    }
    return List.unmodifiable((response['notes'] as List)
        .map((raw) => _note(raw, company, jobId)));
  }

  Future<void> createNote({
    required String jobId, required String title, required String body,
    required JobNoteType type, required JobNoteVisibility visibility,
    String? audioPath,
  }) async {
    final company = _company();
    final fields = <String, String>{
      'title': title.trim(), 'body': body.trim(),
      'type': type.name,
      'visibility': visibility == JobNoteVisibility.privateNote
          ? 'private' : 'customer_facing',
    };
    if (audioPath == null) {
      await _api.post('/api/v1/jobs/$jobId/notes',
        companyScoped: true, data: fields);
    } else {
      final file = File(audioPath);
      if (!await file.exists() || await file.length() == 0) {
        throw const SignApiException('Recorded audio is missing.');
      }
      final bytes = await file.readAsBytes();
      await _api.postMultipart('/api/v1/jobs/$jobId/notes',
        filename: file.uri.pathSegments.last, bytes: bytes,
        companyScoped: true, maxBytes: 25 * 1024 * 1024, fields: fields);
    }
    _check(company);
  }

  Future<Uint8List> audioBytes(String jobId, String noteId) async {
    final company = _company();
    final raw = _payload(await _api.get(
      '/api/v1/jobs/$jobId/notes/$noteId', companyScoped: true));
    _check(company);
    final note = _map(raw['note']);
    if (note['job_id'].toString() != jobId ||
        note['company_id'].toString() != company.toString() ||
        note['id'].toString() != noteId || note['has_audio'] != true) {
      throw const SignApiException('Recording not found.');
    }
    final mime = (note['audio_mime_type'] ?? '').toString();
    final digest = (note['audio_sha256'] ?? '').toString().toLowerCase();
    if (!['audio/mp4', 'audio/aac', 'audio/wav'].contains(mime) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw const SignApiException('Invalid recorded audio metadata.');
    }
    final bytes = await _api.getPrivateMedia(
      '/api/v1/jobs/$jobId/notes/$noteId/audio',
      mimeType: mime, maxBytes: 25 * 1024 * 1024);
    _check(company);
    if (sha256.convert(bytes).toString() != digest) {
      throw const SignApiException('Recording integrity check failed.');
    }
    return bytes;
  }

  /// On-demand voice transcription. Server enforces tenant and privacy.
  Future<String> transcribeNote(JobNoteModel note) async {
    final company = _company();
    if (note.visibility != JobNoteVisibility.privateNote ||
        !isLiveJob(note.jobId) || int.tryParse(note.id) == null ||
        note.audioPath == null) {
      throw const SignApiException('A saved private voice note is required.');
    }
    final data = _payload(await _api.post(
      '/api/v1/jobs/' + note.jobId + '/notes/' + note.id + '/transcribe',
      companyScoped: true,
    ));
    _check(company);
    if (data['note_id'].toString() != note.id ||
        data['job_id'].toString() != note.jobId) {
      throw const SignApiException('Transcription note identity mismatch.');
    }
    final value = data['transcript'];
    if (value is! String || value.trim().isEmpty ||
        value.length > 20000) {
      throw const SignApiException('Invalid voice transcription.');
    }
    return value.trim();
  }

  Future<NoteDocumentDraft> prepareNote(JobNoteModel note, String type) async {
    final company = _company();
    if (note.visibility != JobNoteVisibility.privateNote) {
      throw const SignApiException('Only selected private notes can be converted.');
    }
    final data = _payload(await _api.post(
      '/api/v1/jobs/${note.jobId}/notes/${note.id}/documents/prepare',
      companyScoped: true, data: {'document_type': type}));
    _check(company);
    final row = _map(data['document']);
    if (row['note_id'].toString() != note.id ||
        row['job_id'].toString() != note.jobId || row['document_type'] != type) {
      throw const SignApiException('Invalid prepared document source.');
    }
    return NoteDocumentDraft(
      noteId: note.id, jobId: note.jobId,
      documentType: type, title: row['title'].toString(),
      content: row['content'].toString(),
      serverId: int.tryParse(row['id'].toString()));
  }

  Future<NoteDocumentDraft> saveDocument(
      NoteDocumentDraft draft, {required bool approve}) async {
    final company = _company();
    if (draft.serverId == null) {
      throw const SignApiException('Document must be prepared by the server.');
    }
    final path = '/api/v1/jobs/${draft.jobId}/notes/${draft.noteId}'
        '/documents/${draft.serverId}';
    await _api.request('PATCH', path, companyScoped: true,
      data: {'title': draft.title, 'content': draft.content});
    _check(company);
    if (!approve) return draft.copyWith(approvedLocally: false);
    final data = _payload(await _api.post('$path/approve',
      companyScoped: true, data: {'confirm': true}));
    _check(company);
    final row = _map(data['document']);
    if (row['status'] != 'approved' ||
        int.tryParse(row['managed_document_id'].toString()) == null) {
      throw const SignApiException('Document was not approved.');
    }
    return draft.copyWith(approvedLocally: true);
  }
}
