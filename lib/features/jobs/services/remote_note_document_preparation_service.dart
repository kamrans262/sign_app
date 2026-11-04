import '../data/remote_job_media_repository.dart';
import '../domain/job_note_model.dart';
import '../domain/note_document_draft.dart';

/// Use existing Laravel OpenAI credentials; never ask the user for API keys.
class RemoteNoteDocumentPreparationService
    implements NoteDocumentPreparationService {
  RemoteNoteDocumentPreparationService({RemoteJobMediaRepository? repository})
      : repository = repository ?? RemoteJobMediaRepository.shared;
  final RemoteJobMediaRepository repository;
  @override
  Future<NoteDocumentDraft> prepare(JobNoteModel note, String type) =>
      repository.prepareNote(note, type);
}
