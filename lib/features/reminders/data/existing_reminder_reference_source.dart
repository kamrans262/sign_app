import '../../clients/data/demo_client_repository.dart';
import '../../documents/data/demo_document_repository.dart';
import '../../invoices/data/demo_invoice_repository.dart';
import '../../jobs/data/mock_jobs.dart';
import '../domain/reminder_record.dart';

/// Reads selectable demo records from existing feature data sources; linked
/// reminders store their type and stable record ID rather than just text.
class ExistingReminderReferenceSource implements ReminderReferenceSource {
  ExistingReminderReferenceSource();

  @override
  Future<List<ReminderRelatedItem>> listForType(ReminderType type) async {
    switch (type) {
      case ReminderType.invoice:
        final invoices = await const DemoInvoiceRepository().listInvoices();
        return [
          for (final invoice in invoices)
            ReminderRelatedItem(type: type, id: invoice.id,
              title: invoice.number, project: invoice.project),
        ];
      case ReminderType.job:
        return [
          for (final job in MockJobsData.jobs)
            ReminderRelatedItem(type: type, id: job.id,
              title: '${job.referenceNumber} — ${job.title}',
              project: job.title),
        ];
      case ReminderType.document:
        final documents = await const DemoDocumentRepository().listDocuments();
        return [
          for (final doc in documents)
            ReminderRelatedItem(type: type, id: doc.id,
              title: doc.title, project: doc.project),
        ];
      case ReminderType.client:
        final clients = await DemoClientRepository().listClients();
        return [
          for (final client in clients)
            ReminderRelatedItem(type: type, id: client.id,
              title: client.companyName),
        ];
      case ReminderType.other:
        return [];
    }
  }
}
