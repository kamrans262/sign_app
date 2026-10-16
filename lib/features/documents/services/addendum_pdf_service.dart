import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../quotes/domain/quote_review_models.dart' show quoteMoney, parseQuoteMinorUnits;
import '../domain/addendum_draft.dart';
import '../domain/document_record.dart';

/// Produces a standalone *unsigned* addendum PDF; it never modifies, replaces,
/// or forges a signature on the referenced original.
class AddendumPdfService {
  const AddendumPdfService();

  Future<Uint8List> build(AddendumDraft draft, DocumentRecord original) async {
    if (!draft.isCreatedLocally || draft.validationIssues.isNotEmpty ||
        draft.linkedDocumentId != original.id) {
      throw const FormatException('A valid original and created addendum are required.');
    }
    final total = draft.totalMinor;
    final subtotal = draft.subtotalMinor;
    final vat = draft.vatMinor;
    if (total == null || subtotal == null || vat == null) {
      throw const FormatException('Addendum prices have not been verified.');
    }
    final pdf = pw.Document();
    final primary = PdfColor.fromHex('#166282');
    final ink = PdfColor.fromHex('#122536');
    pw.Widget detail(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 138,
          child: pw.Text(label, style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, color: ink))),
        pw.Expanded(child: pw.Text(value)),
      ]),
    );
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text('Sign2Digital', style: pw.TextStyle(
          color: primary, fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 24),
        pw.Text('ADDENDUM ${draft.number}', style: pw.TextStyle(
          fontSize: 21, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('UNSIGNED — customer approval and signature not confirmed',
          style: pw.TextStyle(fontSize: 10, color: primary)),
        pw.SizedBox(height: 22),
        detail('Original document', original.number),
        detail('Original reference', original.id),
        detail('Addendum reference', draft.id),
        detail('Client', original.customer),
        detail('Job', draft.linkedJobId ?? original.quote?.jobId ??
            original.project),
        if (draft.effectiveDate != null)
          detail('Effective date',
            '${draft.effectiveDate!.day}/${draft.effectiveDate!.month}/${draft.effectiveDate!.year}'),
        pw.SizedBox(height: 18),
        pw.Text(draft.title, style: pw.TextStyle(
          fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Change description', style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(draft.description),
        pw.SizedBox(height: 18),
        if (draft.hasPricedWork) ...[
          detail('Additional work', draft.additionalWork),
          detail('Quantity', draft.quantity),
          detail('Unit price', quoteMoney(
            parseQuoteMinorUnits(draft.unitPrice), 'CHF')),
        ],
        detail('Additional work subtotal', quoteMoney(subtotal, 'CHF')),
        detail('VAT (${(draft.vatBasisPoints / 100).toStringAsFixed(2)}%)',
          quoteMoney(vat, 'CHF')),
        pw.Divider(),
        detail('Addendum total', quoteMoney(total, 'CHF')),
        pw.SizedBox(height: 40),
        pw.Text('Customer signature: __________________________'),
        pw.SizedBox(height: 14),
        pw.Text('Date: __________________________'),
      ],
    ));
    return pdf.save();
  }
}
