import '../domain/client_details_model.dart';
import '../domain/client_profile.dart';

/// Stable UI demo information. This data is not obtained from a server.
abstract final class DemoClientDetails {
  static ClientDetailsModel forClient(ClientProfile client) {
    final isExample = client.id.startsWith('demo-client-');
    final id = client.id;
    return ClientDetailsModel(
      client: client,
      status: 'Active',
      displayAddress: client.address.isNotEmpty
          ? client.address
          : (isExample ? 'Rue du centre 12, 1000 Lausanne' : ''),
      totalQuotes: isExample ? 8 : 0,
      totalDocuments: isExample ? 12 : 0,
      totalInvoices: isExample ? 8 : 0,
      jobs: isExample
          ? List.generate(
              4,
              (index) => ClientRelatedRecord(
                id: '$id-job-$index',
                title: 'Villa Renovation',
                description: 'Interior renovation works',
                meta: 'Updated Mar 12, 2026',
                status: const [
                  'Active',
                  'Quote',
                  'In Progress',
                  'Active',
                ][index],
              ),
            )
          : const [],
      quotes: isExample
          ? [
              ClientRelatedRecord(
                id: '$id-quote-1',
                title: 'Renovation Estimate',
                description: 'Reference QT-2026-004',
                meta: 'Mar 12, 2026',
                status: 'Quote',
              ),
              ClientRelatedRecord(
                id: '$id-quote-2',
                title: 'Kitchen Extension',
                description: 'Reference QT-2026-005',
                meta: 'Mar 10, 2026',
                status: 'Active',
              ),
            ]
          : const [],
      documents: isExample
          ? [
              ClientRelatedRecord(
                id: '$id-document-1',
                title: 'Renovation Agreement.pdf',
                description: 'Contract',
                meta: 'Mar 12, 2026',
              ),
              ClientRelatedRecord(
                id: '$id-document-2',
                title: 'Project Drawings.pdf',
                description: 'Drawing',
                meta: 'Mar 10, 2026',
              ),
            ]
          : const [],
      invoices: isExample
          ? [
              ClientRelatedRecord(
                id: '$id-invoice-1',
                title: 'Invoice INV-2026-013',
                description: 'CHF 2,450.00',
                meta: 'Mar 12, 2026',
                status: 'Active',
              ),
              ClientRelatedRecord(
                id: '$id-invoice-2',
                title: 'Invoice INV-2026-009',
                description: 'CHF 1,250.00',
                meta: 'Mar 05, 2026',
                status: 'In Progress',
              ),
            ]
          : const [],
      notes: client.notes.trim().isNotEmpty
          ? [
              ClientRelatedRecord(
                id: '$id-note',
                title: 'Client note',
                description: client.notes,
                meta: 'Locally entered',
              ),
            ]
          : isExample
          ? [
              ClientRelatedRecord(
                id: '$id-demo-note',
                title: 'Project preferences',
                description: 'Prefers updates by email.',
                meta: 'Mar 12, 2026',
              ),
            ]
          : const [],
    );
  }
}
