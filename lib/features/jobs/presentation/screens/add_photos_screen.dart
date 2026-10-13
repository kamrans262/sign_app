import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/job_photo_local_store.dart';
import '../../data/local_job_photo_source.dart';
import '../../domain/job_model.dart';
import '../../domain/job_photo_model.dart';
import '../widgets/sign2digital_photo_preview.dart';
import '../widgets/sign2digital_photo_source_card.dart';

/// A single-photo editor. Demo preview is decorative, never saved as a photo.
/// A saved photo is added to the same in-memory store used by JobPhotosScreen.
class AddPhotosScreen extends StatefulWidget {
  const AddPhotosScreen({
    super.key,
    required this.job,
    this.source,
    this.store,
    this.initialSelection,
    this.initialCategory = JobPhotoCategory.during,
    this.onTabSelected,
  });

  final JobModel job;
  final JobPhotoSource? source;
  final JobPhotoLocalStore? store;
  final LocalJobPhotoSelection? initialSelection;
  final JobPhotoCategory initialCategory;
  final ValueChanged<int>? onTabSelected;

  @override
  State<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends State<AddPhotosScreen> {
  static const _maxCaptionLength = 187;
  late final JobPhotoSource _source;
  late final JobPhotoLocalStore _store;
  late final TextEditingController _caption;
  LocalJobPhotoSelection? _selection;
  late JobPhotoCategory _category;
  bool _showDemo = true;
  bool _picking = false;
  bool _saving = false;

  bool get _hasUnsavedChanges => _selection != null || _caption.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _source = widget.source ?? DeviceJobPhotoSource();
    _store = widget.store ?? JobPhotoLocalStore.shared;
    _selection = widget.initialSelection;
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
      LocalJobPhotoSelection? next;
      if (camera) {
        next = await _source.camera();
      } else {
        final selected = await _source.upload();
        next = selected.isEmpty ? null : selected.first;
        if (selected.length > 1 && mounted) {
          _message('One photo at a time can be edited here.');
        }
      }
      if (next == null || !mounted) return;
      DeviceJobPhotoSource.validate(next.name, next.bytes);
      setState(() {
        _selection = next;
        _showDemo = false;
      });
    } catch (error) {
      if (!mounted) return;
      _message(
        error is FormatException
            ? error.message
            : camera
            ? 'Unable to open the camera. Check camera permission.'
            : 'Unable to choose a photo. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePreview() {
    setState(() {
      _selection = null;
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
    final selection = _selection;
    if (selection == null) {
      _message('Take a photo or choose a real image before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      DeviceJobPhotoSource.validate(selection.name, selection.bytes);
      final existing = _store.photosFor(widget.job.id);
      if (existing.any((photo) => photo.sourceKey == selection.sourceKey)) {
        _message('This photo has already been added.');
        return;
      }
      final caption = _caption.text.trim();
      final timestamp = DateTime.now();
      final photo = JobPhotoModel(
        id: 'local-${widget.job.id}-${timestamp.microsecondsSinceEpoch}',
        jobId: widget.job.id,
        title: caption.isEmpty ? 'Front View' : caption,
        caption: caption,
        category: _category,
        createdAt: timestamp,
        bytes: selection.bytes,
        sourceKey: selection.sourceKey,
      );
      _store.addAll(widget.job.id, [photo]);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        _message(
          error is FormatException ? error.message : 'Unable to save photo.',
        );
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
                    Sign2DigitalPhotoPreview(
                      bytes: _selection?.bytes,
                      showDemo: _showDemo,
                      onRemove: _removePreview,
                    ),
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
                      label: 'Save Photo',
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
