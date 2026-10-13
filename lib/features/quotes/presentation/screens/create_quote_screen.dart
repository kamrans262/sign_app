import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_source_card.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../domain/quote_draft_input.dart';
import '../../domain/quote_preparation_service.dart';
import '../../services/openai_quote_preparation_service.dart';
import 'quote_ai_processing_screen.dart';
import '../widgets/sign2digital_quote_input_method_card.dart';

/// New, frontend-only Create Quote entry screen. No fabricated AI draft.
/// The voice dialog is the SAME dialog that Create Job uses.
class CreateQuoteScreen extends StatefulWidget {
  const CreateQuoteScreen({
    super.key,
    this.clientId,
    this.jobId,
    this.voiceRecorderFactory,
    this.pickImage,
    this.onInputPrepared,
    this.quotePreparationService,
  });

  final String? clientId;
  final String? jobId;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final Future<XFile?> Function(ImageSource source)? pickImage;
  final ValueChanged<QuoteDraftInput>? onInputPrepared;
  final QuotePreparationService? quotePreparationService;

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen> {
  QuoteInputMethod _method = QuoteInputMethod.voice;
  final TextEditingController _description = TextEditingController();
  String? _savedAudioPath;
  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  bool _voiceDialogOpen = false;
  bool _pickingImage = false;

  static const _example =
      '“Install 3 windows, each 1.2m x 1.5m, with white PVC frames and '
      'standard glazing. Include removal of old windows and all labour. '
      'Located at 12 Oak Road, London.”';

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _select(QuoteInputMethod method) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _method = method);
    // Voice card interaction opens the recorder immediately.
    if (method == QuoteInputMethod.voice) {
      _openVoice();
    }
  }

  Future<void> _openVoice() async {
    if (_voiceDialogOpen || !mounted) {
      return;
    }
    _voiceDialogOpen = true;
    var recordingSaved = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x80000000),
        useSafeArea: true,
        builder: (_) => AiVoiceFlowDialog(
          recorder:
              widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          // The shared recorder never passes quote input to job AI.
          // Quote extraction starts after recording in Create Quote.
          extraction: OpenAiVoiceJobExtractionService(),
          recordingTitle: 'Record Quote Details',
          onQuoteAudioSaved: (path) {
            recordingSaved = true;
            if (mounted) {
              setState(() => _savedAudioPath = path);
            }
          },
        ),
      );
    } finally {
      _voiceDialogOpen = false;
    }
    // A completed voice recording immediately continues to real quote AI.
    if (mounted && recordingSaved) {
      await _generate();
    }
  }

  Future<void> _choosePhoto() async {
    if (_pickingImage || !mounted) {
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    _pickingImage = true;
    try {
      final selected = widget.pickImage == null
          ? await ImagePicker().pickImage(source: source, imageQuality: 85)
          : await widget.pickImage!(source);
      if (selected == null) {
        return;
      }
      final lowerName = selected.name.toLowerCase();
      if (!(lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png'))) {
        throw const FormatException('Choose a JPG or PNG image.');
      }
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('The selected image is empty.');
      }
      if (bytes.length > 15 * 1024 * 1024) {
        throw const FormatException('Select an image smaller than 15 MB.');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedImagePath = selected.path;
        _selectedImageBytes = bytes;
      });
    } catch (error) {
      _message('Unable to select photo: $error');
    } finally {
      _pickingImage = false;
    }
  }

  /// Runtime-only developer key. Never save it in preferences, assets or logs.
  Future<String?> _requestTemporaryApiKey() async {
    String draft = '';
    bool visible = false;
    String? error;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Connect Quote AI'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'For private development testing: enter your OpenAI API key '
                    'to analyze this quote input. The key is kept in memory only. '
                    'Do not use this method in a published app.',
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    key: const Key('quote-openai-api-key'),
                    obscureText: !visible,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    onChanged: (value) => draft = value,
                    decoration: InputDecoration(
                      labelText: 'OpenAI API key',
                      border: const OutlineInputBorder(),
                      errorText: error,
                      suffixIcon: IconButton(
                        tooltip: visible ? 'Hide API key' : 'Show API key',
                        icon: Icon(visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => update(() => visible = !visible),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('quote-connect-ai'),
              onPressed: () {
                final key = draft.trim();
                if (key.isEmpty ||
                    RegExp(r'[\x00-\x20\x7F]').hasMatch(key)) {
                  update(() => error = 'Paste a valid API key.');
                  return;
                }
                Navigator.of(dialogContext).pop(key);
              },
              child: const Text('Generate with AI'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_method == QuoteInputMethod.voice && _savedAudioPath == null) {
      await _openVoice();
      return;
    }
    if (_method == QuoteInputMethod.handwrittenPhoto &&
        _selectedImagePath == null) {
      _message('Upload an image to generate a quote.');
      return;
    }
    if (_method == QuoteInputMethod.text && _description.text.trim().isEmpty) {
      _message('Enter your quote instructions before generating a draft.');
      return;
    }
    final prepared = QuoteDraftInput(
      method: _method,
      createdAt: DateTime.now(),
      clientId: widget.clientId,
      jobId: widget.jobId,
      description: _method == QuoteInputMethod.text
          ? _description.text.trim()
          : null,
      audioPath: _method == QuoteInputMethod.voice ? _savedAudioPath : null,
      photoPath: _method == QuoteInputMethod.handwrittenPhoto
          ? _selectedImagePath
          : null,
    );
    if (widget.onInputPrepared != null) {
      widget.onInputPrepared!(prepared);
      return;
    }
    QuotePreparationService service;
    if (widget.quotePreparationService != null) {
      service = widget.quotePreparationService!;
    } else {
      final key = await _requestTemporaryApiKey();
      if (!mounted || key == null) {
        return;
      }
      service = OpenAiQuotePreparationService(temporaryApiKey: key);
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => QuoteAiProcessingScreen(
          input: prepared,
          service: service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      // This action remains usable on short screens and above the keyboard.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Sign2DigitalPrimaryButton(
                    key: const Key('quote-generate-draft'),
                    label: '',
                    onPressed: _generate,
                  ),
                  IgnorePointer(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/stars.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                            AppColors.white,
                            BlendMode.srcIn,
                          ),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.auto_awesome,
                                color: AppColors.white,
                                size: 22,
                              ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Generate Draft',
                          style: AppTextStyles.primaryButton,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: 'Create Quote',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('create-quote-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Sign2DigitalQuoteInputMethodCard(
                          key: const Key('quote-method-voice'),
                          label: 'Voice',
                          description: 'Describe your project out loud and let AI do the rest',
                          iconAsset: 'assets/icons/microphone.svg',
                          fallbackIcon: Icons.mic_none_outlined,
                          selected: _method == QuoteInputMethod.voice,
                          onTap: () => _select(QuoteInputMethod.voice),
                        ),
                        const SizedBox(height: 20),
                        Sign2DigitalQuoteInputMethodCard(
                          key: const Key('quote-method-text'),
                          label: 'Text',
                          description:
                              'Type or paste your project details manually',
                          iconAsset: 'assets/icons/description.svg',
                          fallbackIcon: Icons.description_outlined,
                          selected: _method == QuoteInputMethod.text,
                          onTap: () => _select(QuoteInputMethod.text),
                        ),
                        const SizedBox(height: 20),
                        Sign2DigitalQuoteInputMethodCard(
                          key: const Key('quote-method-photo'),
                          label: 'Photo of handwritten Notes',
                          description:
                              'Take a photo of sketches, measurements or notes',
                          iconAsset: 'assets/icons/camera-outlined.svg',
                          fallbackIcon: Icons.photo_camera_outlined,
                          selected:
                              _method == QuoteInputMethod.handwrittenPhoto,
                          onTap: () =>
                              _select(QuoteInputMethod.handwrittenPhoto),
                        ),
                        const SizedBox(height: 20),
                        if (_method == QuoteInputMethod.text) ...[
                          const Text(
                            'Example Prompt',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            constraints: const BoxConstraints(minHeight: 150),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: AppColors.placeholder.withAlpha(26),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              key: const Key('quote-text-input'),
                              controller: _description,
                              minLines: 4,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              scrollPadding: const EdgeInsets.all(90),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                                hintText: _example,
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: AppColors.placeholder,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.dark,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                        if (_method == QuoteInputMethod.handwrittenPhoto) ...[
                          Sign2DigitalPhotoSourceCard(
                            key: const Key('quote-photo-upload'),
                            title: _selectedImageBytes == null
                                ? 'Upload Image' : 'Change Image',
                            description: 'Take a photo or choose an image from your gallery',
                            iconAsset: 'assets/icons/camera-outlined.svg',
                            onTap: _choosePhoto,
                          ),
                        ],
                        if (_method == QuoteInputMethod.voice &&
                            _savedAudioPath != null) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Voice recording saved locally',
                            style: AppTextStyles.fieldHint,
                          ),
                        ],
                        if (_method == QuoteInputMethod.handwrittenPhoto &&
                            _selectedImageBytes != null) ...[
                          const SizedBox(height: 20),
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _selectedImageBytes!,
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(
                                        height: 180,
                                        child: Center(
                                          child: Text(
                                            'Unable to preview this image',
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                              IconButton.filled(
                                key: const Key('quote-remove-photo'),
                                tooltip: 'Remove photo',
                                onPressed: () => setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImagePath = null;
                                }),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
