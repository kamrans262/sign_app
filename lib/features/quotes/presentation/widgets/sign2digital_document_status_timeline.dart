import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/quote_document_tracking.dart';

class Sign2DigitalDocumentStatusTimeline extends StatelessWidget {
  const Sign2DigitalDocumentStatusTimeline({super.key, required this.tracking});

  final QuoteDocumentTracking tracking;

  static const _labels = [
    'Document Sent', 'Viewed by Customer', 'Waiting for Signature', 'Completed',
  ];

  static String _date(DateTime time) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final dates = [
      tracking.timeOf(QuoteDocumentEventType.documentSent),
      tracking.timeOf(QuoteDocumentEventType.documentViewed),
      tracking.timeOf(QuoteDocumentEventType.signatureRequested),
      tracking.timeOf(QuoteDocumentEventType.documentCompleted),
    ];
    final done = [tracking.sent, tracking.viewed, tracking.signed, tracking.completed];
    return Column(
      key: const Key('signature-timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _labels.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 30, child: Column(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: done[i] ? AppColors.primary : AppColors.placeholder,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(done[i] ? Icons.check : Icons.chevron_right,
                    size: 22, color: Colors.white),
                ),
                if (i < _labels.length - 1)
                  Expanded(child: Container(
                    width: 1,
                    color: done[i] && done[i + 1]
                        ? AppColors.primary : AppColors.placeholder,
                  )),
              ])),
              const SizedBox(width: 15),
              Expanded(child: Padding(
                padding: EdgeInsets.only(bottom: i == _labels.length - 1 ? 0 : 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_labels[i], style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
                    letterSpacing: -0.3, color: AppColors.dark,
                  )),
                  if (dates[i] != null) ...[
                    const SizedBox(height: 10),
                    Text(_date(dates[i]!), style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w400, color: AppColors.placeholder,
                    )),
                  ],
                ]),
              )),
            ]),
          ),
      ],
    );
  }
}
