import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/job_photo_model.dart';

class Sign2DigitalJobPhotoCard extends StatelessWidget {
  const Sign2DigitalJobPhotoCard({
    super.key,
    required this.photo,
    required this.onTap,
  });

  final JobPhotoModel photo;
  final VoidCallback onTap;

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
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: SizedBox(height: imageHeight, child: picture(photo)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          photo.title,
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
                          JobPhotoModel.formattedDate(photo.createdAt),
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
