import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/expense_record.dart';

/// The category icon is shared by expense list and detail summaries.
class Sign2DigitalExpenseCategoryIcon extends StatelessWidget {
  const Sign2DigitalExpenseCategoryIcon({
    super.key, required this.category, this.detailStyle = false,
  });
  final ExpenseCategory category;
  final bool detailStyle;

  static IconData iconFor(ExpenseCategory category) => switch (category) {
    ExpenseCategory.fuel => Icons.local_gas_station_outlined,
    ExpenseCategory.tools => Icons.build_outlined,
    ExpenseCategory.parking => Icons.local_parking_outlined,
    ExpenseCategory.meals => Icons.restaurant_outlined,
    ExpenseCategory.other => Icons.receipt_long_outlined,
    ExpenseCategory.material => Icons.inventory_2_outlined,
    ExpenseCategory.labour => Icons.engineering_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: detailStyle ? AppColors.white : const Color(0xFFE3ECF0),
      shape: BoxShape.circle,
      boxShadow: detailStyle
          ? const [BoxShadow(color: Color(0x14000000),
              offset: Offset(0, 4), blurRadius: 8)]
          : null,
    ),
    alignment: Alignment.center,
    child: Icon(iconFor(category), color: AppColors.primary, size: 25),
  );
}
