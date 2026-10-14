import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Table and financial summary geometry shared by Quote Preview and Invoices.
/// Values are passed in as display strings; the domain owns calculations.
class Sign2DigitalDocumentTableLine {
  const Sign2DigitalDocumentTableLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
  final String description, quantity, unitPrice, total;
}

class Sign2DigitalDocumentItemsTable extends StatelessWidget {
  const Sign2DigitalDocumentItemsTable({
    super.key,
    required this.items,
    this.onItemTap,
  });

  final List<Sign2DigitalDocumentTableLine> items;
  final ValueChanged<int>? onItemTap;

  Widget _cell(String value, {
    bool heading = false,
    bool description = false,
    bool total = false,
    TextAlign alignment = TextAlign.left,
    double size = 12,
    required bool narrow,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(
      description ? (narrow ? 8 : 20) : 4,
      heading ? 10 : 13,
      total ? (narrow ? 6 : 20) : 4,
      heading ? 10 : 13,
    ),
    child: Text(value, textAlign: alignment, softWrap: true,
      style: TextStyle(fontFamily: 'Inter',
        fontSize: narrow ? (heading ? 10 : 10) : size,
        fontWeight: FontWeight.w500,
        color: heading ? Colors.white :
            description ? AppColors.dark : AppColors.placeholder)),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final narrow = bounds.maxWidth < 360;
      return Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(3.6), 1: FlexColumnWidth(.8),
          2: FlexColumnWidth(2), 3: FlexColumnWidth(2),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFE5EBF0)),
          verticalInside: BorderSide(color: Color(0xFFE5EBF0)),
        ),
        children: [
          TableRow(decoration: const BoxDecoration(color: AppColors.primary),
            children: [
              _cell('Description', heading: true,
                description: true, narrow: narrow),
              _cell('Qty', heading: true,
                alignment: TextAlign.center, narrow: narrow),
              _cell('Unit Price', heading: true,
                alignment: TextAlign.center, narrow: narrow),
              _cell('Total', heading: true, total: true,
                alignment: TextAlign.right, narrow: narrow),
            ]),
          for (var i = 0; i < items.length; i++)
            TableRow(children: [
              _wrapTap(i, _cell(items[i].description, size: 10,
                description: true, narrow: narrow)),
              _wrapTap(i, _cell(items[i].quantity,
                alignment: TextAlign.center, narrow: narrow)),
              _wrapTap(i, _cell(items[i].unitPrice,
                alignment: TextAlign.center, narrow: narrow)),
              _wrapTap(i, _cell(items[i].total, total: true,
                alignment: TextAlign.right, narrow: narrow)),
            ]),
        ],
      );
    },
  );

  Widget _wrapTap(int index, Widget child) => onItemTap == null
      ? child
      : InkWell(onTap: () => onItemTap!(index), child: child);
}

class Sign2DigitalDocumentAmountRow extends StatelessWidget {
  const Sign2DigitalDocumentAmountRow({
    super.key, required this.label, required this.value, this.highlight = false,
  });
  final String label, value;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    color: highlight ? AppColors.primary : Colors.white,
    child: Row(children: [
      Expanded(child: Text(label,
        style: TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: highlight ? Colors.white : AppColors.placeholder))),
      const SizedBox(width: 12),
      Expanded(child: Text(value, textAlign: TextAlign.right,
        style: TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: highlight ? Colors.white : AppColors.dark))),
    ]),
  );
}
