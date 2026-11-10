import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/job_photo_local_store.dart';
import '../../data/remote_job_media_repository.dart';
import '../../../../core/services/sign_api_client.dart';
import '../../data/local_job_photo_source.dart';
import '../../domain/job_model.dart';
import '../../domain/job_photo_model.dart';
import '../widgets/sign2digital_photo_preview.dart';
import '../widgets/sign2digital_photo_source_card.dart';

/// Multi-photo editor. Saved jobs upload to Laravel private storage; any
/// injected local store is intended only for isolated UI tests.
class AddPhotosScreen extends StatefulWidget {
  const AddPhotosScreen({
    super.key,
    required this.job,
    this.source,
    this.store,
    this.initialSelection,
    this.initialCategory = JobPhotoCategory.during,
    this.onTabSelected,
    this.remoteRepository,
  });

  final JobModel job;
  final JobPhotoSource? source;
  final JobPhotoLocalStore? store;
  final LocalJobPhotoSelection? initialSelection;
  final JobPhotoCategory initialCategory;
  final ValueChanged<int>? onTabSelected;
  /// Inject only for tests; real jobs always use Laravel private storage.
  final RemoteJobMediaRepository? remoteRepository;

  @override
  State<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends State<AddPhotosScreen> {
  static const _maxCaptionLength = 187;
  late final JobPhotoSource _source;
  late final JobPhotoLocalStore _store;
  late final TextEditingController _caption;
  final List<LocalJobPhotoSelection> _selections = [];
  int _previewIndex = 0;
  late JobPhotoCategory _category;
  bool _showDemo = true;
  bool _picking = false;
  bool _saving = false;

  bool get _hasUnsavedChanges => _selections.isNotEmpty || _caption.text.isNotEmpty;
  bool get _liveJob => (int.tryParse(widget.job.id) ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _source = widget.source ?? DeviceJobPhotoSource();
    _store = widget.store ?? JobPhotoLocalStore.shared;
    if (widget.initialSelection != null) {
      _selections.add(widget.initialSelection!);
    }
    _category = widget.initialCategory;
    _caption = TextEditingController()..addListener(_captionChanged);
  }

  void _captionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _caption.removeListener(_captionChanged);
    _caption.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choose({required bool camera}) async {
    if (_picking || _saving) return;
    setState(() => _picking = true);
    try {
      final picked = <LocalJobPhotoSelection>[];
      if (camera) {
        final captured = await _source.camera();
        if (captured != null) picked.add(captured);
      } else {
        picked.addAll(await _source.upload());
      }
      if (picked.isEmpty || !mounted) return;
      for (final file in picked) {
        DeviceJobPhotoSource.validate(file.name, file.bytes);
      }
      setState(() {
        if (!camera) _selections.clear();
        for (final file in picked) {
          if (!_selections.any((p) => p.sourceKey == file.sourceKey)) {
            _selections.add(file);
          }
        }
        _previewIndex = 0;
        _showDemo = false;
      });
    } catch (error) {
      if (!mounted) return;
      _message(error is FormatException ? error.message :
        camera
          ? 'Unable to open the camera. Check camera permission.'
          : 'Unable to select images. Please try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePreview() {
    setState(() {
      if (_selections.isNotEmpty) {
        _selections.removeAt(_previewIndex.clamp(0, _selections.length - 1));
      }
      _previewIndex = 0;
      _showDemo = false;
    });
  }

  Future<void> _goBack() async {
    if (_hasUnsavedChanges) {
      final discard = await showDialog<bool>(
        context: context,
        barrierColor: const Color(0x80000000),
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Discard unsaved photo?'),
          content: const Text(
            'Your selected photo and caption have not been saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_picking || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selections.isEmpty) {
      _message('Take a photo or choose a real image before saving.');
      return;
    }
    if (widget.store == null && !_liveJob) {
      _message('Save this job to your company before uploading photos.');
      return;
    }
    setState(() => _saving = true);
    var savedCount = 0;
    try {
      final entries = List<LocalJobPhotoSelection>.of(_selections);
      final caption = _caption.text.trim();
      for (final selection in entries) {
        DeviceJobPhotoSource.validate(selection.name, selection.bytes);
        if (widget.store == null) {
          // Persisted jobs NEVER fall back to local memory when an API call
          // fails or the selected company is unavailable.
          await (widget.remoteRepository ?? RemoteJobMediaRepository.shared)
              .uploadPhoto(widget.job.id, selection, _category, caption);
        } else {
          final existing = _store.photosFor(widget.job.id);
          if (!existing.any((p) => p.sourceKey == selection.sourceKey)) {
            final time = DateTime.now();
            _store.addAll(widget.job.id, [
              JobPhotoModel(
                id: 'local-${widget.job.id}-${time.microsecondsSinceEpoch}-$savedCount',
                jobId: widget.job.id,
                title: caption.isEmpty ? 'Front View' : caption,
                caption: caption,
                category: _category,
                createdAt: time,
                bytes: selection.bytes,
                sourceKey: selection.sourceKey,
              ),
            ]);
          }
        }
        savedCount++;
        // Retry only the remaining images after a partial upload failure.
        _selections.remove(selection);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _previewIndex = 0);
        final detail = error is SignApiException ? error.message
            : error is FormatException ? error.message
            : 'Unable to save photos. Please try again.';
        _message(savedCount > 0
            ? '$savedCount photo(s) saved. $detail Retry remaining photos.'
            : detail);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectNav(int index) {
    if (index == 1) return;
    _goBack();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = JobPhotoCategory.values.indexOf(_category);
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalHeader(title: 'Job Photos', onBack: _goBack),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('add-photos-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add Photos',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Take a photo or choose from your gallery',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Sign2DigitalPhotoSourceCard(
                              key: const Key('add-photo-camera'),
                              title: 'Take a Photo',
                              description: 'Open camera and take photos',
                              iconAsset: 'assets/icons/camera-outlined.svg',
                              enabled: !_picking && !_saving,
                              onTap: () => _choose(camera: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Sign2DigitalPhotoSourceCard(
                              key: const Key('add-photo-gallery'),
                              title: 'Choose from Gallery',
                              description: 'Choose an existing photo',
                              iconAsset:
                                  'assets/icons/cloud-upload-outlined.svg',
                              enabled: !_picking && !_saving,
                              onTap: () => _choose(camera: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Sign2DigitalDetailsTabs(
                      labels: const ['Before', 'During', 'After'],
                      selectedIndex: selectedIndex,
                      onSelected: (index) => setState(
                        () => _category = JobPhotoCategory.values[index],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Photo Preview',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_selections.length <= 1)
                      Sign2DigitalPhotoPreview(
                        bytes: _selections.isEmpty ? null : _selections.first.bytes,
                        showDemo: _showDemo,
                        onRemove: _removePreview,
                      )
                    else ...[
                      LayoutBuilder(builder: (context, constraints) =>
                        SizedBox(
                          height: (constraints.maxWidth * 180 / 390)
                              .clamp(155.0, 260.0).toDouble(),
                          child: PageView.builder(
                            key: const Key('add-photo-preview-pages'),
                            itemCount: _selections.length,
                            onPageChanged: (index) =>
                                setState(() => _previewIndex = index),
                            itemBuilder: (context, index) =>
                                Sign2DigitalPhotoPreview(
                                  bytes: _selections[index].bytes,
                                  showDemo: false,
                                  onRemove: () {
                                    setState(() => _previewIndex = index);
                                    _removePreview();
                                  },
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Photo ${_previewIndex + 1} of ${_selections.length}',
                        key: const Key('add-photo-preview-counter'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Sign2DigitalInputField(
                      key: const Key('add-photo-caption-field'),
                      label: 'Caption',
                      hintText: 'Complete renovation of the terrace, including new tiles, waterproofing and railings',
                      iconAsset: 'assets/icons/description.svg',
                      controller: _caption,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: null,
                      maxLength: _maxCaptionLength,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_caption.text.length}/$_maxCaptionLength',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.placeholder,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Sign2DigitalPrimaryButton(
                      key: const Key('add-photo-save'),
                      label: _selections.length > 1 ? 'Save Photos' : 'Save Photo',
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: 1,
        onSelected: _selectNav,
      ),
    );
  }
}
