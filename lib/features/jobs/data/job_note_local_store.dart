import '../domain/job_note_model.dart';
import 'demo_job_notes.dart';

/// Session-only job-scoped notes. Does not upload or authorize customer access.
class JobNoteLocalStore {
  JobNoteLocalStore({this.includeDemoNotes = true});
  static final JobNoteLocalStore shared = JobNoteLocalStore();
  final bool includeDemoNotes;
  final Map<String, List<JobNoteModel>> _byJob = {};

  List<JobNoteModel> notesFor(String jobId) => List.unmodifiable(
    _byJob.putIfAbsent(jobId, () => [
      if (includeDemoNotes) ...DemoJobNotes.forJob(jobId),
    ]),
  );

  void add(JobNoteModel note) {
    if (note.id.trim().isEmpty || note.jobId.trim().isEmpty) {
      throw ArgumentError('Notes require a job and a unique ID.');
    }
    if (note.title.trim().isEmpty ||
        (note.body.trim().isEmpty && note.audioPath == null)) {
      throw ArgumentError('Enter note text or record audio.');
    }
    final notes = _byJob.putIfAbsent(note.jobId, () => [
      if (includeDemoNotes) ...DemoJobNotes.forJob(note.jobId),
    ]);
    if (notes.any((item) => item.id == note.id)) {
      throw StateError('Note already exists.');
    }
    notes.insert(0, note);
  }

  void clear() => _byJob.clear();
}
