import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_modal_surface.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../models/extracted_job_details.dart';
import '../../services/voice_job_extraction_service.dart';
import '../../services/voice_recorder_service.dart';
import 'sign2digital_audio_waveform.dart';
import 'sign2digital_recording_control.dart';

enum _VoiceStep {
  preparing,
  recording,
  paused,
  saving,
  processing,
  apiKey,
  error,
  unavailable,
}

/// Single dialog route/barrier for the entire recording -> processing transition.
class AiVoiceFlowDialog extends StatefulWidget {
  const AiVoiceFlowDialog({
    super.key,
    required this.recorder,
    required this.extraction,
    this.recordingTitle = 'Record Deposit Details',
    this.onQuoteAudioSaved,
    this.onAudioProcessed,
    this.rawAudioMode = false,
  });

  final VoiceRecorderService recorder;
  final VoiceJobExtractionService extraction;
  final String recordingTitle;
  final bool rawAudioMode;
  final ValueChanged<String>? onQuoteAudioSaved;
  /// Optional domain-specific processing using the existing recorder/dialog.
  /// The processing screen remains visible until this Future completes.
  final Future<void> Function(String savedAudioPath)? onAudioProcessed;

  static Future<ExtractedJobDetails?> show(
    BuildContext context, {
    required VoiceRecorderService recorder,
    required VoiceJobExtractionService extraction,
  }) {
    return showDialog<ExtractedJobDetails>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x80000000),
      useSafeArea: true,
      builder: (_) =>
          AiVoiceFlowDialog(recorder: recorder, extraction: extraction),
    );
  }

  @override
  State<AiVoiceFlowDialog> createState() => _AiVoiceFlowDialogState();
}

