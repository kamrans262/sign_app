import 'package:sign2digital/features/jobs/models/extracted_job_details.dart';
import 'package:sign2digital/features/jobs/services/voice_job_extraction_service.dart';
import 'package:sign2digital/features/jobs/services/voice_recorder_service.dart';

class FakeVoiceRecorder implements VoiceRecorderService {
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int saves = 0;
  int cancels = 0;
  bool disposed = false;
  bool failStart = false;

  @override
  Stream<double> get amplitude => const Stream<double>.empty();

  @override
  Future<void> start() async {
    starts++;
    if (failStart) throw const VoiceRecordingPermissionException();
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<String> save() async {
    saves++;
    return 'fake-audio.m4a';
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeVoiceExtraction implements VoiceJobExtractionService {
  FakeVoiceExtraction({this.configured = true, this.onExtract});
  final bool configured;
  final Future<ExtractedJobDetails> Function(String)? onExtract;
  int calls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<ExtractedJobDetails> extract(String path) async {
    calls++;
    return onExtract?.call(path) ??
        const ExtractedJobDetails(
          address: 'Rue de Genève 12, Lausanne',
          description: 'Renovate the terrace and replace the railings.',
          budgetChf: 9800,
        );
  }
}
