import '../../../core/services/active_company_session.dart';
import 'job_note_model.dart';

/// A draft prepared from a specific private note; local approval never sends it.
class NoteDocumentDraft {
  const NoteDocumentDraft({
    required this.noteId,
    required this.jobId,
    required this.documentType,
    required this.title,
    required this.content,
    this.approvedLocally = false,
    this.serverId,
  });

  final String noteId;
  final String jobId;
  final String documentType;
  final String title;
  final String content;
  final bool approvedLocally;
  final int? serverId;

  NoteDocumentDraft copyWith({
    String? title, String? content, bool? approvedLocally,
  }) => NoteDocumentDraft(
    noteId: noteId, jobId: jobId, documentType: documentType,
    title: title ?? this.title,
    content: content ?? this.content,
    approvedLocally: approvedLocally ?? this.approvedLocally,
    serverId: serverId,
  );
}

/// Only an in-memory staging area. Does not modify or publish Documents.
class NoteDocumentDraftSession {
  NoteDocumentDraftSession._();
  static final Map<String, NoteDocumentDraft> _drafts = {};

  static String _key(String noteId, String documentType) =>
      (ActiveCompanySession.companyId?.toString() ?? 'demo') +
      '::' + noteId + '::' + documentType;

  static NoteDocumentDraft? forNote(String id, String type) =>
      _drafts[_key(id, type)];

  static void save(NoteDocumentDraft draft) {
    if (draft.title.trim().isEmpty || draft.content.trim().isEmpty ||
        draft.jobId.trim().isEmpty || draft.noteId.trim().isEmpty) {
      throw const FormatException('The document title and text are required.');
    }
    _drafts[_key(draft.noteId, draft.documentType)] = draft;
  }

  static void clear() => _drafts.clear();
}

abstract interface class NoteDocumentPreparationService {
  Future<NoteDocumentDraft> prepare(
    JobNoteModel note, String documentType);
}