class _AiVoiceFlowDialogState extends State<AiVoiceFlowDialog>
    with WidgetsBindingObserver {
  _VoiceStep _step = _VoiceStep.preparing;
  bool _busy = false;
  bool _attemptedStart = false;
  String? _error;
  String? _savedPath;
  double _level = 0.35;
  StreamSubscription<double>? _levels;
  final _apiKeyInput = TextEditingController();
  bool _keyVisible = false;

  static const _heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -.3,
    height: 1.12,
    color: AppColors.dark,
    decoration: TextDecoration.none,
  );
  static const _support = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -.3,
    height: 1.22,
    color: AppColors.placeholder,
    decoration: TextDecoration.none,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _levels = widget.recorder.amplitude.listen((value) {
      if (mounted && _step == _VoiceStep.recording) {
        setState(() => _level = value.clamp(0.0, 1.0).toDouble());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _step == _VoiceStep.recording) {
      unawaited(_pause());
    }
  }

  Future<void> _start() async {
    if (!mounted || _busy) {
      return;
    }
    _busy = true;
    setState(() {
      _step = _VoiceStep.preparing;
      _error = null;
    });
    try {
      if (_attemptedStart) {
        await widget.recorder.cancel();
      }
      _attemptedStart = true;
      await widget.recorder.start();
      if (!mounted) {
        await widget.recorder.cancel();
        return;
      }
      setState(() => _step = _VoiceStep.recording);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _VoiceStep.error;
          _error = e is VoiceRecordingPermissionException
              ? 'Microphone permission denied. Allow microphone access in your device settings and try again.'
              : 'Unable to start recording: $e';
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _pause() async {
    if (_busy || _step != _VoiceStep.recording) {
      return;
    }
    _busy = true;
    try {
      await widget.recorder.pause();
      if (mounted) {
        setState(() => _step = _VoiceStep.paused);
      }
    } catch (e) {
      _setError(e);
    } finally {
      _busy = false;
    }
  }

  Future<void> _resume() async {
    if (_busy || _step != _VoiceStep.paused) {
      return;
    }
    _busy = true;
    try {
      await widget.recorder.resume();
      if (mounted) {
        setState(() => _step = _VoiceStep.recording);
      }
    } catch (e) {
      _setError(e);
    } finally {
      _busy = false;
    }
  }

  void _setError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _step = _VoiceStep.error;
      _error = error is TimeoutException
          ? 'AI processing timed out. You can retry without re-recording.'
          : error.toString().replaceFirst('Bad state: ', '');
    });
  }

  Future<void> _save() async {
    if (_busy ||
        !(_step == _VoiceStep.recording || _step == _VoiceStep.paused)) {
      return;
    }
    _busy = true;
    setState(() => _step = _VoiceStep.saving);
    try {
      _savedPath = await widget.recorder.save();
      if (!mounted) {
        return;
      }
      // The route and its black barrier remain mounted while content changes.
      setState(() => _step = _VoiceStep.processing);
    } catch (e) {
      _setError(e);
      return;
    } finally {
      _busy = false;
    }
    if (mounted) {
      await _extract();
    }
  }

  Future<void> _extract() async {
    if (widget.onAudioProcessed != null) {
      final path = _savedPath;
      if (path == null || !mounted || _busy) { return; }
      _busy = true;
      setState(() { _step = _VoiceStep.processing; _error = null; });
      try {
        await widget.onAudioProcessed!(path).timeout(const Duration(seconds: 110));
        if (mounted) { Navigator.of(context).pop(); }
      } catch (error) {
        _setError(error);
      } finally {
        _busy = false;
      }
      return;
    }
    // Quote mode shares the recorder, then lets Create Quote run its own AI
    // service and collect a temporary API key. Never use job-field extraction.
    if (widget.onQuoteAudioSaved != null) {
      final path = _savedPath;
      if (path == null || !mounted) {
        return;
      }
      try {
        widget.onQuoteAudioSaved!(path);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        _setError(error);
      }
      return;
    }
    if (_busy || _savedPath == null || !mounted) {
      return;
    }
    if (!widget.extraction.isConfigured) {
      setState(() {
        if (widget.extraction is OpenAiVoiceJobExtractionService) {
          _step = _VoiceStep.apiKey;
          _error = null;
        } else {
          _step = _VoiceStep.unavailable;
          _error = 'AI extraction is not configured for this recording.';
        }
      });
      return;
    }
    _busy = true;
    setState(() {
      _step = _VoiceStep.processing;
      _error = null;
    });
    try {
      final result = await widget.extraction
          .extract(_savedPath!)
          .timeout(const Duration(seconds: 110));
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } on VoiceAiAuthenticationException {
      final service = widget.extraction;
      if (service is OpenAiVoiceJobExtractionService) {
        service.clearTemporaryApiKey();
      }
      _apiKeyInput.clear();
      if (mounted) {
        setState(() {
          _step = _VoiceStep.apiKey;
          _error = 'The API key was rejected. Enter a valid key to retry.';
        });
      }
    } catch (e) {
      _setError(e);
    } finally {
      _busy = false;
    }
  }

  Future<void> _useApiKey() async {
    if (_busy || _savedPath == null) {
      return;
    }
    final key = _apiKeyInput.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter your OpenAI API key.');
      return;
    }
    final service = widget.extraction;
    if (service is! OpenAiVoiceJobExtractionService) {
      return;
    }
    service.setTemporaryApiKey(key);
    _apiKeyInput.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await _extract();
  }

  Future<void> _close() async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      // Keep audio already saved; discard only unfinished recordings.
      if (_savedPath == null) {
        await widget.recorder.cancel();
      }
    } catch (_) {
      // Closing must still be possible after native-recorder failure.
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final levels = _levels;
    if (levels != null) {
      unawaited(levels.cancel());
    }
    unawaited(widget.recorder.dispose());
    _apiKeyInput.dispose();
    super.dispose();
  }

  Widget _roundAsset(String name, Color background, {Color? color}) =>
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          name,
          width: 26,
          height: 26,
          colorFilter: color == null
              ? null
              : ColorFilter.mode(color, BlendMode.srcIn),
          errorBuilder: (context, error, stackTrace) => Icon(
            name.endsWith('microphone.svg') ? Icons.mic : Icons.auto_awesome,
            color: color ?? AppColors.primary,
            size: 24,
          ),
        ),
      );

  Widget _label(String label, TextStyle style) =>
      Text(label, textAlign: TextAlign.center, style: style);

  Widget _buttons({required bool canSave}) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            key: const Key('voice-cancel'),
            onPressed: _busy ? null : _close,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 15),
      Expanded(
        child: Sign2DigitalPrimaryButton(
          key: const Key('voice-save'),
          label: 'Save',
          enabled: canSave && !_busy,
          onPressed: _save,
        ),
      ),
    ],
  );

  Widget _recording() {
    final active = _step == _VoiceStep.recording;
    final paused = _step == _VoiceStep.paused;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundAsset(
          'assets/icons/microphone.svg',
          AppColors.primary,
          color: AppColors.white,
        ),
        const SizedBox(height: 20),
        Sign2DigitalAudioWaveform(
          key: const Key('voice-recording-waveform'),
          animating: active,
          amplitude: _level,
        ),
        const SizedBox(height: 20),
        _label(widget.recordingTitle, _heading),
        const SizedBox(height: 5),
        _label('Speak clearly and naturally', _support),
        const SizedBox(height: 5),
        _label(
          widget.rawAudioMode
            ? 'Save this recording as a local job-note attachment'
            : 'AI will extract the information and fill the form for you',
          _support,
        ),
        const SizedBox(height: 15),
        Text(
          active
              ? '● Recording'
              : paused
              ? 'Paused'
              : _step == _VoiceStep.saving
              ? 'Saving…'
              : 'Preparing microphone…',
          key: const Key('voice-recording-status'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? const Color(0xFFCF080F) : AppColors.placeholder,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: -.3,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 15),
        if (active || paused)
          Sign2DigitalRecordingControl(
            paused: paused,
            onPressed: paused ? _resume : _pause,
          )
        else
          const SizedBox(
            height: 50,
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        _buttons(canSave: active || paused),
      ],
    );
  }

  Widget _processing() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _roundAsset('assets/icons/stars.svg', const Color(0xFFE3ECF0)),
      const SizedBox(height: 20),
      _label('AI is Processing your Voice', _heading),
      const SizedBox(height: 5),
      _label(
        'Please wait a moment while we extract details and fill the form',
        _support,
      ),
      const SizedBox(height: 24),
      const Sign2DigitalAudioWaveform(
        key: Key('voice-processing-waveform'),
        animating: true,
        processing: true,
      ),
    ],
  );

  Widget _apiKeyPrompt() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _roundAsset('assets/icons/stars.svg', const Color(0xFFE3ECF0)),
      const SizedBox(height: 20),
      _label('Connect AI Processing', _heading),
      const SizedBox(height: 8),
      _label(
        'Enter your OpenAI API key to transcribe this recording and fill the job form.',
        _support,
      ),
      const SizedBox(height: 16),
      TextField(
        key: const Key('voice-openai-api-key'),
        controller: _apiKeyInput,
        obscureText: !_keyVisible,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _useApiKey(),
        decoration: InputDecoration(
          hintText: 'OpenAI API key',
          isDense: true,
          filled: false,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: IconButton(
            tooltip: _keyVisible ? 'Hide API key' : 'Show API key',
            onPressed: () => setState(() => _keyVisible = !_keyVisible),
            icon: Icon(
              _keyVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _label(
        'For personal testing only. Your key is kept in memory while this screen is open, and your voice recording is sent directly to OpenAI. API charges may apply.',
        _support.copyWith(fontSize: 11),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFFCF080F),
            decoration: TextDecoration.none,
          ),
        ),
      ],
      const SizedBox(height: 20),
      Sign2DigitalPrimaryButton(
        key: const Key('voice-process-with-key'),
        label: 'Process recording',
        onPressed: _useApiKey,
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: _close,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Close / Manual Entry'),
        ),
      ),
    ],
  );

  Widget _problem() {
    final canRetryProcessing = _savedPath != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundAsset('assets/icons/stars.svg', const Color(0xFFE3ECF0)),
        const SizedBox(height: 20),
        _label(
          _step == _VoiceStep.unavailable
              ? 'AI extraction unavailable'
              : 'Voice processing issue',
          _heading,
        ),
        const SizedBox(height: 10),
        _label(_error ?? 'An unexpected error occurred.', _support),
        if (_savedPath != null) ...[
          const SizedBox(height: 8),
          _label('Your recording has been saved on this device.', _support),
        ],
        const SizedBox(height: 20),
        if (_step != _VoiceStep.unavailable) ...[
          Sign2DigitalPrimaryButton(
            label: 'Retry',
            onPressed: canRetryProcessing ? _extract : _start,
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _close,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close / Manual Entry'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final processing = _step == _VoiceStep.processing;
    final problem =
        _step == _VoiceStep.error || _step == _VoiceStep.unavailable;
    final needsApiKey = _step == _VoiceStep.apiKey;
    return PopScope(
      canPop: false,
      child: Sign2DigitalModalSurface(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          child: KeyedSubtree(
            key: ValueKey(
              problem
                  ? 'problem'
                  : needsApiKey
                  ? 'api-key'
                  : processing
                  ? 'processing'
                  : 'recording',
            ),
            child: problem
                ? _problem()
                : needsApiKey
                ? _apiKeyPrompt()
                : processing
                ? _processing()
                : _recording(),
          ),
        ),
      ),
    );
  }
}
