import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/job_photo_model.dart';
import 'sign2digital_job_photo_card.dart';

/// Full-size job gallery with swipe navigation through the currently selected
/// category (or All). Only verified, loaded job photos are shown in live mode.
class JobPhotoGalleryDialog extends StatefulWidget {
  const JobPhotoGalleryDialog({
    super.key,
    required this.photos,
    required this.initialPhotoId,
  });

  final List<JobPhotoModel> photos;
  final String initialPhotoId;

  @override
  State<JobPhotoGalleryDialog> createState() => _JobPhotoGalleryDialogState();
}

class _JobPhotoGalleryDialogState extends State<JobPhotoGalleryDialog> {
  late int _index;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.photos.indexWhere(
      (photo) => photo.id == widget.initialPhotoId,
    );
    _index = initial < 0 ? 0 : initial;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    final current = photos[_index];
    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth.clamp(0.0, 800.0).toDouble(),
          height: (MediaQuery.sizeOf(context).height * 0.73)
              .clamp(180.0, 700.0).toDouble(),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                Expanded(child: Text(
                  current.title,
                  key: const Key('job-photo-preview-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 16,
                    fontWeight: FontWeight.w600, color: AppColors.dark,
                  ),
                )),
                IconButton(
                  key: const Key('job-photo-close-preview'),
                  tooltip: 'Close photo preview',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
            Expanded(child: PageView.builder(
              key: const Key('job-photo-preview-pages'),
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => InteractiveViewer(
                // Allow horizontal swipes to reach PageView at base scale.
                // Pinch-to-zoom remains available.
                panEnabled: false,
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Sign2DigitalJobPhotoCard.picture(
                    photos[index], fit: BoxFit.contain,
                  ),
                ),
              ),
            )),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (photos.length > 1) ...[
                    Text(
                      '${_index + 1} / ${photos.length}',
                      key: const Key('job-photo-preview-counter'),
                      style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(child: Text(
                    JobPhotoModel.formattedDate(current.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 12,
                      color: AppColors.placeholder,
                    ),
                  )),
                ],
              ),
            ),
          ]),
        )),
      ),
    );
  }
}
