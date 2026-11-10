import 'dart:io';

import '../../quotes/domain/quote_review_models.dart';
import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

class InvoiceVoiceSuggestion {
  const InvoiceVoiceSuggestion({
    this.jobReference, this.clientName, this.invoiceNumber,
    this.iban, this.issueDate, this.dueDate,
    this.notes, this.items = const [],
  });
  final String? jobReference, clientName, invoiceNumber, iban, notes;
  final DateTime? issueDate, dueDate;
  final List<InvoiceVoiceLine> items;

  static String? _text(Object? input) =>
      input is String && input.trim().isNotEmpty ? input.trim() : null;

  static DateTime? _date(Object? input) {
    final text = _text(input);
    if (text == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return null;
    }
    final date = DateTime.tryParse(text);
    return date != null && date.toIso8601String().startsWith(text)
        ? date : null;
  }

  factory InvoiceVoiceSuggestion.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final lines = <InvoiceVoiceLine>[];
    if (raw is List) {
      for (final entry in raw.take(30)) {
        if (entry is! Map) { continue; }
        final title = _text(entry['description']);
        final quantity = entry['quantity'] is int
            ? entry['quantity'] as int : null;
        final price = entry['unitPrice'] is num
            ? parseQuoteMinorUnits((entry['unitPrice'] as num).toString())
            : null;
        if (title != null && quantity != null &&
            quantity > 0 && quantity <= 100000) {
          lines.add(InvoiceVoiceLine(
            description: title, quantity: quantity, unitPriceMinor: price));
        }
      }
    }
    return InvoiceVoiceSuggestion(
      jobReference: _text(json['jobReference']),
      clientName: _text(json['clientName']),
      invoiceNumber: _text(json['invoiceNumber']),
      iban: _text(json['iban']),
      issueDate: _date(json['issueDate']),
      dueDate: _date(json['dueDate']),
      notes: _text(json['notes']),
      items: lines,
    );
  }

  bool get hasSuggestions => jobReference != null ||
      clientName != null || invoiceNumber != null || iban != null ||
      issueDate != null || dueDate != null || notes != null ||
      items.isNotEmpty;
}

class InvoiceVoiceLine {
  const InvoiceVoiceLine({
    required this.description, required this.quantity, this.unitPriceMinor,
  });
  final String description;
  final int quantity;
  final int? unitPriceMinor;
}

abstract class InvoiceVoiceExtractionService {
  Future<InvoiceVoiceSuggestion> extract(String audioPath);
}

/// Live invoice dictation uses only the authenticated Laravel AI proxy.
/// OpenAI secrets must remain on the server, never in the mobile application.
class RemoteInvoiceVoiceExtractionService implements InvoiceVoiceExtractionService {
  RemoteInvoiceVoiceExtractionService({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  @override
  Future<InvoiceVoiceSuggestion> extract(String audioPath) async {
    final company = ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select a company before using invoice AI.');
    }
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const SignApiException('The invoice voice recording was not found.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length < 16 || bytes.length > 25 * 1024 * 1024) {
      throw const SignApiException('Invoice recording must be smaller than 25 MB.');
    }
    final response = await _api.postMultipart(
      '/api/v1/invoices/ai/voice',
      filename: file.uri.pathSegments.last,
      bytes: bytes,
      companyScoped: true,
      maxBytes: 25 * 1024 * 1024,
    );
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during invoice dictation.');
    }
    final data = response['data'];
    if (data is! Map<String, dynamic> ||
        data['suggestion'] is! Map<String, dynamic> ||
        data['saved'] != false ||
        data['approved'] != false ||
        data['issued'] != false ||
        data['requires_user_review'] != true) {
      throw const SignApiException('Invalid or unsafe invoice AI response.');
    }
    final suggested = InvoiceVoiceSuggestion.fromJson(
      Map<String, dynamic>.from(data['suggestion'] as Map<String, dynamic>),
    );
    if (!suggested.hasSuggestions) {
      throw const SignApiException('No clear invoice details were found.');
    }
    return suggested;
  }
}
