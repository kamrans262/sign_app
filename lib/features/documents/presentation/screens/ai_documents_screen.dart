import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../data/remote_general_document_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../domain/document_record.dart';
import 'document_details_screen.dart';
import 'generate_ai_document_screen.dart';
import 'general_document_editor_screen.dart';

/// AI document hub reusing the dashboard chrome and existing document cards.
/// Loads real company-owned documents from Laravel; no preview fixtures.
class AiDocumentsScreen extends StatefulWidget {
  const AiDocumentsScreen({
    super.key,
    this.repository,
    this.onDocumentTap,
    this.onCreateDocument,
    this.documentGenerator,
    this.onNavigationSelected,
    this.onNotificationTap,
    this.onProfileTap,
    this.showAll = false,
  });

  final DocumentRepository? repository;
  final ValueChanged<DocumentRecord>? onDocumentTap;
  final VoidCallback? onCreateDocument;
  final AiDocumentGenerator? documentGenerator;
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
    _repository = widget.repository ?? RemoteGeneralDocumentRepository.shared;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _repository.listDocuments();
      final generated = records.where((record) =>
        record.status.toLowerCase() == 'generated' ||
        record.id.startsWith('ai-document-') ||
        record.id.startsWith('general-')).toList();
      generated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) { return; }
      setState(() {
        _documents = generated;
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
    if (!MobileAuthRepository.shared.isSignedIn) {
      _notify('Sign in to generate company documents.');
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('ai-documents-create-general'),
              title: const Text('General Document'),
              subtitle: const Text('Business letter, statement, acceptance or custom draft'),
              onTap: () => Navigator.pop(sheet, 'general'),
            ),
            ListTile(
              key: const Key('ai-documents-create-project'),
              title: const Text('Project Document'),
              subtitle: const Text('Use the existing job and sections workflow'),
              onTap: () => Navigator.pop(sheet, 'project'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => choice == 'general'
        ? const GeneralDocumentEditorScreen()
        : GenerateAiDocumentScreen(documentGenerator: widget.documentGenerator)),
    );
    if (mounted) { await _load(); }
  }

  Future<void> _openDocument(DocumentRecord record) async {
    if (widget.onDocumentTap != null) {
      widget.onDocumentTap!(record);
      return;
    }
    final id=record.id.startsWith('general-')
        ? int.tryParse(record.id.substring('general-'.length)) : null;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => id!=null
          ? GeneralDocumentEditorScreen(documentId:id)
          : DocumentDetailsScreen(documentId:record.id,document:record),
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
          documentGenerator: widget.documentGenerator,
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
