import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../../core/services/active_company_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../widgets/sign2digital_photo_source_card.dart';
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
  bool _galleryOpen = false;
  bool _deletingPhoto = false;

  // Persisted jobs must never silently fall back to local demo storage.
  bool get _remote => widget.store == null &&
      (int.tryParse(widget.job.id) ?? 0) > 0;

  RemoteJobMediaRepository get _remoteRepository =>
      widget.remoteRepository ?? RemoteJobMediaRepository.shared;

  Future<void> _loadRemotePhotos() async {
    if (!_remote) return;
    try {
      final records = await _remoteRepository.listPhotos(widget.job.id);
      // Repository snapshots are immutable; keep mutable screen state for
      // optimistic inserts while preserving the verified server records.
      if (mounted) setState(() => _photos = List<JobPhotoModel>.of(records));
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

  bool _alreadySelected(LocalJobPhotoSelection value) {
    // Different files picked by the user must remain separate photos, even
    // when their bytes happen to match (for example, two exported logos).
    // Use content matching only when the picker lacks a unique source key.
    bool matches(String? sourceKey, Uint8List? bytes) =>
        value.sourceKey.isNotEmpty && sourceKey != null && sourceKey.isNotEmpty
            ? sourceKey == value.sourceKey
            : bytes != null && _sameBytes(bytes, value.bytes);
    return _pending.any((item) =>
        matches(item.value.sourceKey, item.value.bytes)) ||
        _photos.any((item) => matches(item.sourceKey, item.bytes));
  }

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
        _pending.add(_PendingPhoto(value)
          ..category = _selectedTab == 0
              ? JobPhotoCategory.during
              : JobPhotoCategory.values[_selectedTab - 1]);
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

  Future<bool> _deletePhoto(JobPhotoModel photo) async {
    if (_deletingPhoto) return false;
    final chosen = await Sign2DigitalSelectionSheet.show(
      context, title: 'Delete Job Photo',
      subtitle: 'Remove this photo from the job? Other photos in the category remain.',
      icon: Icons.delete_outline,
      options: const ['Cancel', 'Delete Photo'],
    );
    if (!mounted || chosen != 'Delete Photo') return false;
    _deletingPhoto = true;
    try {
      if (_remote) {
        await _remoteRepository.deletePhoto(photo);
        if (!mounted) return false;
        await _loadRemotePhotos();
      } else {
        _store.remove(widget.job.id, photo.id);
        if (mounted) setState(() => _photos = _store.photosFor(widget.job.id).toList());
      }
      if (!mounted) return false;
      _message('Photo deleted from this job.');
      return true;
    } catch (error) {
      if (mounted) _message(error is SignApiException
          ? error.message : 'Unable to delete photo. Please retry.');
      return false;
    } finally {
      _deletingPhoto = false;
    }
  }

  Future<void> _openPhoto(JobPhotoModel photo, List<JobPhotoModel> group) async {
    if (_galleryOpen || group.isEmpty) return;
    _galleryOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierColor: const Color(0x80000000),
        builder: (_) => JobPhotoGalleryDialog(
          photos: List<JobPhotoModel>.unmodifiable(group),
          initialPhotoId: photo.id,
          onDelete: ActiveCompanySession.canWrite('jobs') ? _deletePhoto : null,
        ),
      );
    } finally {
      _galleryOpen = false;
    }
  }

  void _selectNavigation(int index) {
    if (index == 1) return;
    // The originating Job Details route owns the navigation callback.
    Navigator.of(context).pop();
    widget.onTabSelected?.call(index);
  }

  Widget _photoGrid(double availableWidth) {
    final columns = availableWidth < 300
        ? 1 : availableWidth < 610
        ? 2 : (availableWidth / 205).floor().clamp(3, 5);
    const gap = 14.0;
    final itemWidth = (availableWidth - gap * (columns - 1)) / columns;
    final visible = _filteredPhotos;
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text('No photos in this category yet.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder))),
      );
    }
    // One cover per category, retaining the full photo collection behind
    // the card. Tapping opens the approved viewer with swipe pagination.
    final grouped = <JobPhotoCategory, List<JobPhotoModel>>{};
    for (final photo in visible) {
      grouped.putIfAbsent(photo.category, () => []).add(photo);
    }
    return Wrap(
      spacing: gap, runSpacing: 20,
      children: [
        for (final category in JobPhotoCategory.values)
          if (grouped.containsKey(category))
            Builder(builder: (context) {
              final photos = grouped[category]!.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final cover = photos.first;
              return SizedBox(
                key: Key('photo-grid-${cover.id}'),
                width: itemWidth,
                child: Sign2DigitalJobPhotoCard(
                  photo: cover,
                  groupPhotos: photos,
                  groupLabel: switch (category) {
                    JobPhotoCategory.before => 'Before Job',
                    JobPhotoCategory.during => 'During Job',
                    JobPhotoCategory.after => 'After Job',
                  },
                  onTap: () => _openPhoto(cover, photos),
                ),
              );
            }),
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

  /// Reuse the existing source containers immediately above Add Photos.
  Widget _photoSourceChoices() {
    if (!ActiveCompanySession.canWrite('jobs')) {
      return const SizedBox.shrink();
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Sign2DigitalPhotoSourceCard(
            key: const Key('job-photos-upload'),
            title: 'Upload',
            description: 'Choose existing photos',
            iconAsset: 'assets/icons/cloud-upload-outlined.svg',
            enabled: !_picking && !_savingPhotos,
            onTap: () => _selectPhotos(camera: false),
          )),
          const SizedBox(width: 16),
          Expanded(child: Sign2DigitalPhotoSourceCard(
            key: const Key('job-photos-camera'),
            title: 'Camera',
            description: 'Take a photo',
            iconAsset: 'assets/icons/camera-outlined.svg',
            enabled: !_picking && !_savingPhotos,
            onTap: () => _selectPhotos(camera: true),
          )),
        ],
      ),
    );
  }

  /// Add Photos is the sole confirmation/save action. No second
  /// "Confirm selected photos" control is presented.
  Widget _bottomPhotoActions() {
    if (!ActiveCompanySession.canWrite('jobs')) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false, bottom: false,
      child: Padding(
        key: const Key('job-photos-bottom-actions'),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _photoSourceChoices(),
            const SizedBox(height: 12),
            Sign2DigitalPrimaryButton(
              key: const Key('job-photos-add-button'),
              label: '＋ Add Photos',
              loading: _savingPhotos,
              enabled: !_picking,
              onPressed: _commitPendingPhotos,
            ),
          ],
        ),
      ),
    );
  }

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
                        const SizedBox(height: 20),
                        if (ActiveCompanySession.canWrite('jobs') &&
                            _pending.isNotEmpty) _pendingPreviews(),
                      ],
                    );
                  },
                ),
              ),
            ),
            _bottomPhotoActions(),
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
