import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/quote_review_models.dart';
import 'quote_pdf_locale.dart';

/// Builds a real A4 document from exactly the same draft used by Quote Preview.
/// No mobile scaffold, device chrome, or action buttons are printed.
class Sign2DigitalQuotePdfBuilder {
  const Sign2DigitalQuotePdfBuilder();

  Future<Uint8List> build(QuoteReviewDraft source) async {
    final quote = source.copy();
    final language = QuotePdfLocale.selectedCode();
    String tr(String english) => QuotePdfLocale.tr(english, language);
    final logoData = await rootBundle.load('assets/header_logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List(
      logoData.offsetInBytes, logoData.lengthInBytes));

    pw.Font? inter;
    try {
      inter = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    } catch (_) {
      // Flutter can still export a readable PDF if the bundled variable font
      // is unsupported by a particular pdf package version.
    }
    // M8 signing uses the open-source FPDI parser, which needs normal
    // PDF cross-reference tables rather than PDF 1.5 compressed xref streams.
    // Do not alter an already-approved M7 PDF: its original bytes remain frozen.
    final pdf = pw.Document(
      version: PdfVersion.pdf_1_4,
      theme: inter == null ? null : pw.ThemeData.withFont(base: inter, bold: inter),
    );
    final blue = PdfColor.fromHex('#166282');
    final ink = PdfColor.fromHex('#122536');
    final grey = PdfColor.fromHex('#8A9AA8');
    final rule = PdfColor.fromHex('#E4EAF0');
    String formatDate(DateTime? value) => QuotePdfLocale.date(value, language);
    pw.TextStyle style(double size, {PdfColor? color, bool bold = false}) =>
        pw.TextStyle(fontSize: size, color: color ?? ink,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    // Align both date values against the quote card's right-hand inset,
    // matching the quote number. Keep the label/value gap and original style.
    pw.Widget quoteDateRow(String label, String value) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 72, child: pw.Text(label,
          textAlign: pw.TextAlign.right, style: style(11))),
        pw.SizedBox(width: 6),
        pw.Expanded(child: pw.Text(value,
          textAlign: pw.TextAlign.right, style: style(11, color: grey))),
      ],
    );
    pw.Widget lineAmount(String label, String amount, {bool total = false}) {
      return pw.Container(
        color: total ? blue : PdfColors.white,
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 9),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.SizedBox(width: 110, child: pw.Text(label,
              style: style(total ? 12 : 10,
                  color: total ? PdfColors.white : grey, bold: total))),
          pw.SizedBox(width: 100, child: pw.Text(amount,
              textAlign: pw.TextAlign.right,
              style: style(total ? 12 : 10,
                  color: total ? PdfColors.white : ink, bold: total))),
        ]),
      );
    }

    final qrPayload = quote.isDemo ? null : quote.payment?.swissQrBillPayload(
      currency: quote.currency, amountMinor: quote.totalMinor);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      build: (context) => [
        if (quote.isDemo) pw.Container(
          padding: const pw.EdgeInsets.all(7),
          color: PdfColor.fromHex('#EEF2F5'),
          child: pw.Text('FIGMA DEMONSTRATION - NOT A LIVE CUSTOMER QUOTE',
            style: style(10, color: ink, bold: true)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: rule, width: .7),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(logo, width: 132, height: 43, fit: pw.BoxFit.contain),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(tr('Quote'), style: style(18, bold: true)),
                      pw.SizedBox(height: 6),
                      pw.Text(quote.quoteNumber.isEmpty ? tr('Unnumbered draft')
                          : quote.quoteNumber, style: style(12, color: grey)),
                    ]),
                ]),
              pw.SizedBox(height: 20),
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(tr('Bill To:'), style: style(14, bold: true)),
                      pw.SizedBox(height: 8),
                      for (final value in <String>[
                        quote.clientName, quote.billingAddress,
                        quote.clientEmail, quote.clientPhone,
                      ]) if (value.trim().isNotEmpty)
                        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Text(value, style: style(11, color: grey))),
                    ],
                  )),
                  pw.SizedBox(width: 12),
                  pw.SizedBox(width: 156, child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      quoteDateRow(tr('Date:'), formatDate(quote.date)),
                      pw.SizedBox(height: 8),
                      quoteDateRow(tr('Valid Until:'), formatDate(quote.validUntil)),
                    ],
                  )),
                ]),
              pw.SizedBox(height: 24),
            ]),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
                headers: [tr('Description'), tr('Qty'), tr('Unit Price'), tr('Total')],
                data: quote.items.map((item) => <String>[
                  quoteWorkItemDocumentText(item),
                  item.quantity.isEmpty ? '-' : item.quantity,
                  quoteMoney(item.priceMinor, quote.currency),
                  quoteMoney(item.totalMinor, quote.currency),
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
        if (!quote.allItemPricesValid)
                pw.Text(tr('Pricing incomplete - unresolved work item prices.'),
                  style: style(10, color: PdfColor.fromHex('#E6A23C'))),
              lineAmount(tr('Subtotal'), quoteMoney(quote.subtotalMinor, quote.currency)),
              lineAmount('${tr('Tax')} (${quotePercentText(quote.vatBasisPoints)}%)',
                quoteMoney(quote.vatMinor, quote.currency)),
              lineAmount(tr('Total'), quoteMoney(quote.totalMinor, quote.currency), total: true),
              lineAmount('${tr('Deposit due')} (${quotePercentText(quote.depositBasisPoints)}%)',
                quoteMoney(quote.depositMinor, quote.currency)),
              lineAmount(tr('Remaining after deposit'),
                quoteMoney(quote.remainingAfterDepositMinor, quote.currency)),
        pw.SizedBox(height: 65),
        // The tiny link annotation marks only the signature row and page.
        // Align it to the left edge of the actual Customer Signature rule.
        // Laravel independently uses the fixed PDF margin for stamp X, so
        // previously approved PDFs with a centered marker also work.
        // Keep marker and both lines together when paginating.
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
          pw.UrlLink(
            destination: 'https://sign2digital.invalid/signature-anchor-v1',
            child: pw.SizedBox(width: 1, height: 1),
          ),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              for (final label in [tr('Customer Signature'), tr('Date')])
                pw.SizedBox(width: 138, child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(height: 2, color: grey),
                    pw.SizedBox(height: 6),
                    pw.Text(label, style: style(10, color: grey)),
                  ])),
            ],
          ),
        ]),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: rule),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(tr('Payment Details'), style: style(14, bold: true)),
              pw.SizedBox(height: 5),
              pw.Text(qrPayload == null ? tr('Payment QR unavailable') : tr('Scan to Pay'),
                style: style(12)),
              pw.SizedBox(height: 16),
              if (qrPayload != null) pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrPayload, width: 96, height: 96),
                  pw.SizedBox(width: 15),
                  pw.Expanded(child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(tr('Account / payable to'), style: style(10, bold: true)),
                      pw.Text(quote.payment!.iban, style: style(10, color: grey)),
                      pw.SizedBox(height: 5),
                      pw.Text(tr('Company Name'), style: style(10, bold: true)),
                      pw.Text(quote.payment!.accountHolder, style: style(10, color: grey)),
                      pw.SizedBox(height: 5),
                      pw.Text(tr('Amount'), style: style(10, bold: true)),
                      pw.Text(quoteMoney(quote.totalMinor, quote.currency),
                          style: style(10, color: grey)),
                    ]),
                  ),
                ])
              else pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(tr('A valid Swiss payment account, address and payable amount are required before a payment QR can be displayed.'),
                    style: style(10, color: grey)),
                  pw.SizedBox(height: 12),
                  if (quote.payment != null &&
                      quote.payment!.iban.trim().isNotEmpty) ...[
                    pw.Text(tr('Account / payable to'), style: style(10, bold: true)),
                    pw.Text(quote.payment!.iban, style: style(10, color: grey)),
                    pw.SizedBox(height: 5),
                  ],
                  if (quote.payment != null &&
                      quote.payment!.accountHolder.trim().isNotEmpty) ...[
                    pw.Text(tr('Company Name'), style: style(10, bold: true)),
                    pw.Text(quote.payment!.accountHolder,
                      style: style(10, color: grey)),
                    pw.SizedBox(height: 5),
                  ],
                  pw.Text(tr('Payable amount'), style: style(10, bold: true)),
                  pw.Text(quoteMoney(quote.totalMinor, quote.currency),
                    style: style(10, color: grey)),
                  pw.SizedBox(height: 5),
                  pw.Text(tr('Currency'), style: style(10, bold: true)),
                  pw.Text(quote.currency, style: style(10, color: grey)),
                ],
              ),
            ]),
        ),
        pw.SizedBox(height: 20),
        pw.Text(tr('General Terms & Conditions'), style: style(15, bold: true)),
        pw.SizedBox(height: 12),
        pw.Text(quote.terms.trim().isEmpty ?
            tr('No terms and conditions have been provided.') : quote.terms,
            style: style(12, color: grey)),
      ],
    ));
    return pdf.save();
  }
}
