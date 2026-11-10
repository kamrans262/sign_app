import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/job_photo_local_store.dart';
import '../../data/remote_job_media_repository.dart';
import '../../data/local_job_photo_source.dart';
import '../../domain/job_model.dart';
import '../../domain/job_photo_model.dart';
import '../widgets/sign2digital_job_info_banner.dart';
import '../widgets/sign2digital_job_photo_card.dart';
import '../widgets/job_photo_gallery_dialog.dart';
import '../../../../core/services/sign_api_client.dart';
import 'add_photos_screen.dart';

class JobPhotosScreen extends StatefulWidget {
  const JobPhotosScreen({
    super.key,
    required this.job,
    this.source,
    this.store,
    this.onTabSelected,
    this.remoteRepository,
  });

  final JobModel job;
  final JobPhotoSource? source;
  final JobPhotoLocalStore? store;
  final ValueChanged<int>? onTabSelected;
  final RemoteJobMediaRepository? remoteRepository;

  @override
  State<JobPhotosScreen> createState() => _JobPhotosScreenState();
}

class _PendingPhoto {
  _PendingPhoto(this.value);

  final LocalJobPhotoSelection value;
  JobPhotoCategory category = JobPhotoCategory.during;
  String caption = '';
}

class _JobPhotosScreenState extends State<JobPhotosScreen> {
  late final JobPhotoSource _source;
  late final JobPhotoLocalStore _store;
  final List<_PendingPhoto> _pending = [];
  late List<JobPhotoModel> _photos;
  int _selectedTab = 0;
  bool _showBanner = true;
  bool _picking = false;
  int _nextId = 0;
  bool _savingPhotos = false;

  // Persisted jobs must never silently fall back to local demo storage.
  bool get _remote => widget.store == null &&
      (int.tryParse(widget.job.id) ?? 0) > 0;

  RemoteJobMediaRepository get _remoteRepository =>
      widget.remoteRepository ?? RemoteJobMediaRepository.shared;

