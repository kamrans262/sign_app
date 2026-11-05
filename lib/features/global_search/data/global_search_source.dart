import '../../clients/data/client_repository.dart';
import '../../clients/data/demo_client_repository.dart';
import '../../clients/domain/client_profile.dart';
import '../../deposits/data/demo_deposit_repository.dart';
import '../../deposits/domain/deposit_record.dart';
import '../../documents/data/demo_document_repository.dart';
import '../../documents/data/demo_report_repository.dart';
import '../../documents/domain/document_record.dart';
import '../../equipment/data/demo_equipment_repository.dart';
import '../../equipment/domain/equipment_record.dart';
import '../../expenses/data/demo_expense_repository.dart';
import '../../expenses/domain/expense_record.dart';
import '../../invoices/data/demo_invoice_repository.dart';
import '../../invoices/domain/invoice_record.dart';
import '../../jobs/data/mock_jobs.dart';
import '../../jobs/domain/job_model.dart';

enum GlobalSearchCategory {
  jobs('Job'), clients('Client'), quotes('Quote'),
  documents('Document'), generalDocuments('Document'),
  invoices('Invoice'), expenses('Expense'), deposits('Deposit'),
  equipment('Equipment'), reports('Report'), reminders('Reminder');

  const GlobalSearchCategory(this.label);
  final String label;

  bool get isMore => switch (this) {
    GlobalSearchCategory.quotes || GlobalSearchCategory.expenses ||
    GlobalSearchCategory.deposits ||
    GlobalSearchCategory.equipment ||
    GlobalSearchCategory.reports ||
    GlobalSearchCategory.reminders => true,
    _ => false,
  };
}

enum GlobalSearchTab { all, jobs, clients, documents, invoices, more }

/// Wraps an EXISTING repository record; never a fabricated search fixture.
/// [record] is passed unchanged to the matching module's Details screen.
class GlobalSearchResult {
  const GlobalSearchResult({
    required this.category, required this.id, required this.title,
    required this.subtitle, required this.details, required this.record,
    this.searchTerms = const [],
  });

  final GlobalSearchCategory category;
  final String id, title, subtitle, details;
  final Object record;
  final List<String> searchTerms;

  String get key => '${category.name}:$id';

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    return needle.isEmpty ||
        [title, id, subtitle, details, category.label, ...searchTerms]
          .any((part) => part.toLowerCase().contains(needle));
  }

  bool inTab(GlobalSearchTab tab) => switch (tab) {
    GlobalSearchTab.all => true,
    GlobalSearchTab.jobs => category == GlobalSearchCategory.jobs,
    GlobalSearchTab.clients => category == GlobalSearchCategory.clients,
    GlobalSearchTab.documents => category == GlobalSearchCategory.documents ||
      category == GlobalSearchCategory.generalDocuments,
    GlobalSearchTab.invoices => category == GlobalSearchCategory.invoices,
    GlobalSearchTab.more => category.isMore,
  };
}

/// A provider can be swapped for an API-backed aggregated search later.
abstract class GlobalSearchProvider {
  Future<List<GlobalSearchResult>> loadAll();
}

/// Existing demo/session repositories only. No synthetic "10 results".
class ExistingGlobalSearchProvider implements GlobalSearchProvider {
  ExistingGlobalSearchProvider({
    ClientRepository? clients,
    DocumentRepository? documents,
    DocumentRepository? reports,
    InvoiceRepository? invoices,
    ExpenseRepository? expenses,
    DepositRepository? deposits,
    EquipmentRepository? equipment,
    List<JobModel>? jobs,
  }) : clients = clients ?? DemoClientRepository(),
       documents = documents ?? const DemoDocumentRepository(),
       reports = reports ?? const DemoReportRepository(),
       invoices = invoices ?? const DemoInvoiceRepository(),
       expenses = expenses ?? const DemoExpenseRepository(),
       deposits = deposits ?? const DemoDepositRepository(),
       equipment = equipment ?? const DemoEquipmentRepository(),
       jobs = jobs ?? MockJobsData.jobs;

