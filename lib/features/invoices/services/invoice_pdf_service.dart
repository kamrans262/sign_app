import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../quotes/domain/quote_review_models.dart';
import '../domain/invoice_record.dart';

/// Invoice-specific document backed by the same PDF package as Quote PDF.
/// Never prints Figma placeholder amounts as if they were confirmed records.
class Sign2DigitalInvoicePdfBuilder {
  const Sign2DigitalInvoicePdfBuilder();

  Future<Uint8List> build(InvoiceRecord invoice) async {
    final pdf = pw.Document();
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/header_logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List(
        data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      // The invoice remains exportable without an optional logo image.
    }
    final blue = PdfColor.fromHex('#166282');
    final dark = PdfColor.fromHex('#122536');
    final grey = PdfColor.fromHex('#8A9AA8');
    pw.TextStyle style(double size, {bool bold = false, PdfColor? color}) =>
        pw.TextStyle(fontSize: size, color: color ?? dark,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    String date(DateTime? d) => d == null ? 'Not recorded'
        : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    String money(int? minor) => quoteMoney(minor, invoice.currency);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      build: (context) => [
        if (invoice.demoOnly) pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: PdfColor.fromHex('#EEF2F5'),
          child: pw.Text('LOCAL DEMONSTRATION INVOICE - NOT A VERIFIED DELIVERY',
            style: style(9, bold: true))),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logo != null) pw.Image(logo, width: 130, height: 44),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Invoice', style: style(22, bold: true)),
                pw.Text(invoice.number, style: style(11, color: grey)),
              ]),
          ]),
        pw.SizedBox(height: 28),
        pw.Text('Bill To: ${invoice.clientName}', style: style(12, bold: true)),
        pw.SizedBox(height: 8),
        pw.Text('Project: ${invoice.project}', style: style(11)),
        pw.Text('Issue date: ${date(invoice.date)}', style: style(11)),
        pw.Text('Due date: ${date(invoice.dueDate)}', style: style(11)),
        pw.Text('Status: ${invoice.status.label}', style: style(11)),
        if (invoice.iban.trim().isNotEmpty)
          pw.Text('IBAN: ${invoice.iban}', style: style(11)),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: const ['Description', 'Qty', 'Unit Price', 'Total'],
          data: invoice.items.isEmpty
              ? [['No itemized lines recorded', '-', '-', '-']]
              : invoice.items.map((item) => [
                  item.description, '${item.quantity}',
                  money(item.unitPriceMinor), money(item.totalMinor),
                ]).toList(),
          headerDecoration: pw.BoxDecoration(color: blue),
          headerStyle: style(10, color: PdfColors.white, bold: true),
          cellStyle: style(10),
          cellPadding: const pw.EdgeInsets.all(7),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2.2),
            3: const pw.FlexColumnWidth(2.2),
          },
        ),
        pw.SizedBox(height: 14),
        for (final entry in <(String, String)>[
          ('Subtotal', money(invoice.subtotalMinor)),
          ('VAT (${(invoice.vatBasisPoints / 100).toStringAsFixed(2)}%)',
            money(invoice.vatMinor)),
          ('Total', invoice.formattedAmount),
          ('Deposit paid', money(invoice.depositPaidMinor)),
          ('Received via recorded payments',
            money(invoice.payments.isEmpty ? null : invoice.receivedMinor)),
          ('Amount due', money(invoice.amountDueMinor)),
        ]) pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(width: 180,
                child: pw.Text(entry.$1, style: style(10, color: grey))),
              pw.SizedBox(width: 110,
                child: pw.Text(entry.$2, textAlign: pw.TextAlign.right,
                  style: style(10, bold: entry.$1 == 'Total'))),
            ]),
        ),
        if (invoice.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('Notes', style: style(12, bold: true)),
          pw.Text(invoice.notes, style: style(11)),
        ],
      ],
    ));
    return pdf.save();
  }
}
