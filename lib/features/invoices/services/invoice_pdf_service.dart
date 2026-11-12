import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../quotes/domain/quote_review_models.dart';
import '../domain/invoice_record.dart';

/// Invoice-specific document backed by the same PDF package as Quote PDF.
/// Never prints Figma placeholder amounts as if they were confirmed records.
class Sign2DigitalInvoicePdfBuilder {
  const Sign2DigitalInvoicePdfBuilder();

  Future<Uint8List> build(InvoiceRecord invoice) async {
    // Reuse Quote PDF's bundled Inter font so CHF values and Unicode
    // placeholders are rendered rather than lost in Helvetica fallback.
    pw.Font? inter;
    try {
      inter = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
      );
    } catch (_) {
      // Keep the PDF usable if the bundled font cannot be read.
    }
    final pdf = pw.Document(
      version: PdfVersion.pdf_1_4,
      theme: inter == null
          ? null
          : pw.ThemeData.withFont(base: inter, bold: inter),
    );
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
    final rule = PdfColor.fromHex('#E4EAF0');
    pw.TextStyle style(double size, {bool bold = false, PdfColor? color}) =>
        pw.TextStyle(fontSize: size, color: color ?? dark,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    String date(DateTime? d) => d == null ? 'Not recorded'
        : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    String money(int? minor) => quoteMoney(minor, invoice.currency);

    final payment = invoice.payment ??
      (invoice.iban.trim().isNotEmpty
        ? QuotePaymentDetails(iban: invoice.iban) : null);
    final qrPayload = invoice.demoOnly ? null :
      payment?.swissQrBillPayload(
        currency: invoice.currency, amountMinor: invoice.amountDueMinor);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      build: (context) => [
        if (invoice.demoOnly) pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: PdfColor.fromHex('#EEF2F5'),
          child: pw.Text('LOCAL DEMONSTRATION INVOICE - NOT A VERIFIED DELIVERY',
            style: style(9, bold: true))),
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: rule, width: .7),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null)
                    pw.Image(logo, width: 132, height: 43, fit: pw.BoxFit.contain)
                  else
                    pw.Text('Sign2Digital', style: style(18, bold: true)),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice', style: style(18, bold: true)),
                      pw.SizedBox(height: 6),
                      pw.Text(invoice.number, style: style(12, color: grey)),
                    ]),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill To:', style: style(14, bold: true)),
                      pw.SizedBox(height: 8),
                      for (final text in [
                        invoice.clientName, invoice.billingAddress,
                        invoice.clientEmail, invoice.clientPhone,
                      ]) if (text.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Text(text, style: style(11, color: grey))),
                    ],
                  )),
                  pw.SizedBox(width: 12),
                  pw.SizedBox(width: 156, child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in <(String, String)>[
                        ('Date:', date(invoice.date)),
                        ('Due Date:', date(invoice.dueDate)),
                      ]) ...[
                        pw.Row(children: [
                          pw.SizedBox(width: 72, child: pw.Text(entry.$1,
                            textAlign: pw.TextAlign.right,
                            style: style(11, bold: true))),
                          pw.SizedBox(width: 6),
                          pw.Expanded(child: pw.Text(entry.$2,
                            textAlign: pw.TextAlign.right,
                            style: style(11, color: grey))),
                        ]),
                        pw.SizedBox(height: 8),
                      ],
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('Project: ${invoice.project}', style: style(11)),
              pw.Text('Status: ${invoice.status.label}', style: style(11)),
              if (invoice.iban.trim().isNotEmpty)
                pw.Text('IBAN: ${invoice.iban}', style: style(11)),
              pw.SizedBox(height: 6),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: const ['Description', 'Qty', 'Unit Price', 'Total'],
          data: invoice.items.isEmpty
              ? [['No itemized lines recorded', '-', '-', '-']]
              : invoice.items.map((item) => [
                  item.description, '${item.quantity}',
                  money(item.unitPriceMinor), money(item.totalMinor),
                ]).toList(),
          headerDecoration: pw.BoxDecoration(color: blue),
          headerStyle: style(11, color: PdfColors.white, bold: true),
          cellStyle: style(10),
          cellPadding: const pw.EdgeInsets.all(9),
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: rule, width: .6),
            verticalInside: pw.BorderSide(color: rule, width: .6)),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2.2),
            3: const pw.FlexColumnWidth(2.2),
          },
        ),
        pw.SizedBox(height: 12),
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
          color: entry.$1 == 'Total' ? blue : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(
            vertical: 7, horizontal: 9),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(width: 170,
                child: pw.Text(entry.$1,
                  textAlign: pw.TextAlign.right,
                  style: style(entry.$1 == 'Total' ? 12 : 10,
                    color: entry.$1 == 'Total' ? PdfColors.white : grey,
                    bold: entry.$1 == 'Total'))),
              pw.SizedBox(width: 110,
                child: pw.Text(entry.$2,
                  textAlign: pw.TextAlign.right,
                  style: style(entry.$1 == 'Total' ? 12 : 10,
                    color: entry.$1 == 'Total' ? PdfColors.white : dark,
                    bold: entry.$1 == 'Total'))),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#E4EAF0')),
            borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Payment Details', style: style(14, bold: true)),
              pw.SizedBox(height: 5),
              pw.Text(qrPayload == null
                ? 'Payment QR unavailable' : 'Scan to Pay',
                style: style(11)),
              pw.SizedBox(height: 12),
              if (qrPayload != null)
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrPayload, width: 92, height: 92),
              if (qrPayload == null)
                pw.Text('A validated Swiss payee address, IBAN and amount '
                  'are required for a scannable payment QR.',
                  style: style(10, color: grey)),
              if (invoice.iban.trim().isNotEmpty)
                pw.Text('Account / payable to: ${invoice.iban}',
                  style: style(10)),
              if (invoice.payment != null &&
                  invoice.payment!.accountHolder.trim().isNotEmpty)
                pw.Text('Company: ${invoice.payment!.accountHolder}',
                  style: style(10)),
              pw.Text('Payable amount: ${money(invoice.amountDueMinor)}',
                style: style(10)),
              pw.Text('Currency: ${invoice.currency}', style: style(10)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text('General Terms & Conditions',
          style: style(15, bold: true)),
        pw.SizedBox(height: 10),
        pw.Text(invoice.terms.trim().isEmpty
          ? 'No terms and conditions have been provided.'
          : invoice.terms,
          style: style(11, color: grey)),
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
