import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A separate seam makes recording testable without native microphone plugins.
abstract class VoiceRecorderService {
  Stream<double> get amplitude; // normalized 0..1
  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<String> save();
  Future<void> cancel();
  Future<void> dispose();
}

class VoiceRecordingPermissionException implements Exception {
  const VoiceRecordingPermissionException();
  @override
  String toString() => 'Microphone permission is required to record audio.';
}

class LocalVoiceRecorderService implements VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<double> _levels = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _subscription;
  String? _path;
  bool _recording = false;
  bool _disposed = false;

  @override
  Stream<double> get amplitude => _levels.stream;

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('Recorder has been disposed');
    if (!await _recorder.hasPermission()) {
      throw const VoiceRecordingPermissionException();
    }
    final folder = await getApplicationDocumentsDirectory();
    final path =
        '${folder.path}${Platform.pathSeparator}s2d_job_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
    _path = path;
    _recording = true;
    _subscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((level) {
          if (!_levels.isClosed) {
            _levels.add(((level.current + 50) / 50).clamp(0.0, 1.0).toDouble());
          }
        });
  }

  @override
  Future<void> pause() async {
    if (_recording) await _recorder.pause();
  }

  @override
  Future<void> resume() async {
    if (_recording) await _recorder.resume();
  }

  @override
  Future<String> save() async {
    if (!_recording) throw StateError('No active recording to save');
    await _subscription?.cancel();
    _subscription = null;
    final result = await _recorder.stop();
    _recording = false;
    final path = result ?? _path;
    if (path == null ||
        !await File(path).exists() ||
        await File(path).length() == 0) {
      throw StateError('No recorded audio was captured. Please try again.');
    }
    _path = null; // The saved audio belongs to the user, not the recorder.
    return path;
  }

  @override
  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_recording) {
      await _recorder.cancel();
      _recording = false;
    }
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await cancel();
    } finally {
      await _recorder.dispose();
      await _levels.close();
    }
  }
}
