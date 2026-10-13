import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Shows a selected local image or a clearly non-saveable Figma demo image.
class Sign2DigitalPhotoPreview extends StatelessWidget {
  const Sign2DigitalPhotoPreview({
    super.key,
    this.bytes,
    required this.showDemo,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final bool showDemo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * 180 / 390)
            .clamp(155.0, 260.0)
            .toDouble();
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            key: const Key('add-photo-preview'),
            width: double.infinity,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bytes != null)
                  Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  )
                else if (showDemo)
                  Image.asset('assets/images/jp1.jpg', fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: const Color(0x1A8A9AA8),
                    child: Center(
                      child: Text(
                        'Take a photo or choose one from your gallery',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.placeholder,
                        ),
                      ),
                    ),
                  ),
                if (bytes != null || showDemo)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      key: const Key('add-photo-remove'),
                      tooltip: 'Remove photo preview',
                      onPressed: onRemove,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
