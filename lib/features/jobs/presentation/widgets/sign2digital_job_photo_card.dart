import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/job_photo_model.dart';

class Sign2DigitalJobPhotoCard extends StatelessWidget {
  const Sign2DigitalJobPhotoCard({
    super.key,
    required this.photo,
    required this.onTap,
    this.groupPhotos,
    this.groupLabel,
  });

  final JobPhotoModel photo;
  final VoidCallback onTap;
  /// An optional category collection rendered inside the existing photo card.
  final List<JobPhotoModel>? groupPhotos;
  final String? groupLabel;

  static Widget picture(JobPhotoModel photo, {BoxFit fit = BoxFit.cover}) {
    if (photo.bytes != null) {
      return Image.memory(
        photo.bytes!,
        fit: fit,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.placeholder,
          ),
        ),
      );
    }
    return Image.asset(
      photo.assetPath!,
      fit: fit,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.placeholder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limits) {
        final width = limits.maxWidth;
        final imageHeight = (width * 110 / 188).clamp(80.0, 160.0).toDouble();
        final photos = groupPhotos ?? [photo];
        final grouped = groupPhotos != null;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: Key('job-photo-card-${photo.id}'),
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(minHeight: width >= 170 ? 182 : 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lightBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    offset: Offset(0, 4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (photos.length == 1)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: SizedBox(height: imageHeight,
                        child: picture(photo)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Wrap(
                        spacing: 6, runSpacing: 6,
                        children: [
                          for (final item in photos)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: (width - 28) / 2,
                                height: ((width - 28) / 2 * 0.70)
                                    .clamp(56.0, 126.0).toDouble(),
                                child: picture(item),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          grouped ? (groupLabel ?? photo.title) : photo.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          grouped
                              ? '${photos.length} photo${photos.length == 1 ? '' : 's'} · '
                                '${JobPhotoModel.formattedDate(photo.createdAt)}'
                              : JobPhotoModel.formattedDate(photo.createdAt),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.placeholder,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
