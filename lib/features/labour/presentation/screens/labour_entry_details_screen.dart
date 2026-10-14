import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../domain/labour_entry.dart';

/// Read-only details for the exact selected worker/time entry ID.
class LabourEntryDetailsScreen extends StatelessWidget {
  const LabourEntryDetailsScreen({super.key, required this.entry});

  final LabourEntry entry;

  static String date(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(
        title: entry.kind == LabourEntryKind.labour
            ? 'Labour Details' : 'Time Sheet Details',
        onBack: () => Navigator.of(context).pop(),
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('labour-detail-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            Text(entry.workerName, style: const TextStyle(
              fontFamily: 'Inter', fontSize: 22,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 8),
            Text(entry.jobName, style: const TextStyle(
              fontFamily: 'Inter', fontSize: 14,
              color: AppColors.placeholder)),
            const SizedBox(height: 20),
            Sign2DigitalInformationTable(
              key: const Key('labour-detail-table'),
              rows: [
                Sign2DigitalInformationRow('Worker', entry.workerName),
                Sign2DigitalInformationRow('Role', entry.role),
                Sign2DigitalInformationRow('Job', entry.jobName),
                Sign2DigitalInformationRow('Date', date(entry.date)),
                Sign2DigitalInformationRow('Hours', entry.formattedHours),
                if (entry.task.isNotEmpty)
                  Sign2DigitalInformationRow('Task', entry.task),
                Sign2DigitalInformationRow('Status', entry.statusLabel,
                  isStatus: true),
              ],
            ),
            if (entry.isDemo) ...[
              const SizedBox(height: 14),
              const Text('Demo time entry — no approval has been submitted.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                  color: AppColors.primary)),
            ],
          ],
        ),
      ))),
    ])),
  );
}
