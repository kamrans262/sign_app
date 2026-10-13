import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/document_record.dart';

/// Shared borderless tracking row. The Document History and Work Acceptance
/// flows use the same 30px icon / 12px gap / 16px heading rhythm.
class Sign2DigitalTrackingRow extends StatelessWidget {
  const Sign2DigitalTrackingRow({
    super.key,
    required this.title,
    this.dateText,
    this.actorText,
    this.completed = false,
  });

  final String title;
  final String? dateText;
  final String? actorText;
  final bool completed;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        key: const Key('work-acceptance-stage-icon'),
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: completed ? AppColors.primary : const Color(0xFFE3ECF0),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          completed ? Icons.check_rounded : Icons.schedule_rounded,
          size: 20,
          color: completed ? Colors.white : AppColors.secondaryText,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
            letterSpacing: -0.3, color: AppColors.dark,
          )),
          const SizedBox(height: 5),
          Text(dateText ?? 'Pending', style: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
            color: AppColors.placeholder,
          )),
          if (actorText != null && actorText!.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(actorText!, softWrap: true, style: const TextStyle(
              fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400,
              color: AppColors.placeholder,
            )),
          ],
        ],
      )),
    ],
  );
}

/// Borderless events under the existing Document Details History tab.
class Sign2DigitalDocumentHistory extends StatefulWidget {
  const Sign2DigitalDocumentHistory({
    super.key, required this.document, this.onViewSignatures,
  });

  final DocumentRecord document;
  final ValueChanged<DocumentHistoryEvent>? onViewSignatures;

  @override
  State<Sign2DigitalDocumentHistory> createState() =>
      _Sign2DigitalDocumentHistoryState();
}

class _Sign2DigitalDocumentHistoryState
    extends State<Sign2DigitalDocumentHistory> {
  String? _selectedId;

  List<DocumentHistoryEvent> get _events => widget.document.history
      .where((event) => event.documentId == widget.document.id)
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  IconData _icon(DocumentHistoryType type) => switch (type) {
    DocumentHistoryType.signed || DocumentHistoryType.sent =>
      Icons.check_rounded,
    DocumentHistoryType.viewed => Icons.visibility_outlined,
    DocumentHistoryType.emailOpened => Icons.chat_bubble_outline_rounded,
    DocumentHistoryType.created => Icons.description_outlined,
  };

  String _timestamp(DateTime input) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final date = input.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${weekdays[date.weekday - 1]}, ${date.day} '
        '${months[date.month - 1]} ${date.year}, '
        '$hour:${date.minute.toString().padLeft(2, '0')} '
        "${date.hour >= 12 ? 'PM' : 'AM'}";
  }

  void _showSignatures(DocumentHistoryEvent event) {
    if (widget.document.demoOnly) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('UI demo: no verified signature record is available.'),
      ));
    } else if (event.signatureReference == null ||
        widget.onViewSignatures == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Verified signature details are not available yet.'),
      ));
    } else {
      widget.onViewSignatures!(event);
    }
  }

  Widget _event(DocumentHistoryEvent event, bool expanded) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: InkWell(
      key: Key('document-history-event-${event.id}'),
      onTap: () => setState(() => _selectedId = event.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFE3ECF0), shape: BoxShape.circle,
            ),
            child: Icon(_icon(event.type), color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title, style: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w600,
                fontSize: 16, letterSpacing: -0.3, color: AppColors.dark,
              )),
              const SizedBox(height: 5),
              Text(_timestamp(event.occurredAt),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                  fontWeight: FontWeight.w500, color: AppColors.placeholder)),
              if ((event.description ?? '').trim().isNotEmpty ||
                  (event.actorEmail ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text([
                  if ((event.description ?? '').trim().isNotEmpty)
                    event.description!.trim(),
                  if ((event.actorEmail ?? '').trim().isNotEmpty)
                    event.actorEmail!.trim(),
                ].join('\n'),
                  softWrap: true,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.placeholder)),
              ],
              if (expanded && event.type == DocumentHistoryType.signed) ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: 148,
                  child: Sign2DigitalPrimaryButton(
                    key: const Key('document-view-signatures'),
                    label: 'View Signatures',
                    height: 36,
                    onPressed: () => _showSignatures(event),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final events = _events;
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No recorded document history is available.',
          key: Key('document-history-empty'),
          style: TextStyle(fontFamily: 'Inter',
            color: AppColors.placeholder, fontSize: 14)),
      );
    }
    final selected = _selectedId ??
        events.firstWhere(
          (e) => e.type == DocumentHistoryType.signed,
          orElse: () => events.first,
        ).id;
    return Column(
      key: const Key('document-history'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.document.demoOnly)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('FIGMA UI DEMO — sample events, not verified audit data.',
              key: Key('document-history-demo-notice'),
              style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                color: AppColors.primary)),
          ),
        for (final event in events) _event(event, selected == event.id),
        const Sign2DigitalInfoBanner(
          title: 'Audit Information',
          message: 'Document history displays available recorded events. '
              'Only a connected verified audit service can establish '
              'record integrity and immutability.',
          iconAsset: 'assets/icons_2/pdf.svg',
          verticalPadding: 15,
          iconGap: 10,
          iconSize: 24,
          fontSize: 13,
          textColor: AppColors.placeholder,
        ),
      ],
    );
  }
}
