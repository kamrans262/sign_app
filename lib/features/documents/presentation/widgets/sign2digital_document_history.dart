import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
    this.historyStyle = false,
    this.historyIcon,
  });

  final String title;
  final String? dateText;
  final String? actorText;
  final bool completed;
  final bool historyStyle;
  final IconData? historyIcon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        key: const Key('work-acceptance-stage-icon'),
        width: historyStyle ? 40 : 30, height: historyStyle ? 40 : 30,
        decoration: BoxDecoration(
          color: historyStyle ? const Color(0xFFE3ECF0)
              : completed ? AppColors.primary : const Color(0xFFE3ECF0),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          historyIcon ?? (completed ? Icons.check_rounded : Icons.schedule_rounded),
          size: historyStyle ? 23 : 20,
          color: historyStyle ? AppColors.primary :
              completed ? Colors.white : AppColors.secondaryText,
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
    this.onOpenDocument,
    this.canPreview = false,
    this.additionalEvents = const [],
  });

  final DocumentRecord document;
  /// Events completed while this details page remains open.
  final List<DocumentHistoryEvent> additionalEvents;
  final ValueChanged<DocumentHistoryEvent>? onViewSignatures;
  /// Opens the already-loaded document at the requested details (0) or
  /// preview (1) tab, without constructing an unrelated document screen.
  final ValueChanged<int>? onOpenDocument;
  final bool canPreview;

  @override
  State<Sign2DigitalDocumentHistory> createState() =>
      _Sign2DigitalDocumentHistoryState();
}

class _Sign2DigitalDocumentHistoryState
    extends State<Sign2DigitalDocumentHistory> {
  String? _selectedId;

  List<DocumentHistoryEvent> get _events => [
        ...widget.document.history,
        ...widget.additionalEvents,
      ].where((event) => event.documentId == widget.document.id)
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  IconData _icon(DocumentHistoryType type) => switch (type) {
    DocumentHistoryType.signed || DocumentHistoryType.sent =>
      Icons.check_rounded,
    DocumentHistoryType.viewed => Icons.visibility_outlined,
    DocumentHistoryType.emailOpened => Icons.chat_bubble_outline_rounded,
    DocumentHistoryType.created => Icons.description_outlined,
    DocumentHistoryType.edited => Icons.edit_outlined,
    DocumentHistoryType.downloaded => Icons.download_outlined,
    DocumentHistoryType.versionChanged => Icons.history_outlined,
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

  bool _opensPreview(DocumentHistoryType type) => switch (type) {
    DocumentHistoryType.sent ||
    DocumentHistoryType.viewed ||
    DocumentHistoryType.emailOpened ||
    DocumentHistoryType.downloaded => widget.canPreview,
    _ => false,
  };

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
              if (expanded &&
                  (event.type == DocumentHistoryType.signed ||
                      widget.onOpenDocument != null)) ...[
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: SizedBox(
                      width: double.infinity,
                      child: Sign2DigitalPrimaryButton(
                        key: event.type == DocumentHistoryType.signed
                            ? const Key('document-view-signatures')
                            : Key('document-history-action-${event.id}'),
                        label: event.type == DocumentHistoryType.signed
                            ? 'View Signatures'
                            : _opensPreview(event.type)
                                ? 'View Document'
                                : 'View Details',
                        height: 48,
                        onPressed: event.type == DocumentHistoryType.signed
                            ? () => _showSignatures(event)
                            : () => widget.onOpenDocument!(
                                  _opensPreview(event.type) ? 1 : 0),
                      ),
                    ),
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
        for (final event in events) _event(event, selected == event.id),
      ],
    );
  }
}