  final ClientRepository clients;
  final DocumentRepository documents, reports;
  final InvoiceRepository invoices;
  final ExpenseRepository expenses;
  final DepositRepository deposits;
  final EquipmentRepository equipment;
  final List<JobModel> jobs;

  @override
  Future<List<GlobalSearchResult>> loadAll() async {
    final clientsData = await clients.listClients();
    final documentsData = await documents.listDocuments();
    final invoicesData = await invoices.listInvoices();
    final expensesData = await expenses.listExpenses();
    final depositsData = await deposits.listDeposits();
    final equipmentData = await equipment.listEquipment();
    final reportsData = await reports.listDocuments();

    final results = <GlobalSearchResult>[
      for (final JobModel job in jobs)
        GlobalSearchResult(
          category: GlobalSearchCategory.jobs, id: job.id,
          title: job.title,
          subtitle: 'Job: ${job.referenceNumber}',
          details: 'Client: ${job.clientName}',
          searchTerms: [job.description, job.statusLabel],
          record: job),
      for (final ClientProfile client in clientsData)
        GlobalSearchResult(
          category: GlobalSearchCategory.clients, id: client.id,
          title: client.companyName,
          subtitle: client.companyType,
          details: client.fullName.isNotEmpty
            ? client.fullName : client.email,
          searchTerms: [client.phone, client.address, client.notes],
          record: client),
      for (final DocumentRecord doc in documentsData)
        if (doc.category != DocumentCategory.reports)
          GlobalSearchResult(
            category: GlobalSearchCategory.documents, id: doc.id,
            title: doc.title, subtitle: 'Document: ${doc.number}',
            details: doc.project,
            searchTerms: [doc.customer, doc.status],
            record: doc),
      for (final InvoiceRecord invoice in invoicesData)
        GlobalSearchResult(
          category: GlobalSearchCategory.invoices, id: invoice.id,
          title: invoice.number, subtitle: invoice.project,
          details: 'Client: ${invoice.clientName}',
          searchTerms: [invoice.status.label, invoice.notes,
            invoice.formattedAmount],
          record: invoice),
      for (final ExpenseRecord expense in expensesData)
        GlobalSearchResult(
          category: GlobalSearchCategory.expenses, id: expense.id,
          title: expense.title, subtitle: expense.job,
          details: expense.formattedAmount,
          searchTerms: [expense.category.label, expense.report,
            expense.description],
          record: expense),
      for (final DepositRecord deposit in depositsData)
        GlobalSearchResult(
          category: GlobalSearchCategory.deposits, id: deposit.id,
          title: deposit.title,
          subtitle: 'Client: ${deposit.clientName}',
          details: deposit.formattedAmount,
          searchTerms: [deposit.referenceNumber, deposit.jobReference ?? '',
            deposit.paymentMethod, deposit.status.label],
          record: deposit),
      for (final EquipmentRecord item in equipmentData)
        GlobalSearchResult(
          category: GlobalSearchCategory.equipment, id: item.id,
          title: item.name, subtitle: item.id, details: item.category,
          searchTerms: [item.brand, item.model, item.location, item.notes],
          record: item),
      for (final DocumentRecord report in reportsData)
        if (report.category == DocumentCategory.reports)
          GlobalSearchResult(
            category: GlobalSearchCategory.reports, id: report.id,
            title: report.title, subtitle: report.project,
            details: report.number,
            searchTerms: [report.customer, report.status],
            record: report),
    ];

    // A record may appear in the Document repository AND Report repository.
    // Keep the first stable category+ID rather than duplicate a card.
    final seen = <String>{};
    return List<GlobalSearchResult>.unmodifiable(
      results.where((entry) => seen.add(entry.key)));
  }
}
