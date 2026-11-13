import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../clients/data/remote_client_repository.dart';
import '../../documents/data/remote_document_repository.dart';
import '../../equipment/data/remote_equipment_loan_repository.dart';
import '../../invoices/data/remote_invoice_repository.dart';
import '../../jobs/data/remote_job_repository.dart';
import '../../jobs/domain/job_model.dart';
import '../domain/reminder_record.dart';

/// A reminder must link to the authoritative ID of an existing record.
/// Each module exposes a different listing format; use its verified repository
/// rather than treating every API response as a generic "records" array.
class RemoteReminderReferenceSource implements ReminderReferenceSource {
  RemoteReminderReferenceSource({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;
  final SignApiClient _api;

  static int _id(Object? value) => int.tryParse('$value') ?? 0;

  @override
  Future<List<ReminderRelatedItem>> listForType(ReminderType type) async {
    if (type == ReminderType.other) return const [];
    final company = ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select a company first.');
    }
    final result = <ReminderRelatedItem>[];
    switch (type) {
      case ReminderType.job:
        final jobs = await RemoteJobRepository(api: _api).listJobs();
        for (final job in jobs) {
          if (job.category == JobCategory.archived || _id(job.id) <= 0) {
            continue;
          }
          result.add(ReminderRelatedItem(
            type: type,
            id: job.id,
            title: job.referenceNumber.trim().isEmpty
                ? job.title : '${job.referenceNumber} — ${job.title}',
            project: job.clientName,
          ));
        }
      case ReminderType.invoice:
        final invoices = await RemoteInvoiceRepository(api: _api).listInvoices();
        for (final invoice in invoices) {
          if (_id(invoice.id) <= 0) continue;
          result.add(ReminderRelatedItem(
            type: type, id: invoice.id, title: invoice.number,
            project: invoice.project,
          ));
        }
      case ReminderType.client:
        final clients = await RemoteClientRepository(api: _api).listClients();
        for (final client in clients) {
          if (_id(client.id) <= 0) continue;
          final name = client.fullName.trim().isNotEmpty
              ? client.fullName : client.companyName;
          result.add(ReminderRelatedItem(
            type: type, id: client.id, title: name,
            project: client.companyName,
          ));
        }
      case ReminderType.document:
        final docs = await RemoteDocumentRepository(api: _api).listDocuments();
        for (final doc in docs) {
          // M20 validates related_id against managed_documents. A synthetic
          // quote, general document, signed document, etc. is NOT linkable.
          final match = RegExp(r'^managed-([1-9][0-9]*)$')
              .firstMatch(doc.id);
          if (match == null) continue;
          result.add(ReminderRelatedItem(
            type: type, id: match.group(1)!, title: doc.title,
            project: doc.project,
          ));
        }
      case ReminderType.equipment:
        // The M20 backend references equipment_loans, not equipment_assets.
        final loans = await RemoteEquipmentLoanRepository(api: _api).listLoans();
        for (final loan in loans) {
          if (loan.id == null || loan.id! <= 0) continue;
          result.add(ReminderRelatedItem(
            type: type, id: loan.id!.toString(),
            title: loan.equipmentName, project: loan.borrowerName,
          ));
        }
      case ReminderType.other:
        break;
    }
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed while loading links.');
    }
    return List.unmodifiable(result);
  }
}
