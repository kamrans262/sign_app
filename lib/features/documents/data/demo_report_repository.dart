import '../domain/document_record.dart';

/// Session-only report drafts. No remote creation, delivery or completion.
abstract final class DemoReportDraftSession {
  static final Map<String, DocumentRecord> _drafts = {};

  static List<DocumentRecord> get drafts =>
      List<DocumentRecord>.unmodifiable(_drafts.values);

  static DocumentRecord? find(String id) => _drafts[id];

  static void save(DocumentRecord report) {
    final site = report.siteReportDetails;
    if (report.category != DocumentCategory.reports ||
        report.reportKind == null ||
        !report.demoOnly ||
        report.status.toLowerCase() != 'draft' ||
        report.title.trim().isEmpty ||
        (site == null
            ? report.project.trim().isEmpty || report.customer.trim().isEmpty
            : report.reportKind != ReportKind.siteReport ||
                site.preparedBy.trim().isEmpty ||
                site.weatherCondition.trim().isEmpty ||
                site.selectedSections.isEmpty)) {
      throw ArgumentError('A valid local draft report is required.');
    }
    _drafts[report.id] = report;
  }

  static void clear() => _drafts.clear();
}

/// Figma-first fixtures for Reports, including one Work acceptance sample
/// after the five Site Report cards. No finished PDF is claimed or generated.
class DemoReportRepository implements DocumentRepository {
  const DemoReportRepository();

  @override
  Future<List<DocumentRecord>> listDocuments() async => [
    for (var index = 0; index < 5; index++)
      DocumentRecord(
        id: 'report-figma-site-${index + 1}',
        category: DocumentCategory.reports,
        reportKind: ReportKind.siteReport,
        number: 'SR-2026-${(index + 1).toString().padLeft(3, '0')}',
        title: 'Site Report- Week 3',
        project: 'Kitchen renovation',
        customer: 'Jean dupont',
        timestamp: DateTime(2026, 8, 23, 22),
        status: const ['Completed', 'Completed', 'Draft', 'Draft', 'Completed'][index],
        createdAt: DateTime(2026, 8, 23),
        demoOnly: true,
      ),
    DocumentRecord(
      id: 'report-demo-work-acceptance-1',
      category: DocumentCategory.reports,
      reportKind: ReportKind.workAcceptance,
      number: 'WA-2026-001',
      title: 'Work acceptance- Kitchen renovation',
      project: 'Kitchen renovation',
      customer: 'Jean dupont',
      timestamp: DateTime(2026, 8, 23, 22),
      status: 'Draft',
      demoOnly: true,
    ),
    ...DemoReportDraftSession.drafts,
  ];
}
