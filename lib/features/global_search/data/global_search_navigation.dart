import 'package:flutter/material.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../clients/data/remote_client_repository.dart';
import '../../clients/presentation/screens/client_details_screen.dart';
import '../../deposits/data/remote_deposit_repository.dart';
import '../../deposits/presentation/screens/deposit_details_screen.dart';
import '../../documents/data/remote_document_repository.dart';
import '../../documents/data/remote_site_report_repository.dart';
import '../../documents/presentation/screens/document_details_screen.dart';
import '../../equipment/data/remote_equipment_repository.dart';
import '../../equipment/presentation/screens/equipment_details_screen.dart';
import '../../expenses/data/remote_expense_repository.dart';
import '../../expenses/presentation/screens/expense_details_screen.dart';
import '../../invoices/data/remote_invoice_repository.dart';
import '../../invoices/presentation/screens/invoice_details_screen.dart';
import '../../jobs/data/remote_job_repository.dart';
import '../../jobs/presentation/screens/job_details_screen.dart';
import '../../quotes/data/remote_quote_repository.dart';
import '../../quotes/presentation/screens/quote_preview_screen.dart';
import '../../reminders/data/remote_reminder_repository.dart';
import '../../reminders/presentation/screens/add_reminder_screen.dart';
import 'remote_global_search_provider.dart';

/// Open an authoritative backend record only, never a fabricated UI model.
/// A company switch between search and loading invalidates the navigation.
abstract final class GlobalSearchNavigation {
  static Future<Widget> resolve(GlobalSearchHit hit) async {
    if (hit.companyId != ActiveCompanySession.companyId) {
      throw const SignApiException('Search result company has changed.');
    }
    final id = hit.id;
    final Widget result;
    switch (hit.type) {
      case 'jobs':
        result = JobDetailsScreen(
          job: await RemoteJobRepository.shared.getJob(id));
      case 'clients':
        result = ClientDetailsScreen(
          client: await RemoteClientRepository.shared.getClient(id),
          repository: RemoteClientRepository.shared);
      case 'quotes':
        result = QuotePreviewScreen(
          quote: await RemoteQuoteRepository.shared.getQuote(id));
      case 'documents':
      case 'general_documents':
        final key = hit.type == 'documents' ? 'managed-$id' : 'general-$id';
        final document = await RemoteDocumentRepository.shared.details(key);
        result = DocumentDetailsScreen(documentId: key, document: document,
          loadDocument: RemoteDocumentRepository.shared.details);
      case 'invoices':
        result = InvoiceDetailsScreen(
          invoice: await RemoteInvoiceRepository.shared.invoiceDetail('$id'),
          repository: RemoteInvoiceRepository.shared);
      case 'expenses':
        result = ExpenseDetailsScreen(
          expense: await RemoteExpenseRepository.shared.getExpense('$id'),
          repository: RemoteExpenseRepository.shared);
      case 'deposits':
        result = DepositDetailsScreen(
          deposit: await RemoteDepositRepository.shared.detail('$id'),
          repository: RemoteDepositRepository.shared);
      case 'equipment':
        result = EquipmentDetailsScreen(
          equipment: await RemoteEquipmentRepository.shared.getByServerId(id),
          repository: RemoteEquipmentRepository.shared);
      case 'reports':
        final report = await RemoteSiteReportRepository.shared.details('report-$id');
        result = DocumentDetailsScreen(documentId: report.id, document: report,
          loadDocument: RemoteSiteReportRepository.shared.details);
      case 'reminders':
        final records = await RemoteReminderRepository.shared.listReminders();
        final reminder = records.where((r) => r.id == '$id').firstOrNull;
        if (reminder == null) {
          throw const SignApiException('Reminder no longer available.');
        }
        result = AddReminderScreen(initialReminder: reminder);
      default:
        throw const SignApiException('Unsupported search destination.');
    }
    if (hit.companyId != ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed while opening the result.');
    }
    return result;
  }
}
