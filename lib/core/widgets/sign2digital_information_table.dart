import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'sign2digital_outlined_container.dart';
import '../../features/clients/presentation/widgets/sign2digital_status_badge.dart';

/// Shared information table for Document Details and Expense Details.
/// Each value begins at the same responsive column position.
class Sign2DigitalInformationTable extends StatelessWidget {
  const Sign2DigitalInformationTable({
    super.key,
    required this.rows,
    this.heading,
  });

  final String? heading;
  final List<Sign2DigitalInformationRow> rows;

  static const _label = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, color: AppColors.placeholder,
  );
  static const _value = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, color: AppColors.dark,
  );

  Widget _row(Sign2DigitalInformationRow entry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
    child: LayoutBuilder(builder: (context, constraints) {
      final labelWidth = (constraints.maxWidth * .43)
          .clamp(100.0, 180.0).toDouble();
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: labelWidth, child: Text(
          entry.label, softWrap: true, style: _label)),
        const SizedBox(width: 10),
        Expanded(child: Align(
          alignment: Alignment.centerLeft,
          child: entry.isStatus
              ? Sign2DigitalStatusBadge(status: entry.value)
              : Text(entry.value, softWrap: true, style: _value),
        )),
      ]);
    }),
  );

  @override
  Widget build(BuildContext context) => Sign2DigitalOutlinedContainer(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(heading!, style: const TextStyle(
                fontFamily: 'Inter', fontSize: 20,
                fontWeight: FontWeight.w600, color: AppColors.dark,
              )),
            ),
            const SizedBox(height: 20),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            _row(rows[i]),
            if (i < rows.length - 1)
              const Divider(height: 1, thickness: 1,
                color: AppColors.lightBorder),
          ],
        ],
      ),
    ),
  );
}

class Sign2DigitalInformationRow {
  const Sign2DigitalInformationRow(
    this.label, this.value, {this.isStatus = false});

  final String label;
  final String value;
  final bool isStatus;
}
