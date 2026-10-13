import '../domain/job_note_model.dart';

/// Per-job demonstration notes. Voice recordings are not fabricated.
abstract final class DemoJobNotes {
  static List<JobNoteModel> forJob(String jobId, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final moment = DateTime(
      reference.year,
      reference.month,
      reference.day,
      10,
      24,
    );
    return List<JobNoteModel>.unmodifiable([
      for (var index = 0; index < 3; index++)
        JobNoteModel(
          id: '$jobId-demo-note-${index + 1}',
          jobId: jobId,
          title: 'Site meeting with client',
          body: 'Discuss color options and other main things we need',
          createdAt: moment,
          // The second Figma example is a text note with an audio icon;
          // no playable recording is invented.
          type: index == 1 ? JobNoteType.textWithAudio : JobNoteType.text,
          visibility: index == 2
              ? JobNoteVisibility.customerFacing
              : JobNoteVisibility.privateNote,
        ),
    ]);
  }
}
