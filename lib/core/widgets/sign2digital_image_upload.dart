// Sign2Digital — reusable, local-only image upload control.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/local_file_selection.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class Sign2DigitalImageUpload extends StatefulWidget {
  const Sign2DigitalImageUpload({super.key, this.onChanged});

  final ValueChanged<PlatformFile?>? onChanged;

  @override
  State<Sign2DigitalImageUpload> createState() =>
      _Sign2DigitalImageUploadState();
}

class _Sign2DigitalImageUploadState extends State<Sign2DigitalImageUpload> {
  PlatformFile? _file;
  String? _error;
  bool _loading = false;

  Future<void> _pick() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selected = await LocalFileSelection.choose(
        extensions: const ['png', 'jpg', 'jpeg', 'svg'],
      );
      if (!mounted || selected == null) return;
      setState(() => _file = selected);
      widget.onChanged?.call(selected);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to select this image.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _remove() {
    setState(() {
      _file = null;
      _error = null;
    });
    widget.onChanged?.call(null);
  }

  Widget _preview() {
    final data = _file?.bytes;
    if (_file == null || data == null) {
      return SvgPicture.asset(
        'assets/icons/upload-fill.svg',
        height: 24,
        width: 24,
      );
    }
    if (_file!.extension?.toLowerCase() == 'svg') {
      return SvgPicture.memory(
        data,
        width: 48,
        height: 42,
        fit: BoxFit.contain,
      );
    }
    return Image.memory(
      data,
      width: 48,
      height: 42,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Upload your logo. PNG, JPG or SVG, maximum 2 megabytes',
          child: InkWell(
            key: const Key('company-logo-upload'),
            onTap: _pick,
            borderRadius: BorderRadius.circular(10),
            child: CustomPaint(
              foregroundPainter: _DashedRoundedBorder(AppColors.lightBorder),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _preview(),
                      const SizedBox(height: 10),
                      Text(
                        _file == null ? 'Upload your logo' : _file!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.outlinedButton,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _file == null
                            ? 'PNG, JPG or SVG (max 2MB)'
                            : 'Tap to replace logo',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.footer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_file != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _remove,
              child: const Text('Remove logo'),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _DashedRoundedBorder extends CustomPainter {
  const _DashedRoundedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      );
    final brush = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final metric in border.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 10) {
        canvas.drawPath(
          metric.extractPath(
            start,
            (start + 5).clamp(0.0, metric.length).toDouble(),
          ),
          brush,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorder oldDelegate) =>
      oldDelegate.color != color;
}
