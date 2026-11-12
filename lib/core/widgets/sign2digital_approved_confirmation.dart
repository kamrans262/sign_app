import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'sign2digital_modal_surface.dart';
import 'sign2digital_outlined_button.dart';
import 'sign2digital_primary_button.dart';

/// Drop-in visual adapter for legacy confirmation/decision AlertDialogs.
///
/// Keep existing callbacks, result types, widget keys, text inputs and consent
/// controls intact. Only the confirmation's presentation is standardized.
/// Editing forms and image previews should not use this widget.
class Sign2DigitalApprovedConfirmation extends StatelessWidget {
  const Sign2DigitalApprovedConfirmation({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    // Accepted for compatibility with legacy AlertDialog call sites.
    this.backgroundColor,
    this.shape,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  static String _titleText(Widget title) {
    if (title is Text) {
      return title.data ?? title.textSpan?.toPlainText() ?? '';
    }
    return '';
  }

  IconData _effectiveIcon() {
    if (icon != null) return icon!;
    final value = _titleText(title).toLowerCase();
    if (value.contains('delete') || value.contains('remove') ||
        value.contains('discard') || value.contains('void') ||
        value.contains('revoke') || value.contains('deactivate')) {
      return Icons.delete_outline_rounded;
    }
    if (value.contains('cancel')) return Icons.cancel_outlined;
    if (value.contains('email') || value.contains('send') ||
        value.contains('invitation')) return Icons.mail_outline_rounded;
    if (value.contains('subscription') || value.contains('plan')) {
      return Icons.workspace_premium_outlined;
    }
    if (value.contains('reminder')) return Icons.notifications_outlined;
    if (value.contains('date') || value.contains('returned') ||
        value.contains('extension')) return Icons.event_available_outlined;
    if (value.contains('equipment') || value.contains('loan')) {
      return Icons.handyman_outlined;
    }
    if (value.contains('document') || value.contains('report') ||
        value.contains('draft') || value.contains('pdf')) {
      return Icons.description_outlined;
    }
    return Icons.fact_check_outlined;
  }

  Widget _action(Widget source, {required bool primary}) {
    if (source is TextButton) {
      final child = source.child;
      final label = child is Text
          ? (child.data ?? child.textSpan?.toPlainText())
          : null;
      if (label != null) {
        if (primary) {
          return Sign2DigitalPrimaryButton(
            key: source.key,
            label: label,
            compactLabel: true,
            enabled: source.onPressed != null,
            onPressed: source.onPressed ?? () {},
          );
        }
        return Sign2DigitalOutlinedButton(
          key: source.key,
          label: label,
          primaryOutline: true,
          enabled: source.onPressed != null,
          onPressed: source.onPressed ?? () {},
        );
      }
    }
    // Preserve actions with non-text children or specialized behaviors.
    return source;
  }

  @override
  Widget build(BuildContext context) {
    return Sign2DigitalModalSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFE3ECF0),
            child: Icon(_effectiveIcon(), size: 26, color: AppColors.primary),
          ),
          const SizedBox(height: 15),
          DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 18,
              fontWeight: FontWeight.w600, color: AppColors.dark,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            child: title,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.49,
            ),
            child: SingleChildScrollView(
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 14,
                  fontWeight: FontWeight.w500, color: AppColors.placeholder,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
                child: content,
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            if (actions.length == 2)
              Row(children: [
                Expanded(child: _action(actions.first, primary: false)),
                const SizedBox(width: 15),
                Expanded(child: _action(actions.last, primary: true)),
              ])
            else
              Column(
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _action(actions[index],
                        primary: index == actions.length - 1),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}
