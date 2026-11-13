import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../data/support_assistant_repository.dart';

/// Manual-only first-time guide. Does not appear on app startup.
class GettingStartedPreview extends StatefulWidget {
  const GettingStartedPreview({super.key, required this.repository,
    required this.onDestination, required this.authenticated});
  final SupportAssistantRepository repository;
  final ValueChanged<String> onDestination;
  final bool authenticated;

  @override
  State<GettingStartedPreview> createState() => _GettingStartedPreviewState();
}

class _GettingStartedPreviewState extends State<GettingStartedPreview> {
  GettingStartedProgress? _progress;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = widget.authenticated
          ? await widget.repository.progress()
          : const GettingStartedProgress(eligible: true, completed: {});
      if (mounted) setState(() => _progress = data);
    } catch (_) {
      if (mounted) setState(() =>
        _error = 'Progress is unavailable. You can still review the steps.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
        color: AppColors.primary));
    }
    if (_progress != null && !_progress!.eligible) {
      return const Padding(padding: EdgeInsets.all(20),
        child: Text('This guide is for company owners. '
          'Use AI Support to learn about your assigned modules.',
          style: TextStyle(fontFamily: 'Inter',
            color: AppColors.secondaryText)));
    }
    const stages = [
      ('company', 'Set up your company', 'companies', Icons.business_outlined),
      ('client', 'Add your first client', 'clients', Icons.people_outline),
      ('job', 'Create your first job', 'jobs', Icons.work_outline),
      ('quote', 'Prepare your first quotation', 'quotes', Icons.description_outlined),
    ];
    final count = stages.where((s) => _progress?.done(s.$1) == true).length;
    return ListView(
      key: const Key('support-guide-preview'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        const Text('Preview only · Automatic onboarding is disabled',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            fontWeight: FontWeight.w600, color: AppColors.primary)),
        const SizedBox(height: 12),
        const Text('Complete these steps using your existing Sign2Digital screens.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14,
            color: AppColors.secondaryText)),
        const SizedBox(height: 18),
        LinearProgressIndicator(value: count / 4, minHeight: 6,
          color: AppColors.primary, backgroundColor: const Color(0xFFE3ECF0)),
        const SizedBox(height: 8),
        Text('$count of 4 completed',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
            color: AppColors.secondaryText)),
        const SizedBox(height: 16),
        for (final (key, title, destination, icon) in stages)
          Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.lightBorder)),
              child: InkWell(
                key: Key('guide-step-$key'),
                onTap: () => widget.onDestination(destination),
                borderRadius: BorderRadius.circular(10),
                child: Padding(padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(_progress?.done(key) == true
                      ? Icons.check_circle_rounded : icon,
                      color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title,
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.dark))),
                    const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary),
                  ]),
                ),
              ),
            ),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: const TextStyle(fontFamily: 'Inter',
            color: Color(0xFFB42318)))),
        Sign2DigitalPrimaryButton(
          label: 'Refresh Progress', onPressed: _load),
      ],
    );
  }
}
