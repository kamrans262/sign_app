import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/quote_document_tracking.dart';

/// Optional document-preparation stages using the same signing timeline shell.
class DocumentPreparationStep {
  const DocumentPreparationStep({
    required this.title, required this.description,
    this.completed = false, this.active = false, this.failed = false,
  });

  final String title;
  final String description;
  final bool completed;
  final bool active;
  final bool failed;
}

class Sign2DigitalDocumentStatusTimeline extends StatelessWidget {
  const Sign2DigitalDocumentStatusTimeline({
    super.key, this.tracking, this.preparationSteps,
  });

  final QuoteDocumentTracking? tracking;
  final List<DocumentPreparationStep>? preparationSteps;

  Widget _preparation() {
    final steps = preparationSteps!;
    const green = Color(0xFF008737);
    return Column(
      key: const Key('document-preparation-timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 24, child: Column(children: [
                Container(
                  key: Key('document-preparation-step-$i'),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: steps[i].completed ? green : Colors.white,
                    border: Border.all(
                      color: steps[i].failed ? const Color(0xFFB42318)
                        : steps[i].completed ? green : AppColors.placeholder,
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: steps[i].completed
                    ? const Icon(Icons.check, size: 17, color: Colors.white)
                    : steps[i].failed
                      ? const Icon(Icons.close, size: 16, color: Color(0xFFB42318))
                      : steps[i].active
                        ? const Icon(Icons.circle, size: 10, color: AppColors.primary)
                        : null,
                ),
                if (i < steps.length - 1)
                  Expanded(child: Container(
                    width: 1,
                    color: steps[i].completed ? green : AppColors.placeholder,
                  )),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Padding(
                padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(steps[i].title, style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 16,
                      fontWeight: FontWeight.w600, letterSpacing: -0.3,
                      color: AppColors.dark,
                    )),
                    const SizedBox(height: 5),
                    Text(steps[i].description, style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w400, color: AppColors.placeholder,
                    )),
                  ],
                ),
              )),
            ],
          )),
      ],
    );
  }

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
    if (preparationSteps != null) return _preparation();
    final currentTracking = tracking!;
    final dates = [
      currentTracking.timeOf(QuoteDocumentEventType.documentSent),
      currentTracking.timeOf(QuoteDocumentEventType.documentViewed),
      currentTracking.timeOf(QuoteDocumentEventType.signatureRequested),
      currentTracking.timeOf(QuoteDocumentEventType.documentCompleted),
    ];
    final done = [currentTracking.sent, currentTracking.viewed, currentTracking.signed, currentTracking.completed];
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