  Future<void> _loadRemotePhotos() async {
    if (!_remote) return;
    try {
      final records = await _remoteRepository.listPhotos(widget.job.id);
      if (mounted) setState(() => _photos = records);
    } catch (error) {
      if (mounted) _message('Unable to load saved job photos: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    _source = widget.source ?? DeviceJobPhotoSource();
    _store = widget.store ?? JobPhotoLocalStore.shared;
    _photos = _remote ? [] : _store.photosFor(widget.job.id).toList();
    if (_remote) _loadRemotePhotos();
  }

  List<JobPhotoModel> get _filteredPhotos => _selectedTab == 0
      ? _photos
      : _photos
            .where(
              (photo) =>
                  photo.category == JobPhotoCategory.values[_selectedTab - 1],
            )
            .toList();

  bool _sameBytes(Uint8List a, Uint8List b) => listEquals(a, b);

  bool _alreadySelected(LocalJobPhotoSelection value) =>
      _pending.any(
        (p) =>
            p.value.sourceKey == value.sourceKey ||
            _sameBytes(p.value.bytes, value.bytes),
      ) ||
      _photos.any(
        (photo) =>
            photo.bytes != null &&
            (photo.sourceKey == value.sourceKey ||
                _sameBytes(photo.bytes!, value.bytes)),
      );

  Future<void> _selectPhotos({required bool camera}) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final List<LocalJobPhotoSelection> picked;
      if (camera) {
        final captured = await _source.camera();
        picked = captured == null ? [] : [captured];
      } else {
        picked = await _source.upload();
      }
      if (!mounted) return;
      var added = 0;
      for (final value in picked) {
        DeviceJobPhotoSource.validate(value.name, value.bytes);
        if (_alreadySelected(value)) continue;
        _pending.add(_PendingPhoto(value));
        added++;
      }
      setState(() {});
      if (picked.isNotEmpty && added == 0) {
        _message('Those photos are already selected or added.');
      }
    } catch (error) {
      if (mounted) {
        _message(
          error is FormatException
              ? error.message
              : (camera
                    ? 'Unable to open the camera. Check camera permission.'
                    : 'Unable to select images. Please try again.'),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _commitPendingPhotos() async {
    if (_savingPhotos) return;
    if (_pending.isEmpty) {
      _message('Select photos with Upload or Camera first.');
      return;
    }
    if (_remote) {
      setState(() => _savingPhotos = true);
      try {
        for (final pending in List<_PendingPhoto>.of(_pending)) {
          final stored = await _remoteRepository.uploadPhoto(
            widget.job.id, pending.value, pending.category, pending.caption);
          if (!mounted) return;
          setState(() {
            _photos.insert(0, stored);
            _pending.remove(pending);
            _selectedTab = 0;
          });
        }
        if (mounted) {
          await _loadRemotePhotos();
          if (mounted) _message('Photos saved to the company job.');
        }
      } catch (error) {
        assert(() {
          debugPrint('M11 photo upload error type: ${error.runtimeType}; detail: $error');
          return true;
        }());
        if (mounted) _message(error is SignApiException
            ? error.message : 'Could not upload photo. Please retry.');
      } finally {
        if (mounted) setState(() => _savingPhotos = false);
      }
      return;
    }
    final time = DateTime.now();
    final records = <JobPhotoModel>[
      for (final pending in _pending)
        JobPhotoModel(
          id: 'local-${widget.job.id}-${time.microsecondsSinceEpoch}-${_nextId++}',
          jobId: widget.job.id,
          title: pending.caption.trim().isEmpty ? 'Front View' : pending.caption.trim(),
          caption: pending.caption.trim(),
          createdAt: time,
          category: pending.category,
          bytes: pending.value.bytes,
          sourceKey: pending.value.sourceKey,
        ),
    ];
    _store.addAll(widget.job.id, records);
    setState(() {
      _photos = _store.photosFor(widget.job.id).toList();
      _pending.clear();
      _selectedTab = 0;
    });
    _message(
      '${records.length} photo${records.length == 1 ? '' : 's'} added locally.',
    );
  }

  Future<void> _openAddPhotos() async {
    final staged = _pending.isEmpty ? null : _pending.first;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPhotosScreen(
          job: widget.job,
          store: _remote ? null : _store,
          source: _source,
          initialSelection: staged?.value,
          initialCategory: staged?.category ?? JobPhotoCategory.during,
          remoteRepository: widget.remoteRepository,
          onTabSelected: widget.onTabSelected,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    if (_remote) {
      if (staged != null && _pending.isNotEmpty &&
          identical(_pending.first, staged)) {
        _pending.removeAt(0);
      }
      await _loadRemotePhotos();
      if (mounted) setState(() => _selectedTab = 0);
      return;
    }
    setState(() {
      if (staged != null &&
          _pending.isNotEmpty &&
          identical(_pending.first, staged)) {
        _pending.removeAt(0);
      }
      _photos = _store.photosFor(widget.job.id).toList();
      _selectedTab = 0;
    });
  }

  void _openPhoto(JobPhotoModel photo) {
    // The preview pages only through photos visible in the selected tab.
    final gallery = List<JobPhotoModel>.unmodifiable(_filteredPhotos);
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x80000000),
      builder: (_) => JobPhotoGalleryDialog(
        photos: gallery,
        initialPhotoId: photo.id,
      ),
    );
  }

  void _selectNavigation(int index) {
    if (index == 1) return;
    // The originating Job Details route owns the navigation callback.
    Navigator.of(context).pop();
    widget.onTabSelected?.call(index);
  }

  Widget _photoGrid(double availableWidth) {
    final columns = availableWidth < 300
        ? 1
        : availableWidth < 610
        ? 2
        : (availableWidth / 205).floor().clamp(3, 5);
    const gap = 14.0;
    final itemWidth = (availableWidth - gap * (columns - 1)) / columns;
    final items = _filteredPhotos;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'No photos in this category yet.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.placeholder,
            ),
          ),
        ),
      );
    }
    return Wrap(
      spacing: gap,
      runSpacing: 20,
      children: [
        for (final photo in items)
          SizedBox(
            key: Key('photo-grid-${photo.id}'),
            width: itemWidth,
            child: Sign2DigitalJobPhotoCard(
              photo: photo,
              onTap: () => _openPhoto(photo),
            ),
          ),
      ],
    );
  }

  Widget _pendingPreviews() {
    if (_pending.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('job-photo-pending-panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1A8A9AA8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ready to add',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _pending.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _pending[i].value.bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<JobPhotoCategory>(
                    key: Key('pending-category-$i'),
                    isExpanded: true,
                    initialValue: _pending[i].category,
                    decoration: const InputDecoration(
                      labelText: 'Photo category',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final category in JobPhotoCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(switch (category) {
                            JobPhotoCategory.before => 'Before',
                            JobPhotoCategory.during => 'During',
                            JobPhotoCategory.after => 'After',
                          }),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _pending[i].category = value);
                      }
                    },
                  ),
                ),
                IconButton(
                  key: Key('remove-pending-$i'),
                  tooltip: 'Remove pending photo',
                  onPressed: () => setState(() => _pending.removeAt(i)),
                  icon: const Icon(Icons.close, color: AppColors.dark),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextFormField(
                key: Key('pending-caption-$i'),
                initialValue: _pending[i].caption,
                maxLength: 187,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => _pending[i].caption = value,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoAction({
    required String label,
    required String iconAsset,
    required VoidCallback onTap,
    required Key key,
  }) => OutlinedButton(
    key: key,
    onPressed: _picking ? null : onTap,
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: AppColors.primary),
      foregroundColor: AppColors.primary,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size(0, 48),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(iconAsset, width: 21, height: 21),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: 'Job Photos',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('job-photos-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showBanner) ...[
                          Sign2DigitalJobInfoBanner(
                            title: widget.job.title,
                            description: widget.job.description,
                            onDismiss: () =>
                                setState(() => _showBanner = false),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Job Photos',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Document your project with photos',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Sign2DigitalDetailsTabs(
                          labels: const ['All', 'Before', 'During', 'After'],
                          selectedIndex: _selectedTab,
                          onSelected: (value) =>
                              setState(() => _selectedTab = value),
                        ),
                        const SizedBox(height: 20),
                        _photoGrid(constraints.maxWidth),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: _photoAction(
                                label: 'Upload',
                                iconAsset:
                                    'assets/icons/cloud-upload-outlined.svg',
                                onTap: () => _selectPhotos(camera: false),
                                key: const Key('job-photos-upload'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _photoAction(
                                label: 'Camera',
                                iconAsset: 'assets/icons/camera-outlined.svg',
                                onTap: () => _selectPhotos(camera: true),
                                key: const Key('job-photos-camera'),
                              ),
                            ),
                          ],
                        ),
                        if (_pending.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _pendingPreviews(),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('job-photos-confirm-pending'),
                              onPressed: _commitPendingPhotos,
                              child: const Text('Confirm selected photos'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Sign2DigitalPrimaryButton(
                          key: const Key('job-photos-add-button'),
                          label: '＋ Add Photos',
                          onPressed: _openAddPhotos,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: 1,
        onSelected: _selectNavigation,
      ),
    );
  }
}
