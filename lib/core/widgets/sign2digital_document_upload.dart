// Sign2Digital — reusable local-only PDF upload control.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/local_file_selection.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'sign2digital_outlined_container.dart';

class Sign2DigitalDocumentUpload extends StatefulWidget {
  const Sign2DigitalDocumentUpload({super.key, this.onChanged});
  final ValueChanged<PlatformFile?>? onChanged;

  @override
  State<Sign2DigitalDocumentUpload> createState() =>
      _Sign2DigitalDocumentUploadState();
}

class _Sign2DigitalDocumentUploadState
    extends State<Sign2DigitalDocumentUpload> {
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
      final result = await LocalFileSelection.choose(extensions: const ['pdf']);
      if (!mounted || result == null) return;
      setState(() => _file = result);
      widget.onChanged?.call(result);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to select this PDF.');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Upload your general terms, PDF up to 2 megabytes',
          child: InkWell(
            key: const Key('terms-pdf-upload'),
            onTap: _pick,
            borderRadius: BorderRadius.circular(10),
            child: Sign2DigitalOutlinedContainer(
              constraints: const BoxConstraints(minHeight: 59),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/terms_and_conditions.svg',
                    width: 22,
                    height: 24,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _file?.name ?? 'Upload your general terms',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.fieldInput,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _file == null
                              ? 'PDF (max 2MB)'
                              : 'Tap to replace PDF',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.secondaryText,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_file != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _remove,
              child: const Text('Remove PDF'),
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
