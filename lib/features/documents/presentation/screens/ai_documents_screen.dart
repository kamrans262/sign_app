import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../jobs/data/mock_jobs.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/screens/job_notes_screen.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../data/demo_document_repository.dart';
import '../../domain/document_record.dart';
import 'document_details_screen.dart';

/// AI document hub reusing the dashboard chrome and existing document cards.
/// Default examples are clearly local Figma fixtures, not generated AI output.
class AiDocumentsScreen extends StatefulWidget {
  const AiDocumentsScreen({
    super.key,
    this.repository,
    this.onDocumentTap,
    this.onCreateDocument,
    this.onNavigationSelected,
    this.onNotificationTap,
    this.onProfileTap,
    this.showAll = false,
  });

  final DocumentRepository? repository;
  final ValueChanged<DocumentRecord>? onDocumentTap;
  final VoidCallback? onCreateDocument;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap, onProfileTap;
  final bool showAll;

  @override
  State<AiDocumentsScreen> createState() => _AiDocumentsScreenState();
}

class _AiDocumentsScreenState extends State<AiDocumentsScreen> {
  late final DocumentRepository _repository;
  List<DocumentRecord> _documents = const [];
  bool _loading = true;
  String? _error;

  static const _actionDescription =
      'Create professional documents from your project data';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoDocumentRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listDocuments();
      final generated = records.where((record) =>
        record.status.toLowerCase() == 'generated' ||
        record.id.startsWith('ai-document-')).toList();
      generated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) { return; }
      setState(() {
        // Only the built-in demo repository supplies visual Figma examples.
        // An injected empty repository correctly produces an empty state.
        _documents = generated.isEmpty && widget.repository == null
            ? _figmaExamples() : generated;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) { return; }
      setState(() {
        _loading = false;
        _error = 'AI documents could not be loaded';
      });
    }
  }

  List<DocumentRecord> _figmaExamples() => [
    for (var index = 0; index < 3; index++)
      DocumentRecord(
        id: 'ai-document-figma-${index + 1}',
        category: DocumentCategory.reports,
        reportKind: ReportKind.workAcceptance,
        number: 'AI-DEMO-${index + 1}',
        title: 'Work Acceptance Report',
        project: 'Riverside villa',
        customer: 'Jean Dupont',
        timestamp: DateTime(2026, 8, 12),
        status: 'Generated',
        demoOnly: true,
      ),
  ];

  void _notify(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigation(int index) {
    if (index == 4) { return; }
    final callback = widget.onNavigationSelected;
    Navigator.of(context).maybePop();
    callback?.call(index);
  }

  Future<void> _generate() async {
    if (widget.onCreateDocument != null) {
      widget.onCreateDocument!();
      return;
    }
    // The existing conversion flow needs a selected Job Note, not a blank
    // fabricated note. Choose a job, then use its existing Notes workflow.
    final jobs = MockJobsData.jobs;
    final job = await showModalBottomSheet<JobModel>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .65,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select a job to generate a document',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16,
                  fontWeight: FontWeight.w600)),
            ),
            Expanded(child: ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, index) => ListTile(
                key: Key('ai-documents-job-${jobs[index].id}'),
                title: Text(jobs[index].title),
                subtitle: Text(jobs[index].referenceNumber),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheet).pop(jobs[index]),
              ),
            )),
          ]),
        ),
      ),
    );
    if (!mounted || job == null) { return; }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JobNotesScreen(
          job: job,
          onTabSelected: widget.onNavigationSelected,
        ),
      ),
    );
  }

  Future<void> _selectDocumentFor(String operation) async {
    if (_loading || _error != null) { return; }
    if (_documents.isEmpty) {
      _notify('No AI documents are available to $operation.');
      return;
    }
    final picked = await showModalBottomSheet<DocumentRecord>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .55,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(16),
              child: Text('Select a document to $operation',
                style: const TextStyle(fontFamily: 'Inter',
                  fontSize: 16, fontWeight: FontWeight.w600))),
            Expanded(child: ListView.builder(
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final record = _documents[index];
                return ListTile(
                  key: Key('ai-documents-select-${record.id}'),
                  title: Text(record.title),
                  subtitle: Text(record.project),
                  onTap: () => Navigator.of(sheet).pop(record),
                );
              },
            )),
          ]),
        ),
      ),
    );
    if (!mounted || picked == null) { return; }
    // No document summarization or translation service is connected here.
    _notify('AI $operation is not connected yet for ${picked.title}. '
      'No changes were made.');
  }

  Future<void> _openDocument(DocumentRecord record) async {
    if (widget.onDocumentTap != null) {
      widget.onDocumentTap!(record);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailsScreen(
          documentId: record.id, document: record,
        ),
      ),
    );
    if (mounted) { await _load(); }
  }

  void _seeAll() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AiDocumentsScreen(
          repository: widget.repository,
          onDocumentTap: widget.onDocumentTap,
          onCreateDocument: widget.onCreateDocument,
          onNavigationSelected: widget.onNavigationSelected,
          onNotificationTap: widget.onNotificationTap,
          onProfileTap: widget.onProfileTap,
          showAll: true,
        ),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String id,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('ai-documents-$id'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Sign2DigitalOutlinedContainer(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE3ECF0),
              child: Icon(Icons.description_outlined,
                size: 24, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 16,
                    fontWeight: FontWeight.w600, color: AppColors.dark)),
                const SizedBox(height: 5),
                const Text(_actionDescription,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.placeholder)),
              ],
            )),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
              size: 24, color: AppColors.secondaryText),
          ]),
        ),
      ),
    ),
  );

  Widget _recentHeader() => Row(children: [
    Expanded(child: Text(
      widget.showAll ? 'All AI Documents' : 'Recent AI Documents',
      style: const TextStyle(fontFamily: 'Inter', fontSize: 18,
        fontWeight: FontWeight.w600, color: AppColors.dark),
    )),
    if (!widget.showAll)
      TextButton(
        key: const Key('ai-documents-see-all'),
        onPressed: _seeAll,
        child: const Text('See all',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12,
            fontWeight: FontWeight.w500, color: AppColors.primary)),
      ),
  ]);

  Widget _recentItems() {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(key: Key('ai-documents-loading')),
      ));
    }
    if (_error != null) {
      return Center(child: TextButton(
        key: const Key('ai-documents-retry'),
        onPressed: _load,
        child: Text('$_error. Tap to retry.'),
      ));
    }
    if (_documents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No AI documents yet.',
          key: Key('ai-documents-empty'),
          style: TextStyle(fontFamily: 'Inter',
            color: AppColors.placeholder, fontSize: 14))),
      );
    }
    final shown = widget.showAll
        ? _documents : _documents.take(3).toList(growable: false);
    return Column(children: [
      for (var i = 0; i < shown.length; i++) ...[
        Sign2DigitalQuoteSummaryCard(
          key: Key('ai-document-card-${shown[i].id}'),
          quoteNumber: shown[i].number,
          titleOverride: shown[i].title,
          projectName: shown[i].project,
          documentDate: shown[i].timestamp,
          status: shown[i].status,
          listStyle: true,
          aiDocumentStyle: true,
          onTap: () => _openDocument(shown[i]),
        ),
        if (i < shown.length - 1) const SizedBox(height: 20),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalDashboardHeader(
        onNotificationTap: widget.onNotificationTap,
        onProfileTap: widget.onProfileTap,
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Stack(children: [
          ListView(
            key: const Key('ai-documents-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 95),
            children: [
              if (!widget.showAll) ...[
                _actionCard(
                  title: 'Generate Document', id: 'generate',
                  onTap: _generate),
                const SizedBox(height: 20),
                _actionCard(
                  title: 'Summarize Document', id: 'summarize',
                  onTap: () => _selectDocumentFor('summarize')),
                const SizedBox(height: 20),
                _actionCard(
                  title: 'Translate Document', id: 'translate',
                  onTap: () => _selectDocumentFor('translate')),
                const SizedBox(height: 25),
              ],
              _recentHeader(),
              const SizedBox(height: 15),
              _recentItems(),
            ],
          ),
          Positioned(
            right: 20, bottom: 20,
            child: SizedBox(
              width: 50, height: 50,
              child: FloatingActionButton(
                key: const Key('ai-documents-create'),
                heroTag: widget.showAll
                    ? 'ai-documents-create-all' : 'ai-documents-create',
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 3,
                onPressed: _generate,
                child: const Icon(Icons.add, size: 30),
              ),
            ),
          ),
        ]),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 4,
      onSelected: _navigation,
    ),
  );
}
