import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/navigation/sign2digital_navigation.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../../quotes/presentation/widgets/sign2digital_signature_action_card.dart';
import '../../data/remote_general_document_repository.dart';
import '../../domain/document_record.dart';
import '../../domain/general_document_draft.dart';
import 'general_document_editor_screen.dart';
import 'general_document_issued_actions.dart';

/// General AI documents use the same approved details composition as other
/// Documents. Only genuine server-issued PDF bytes can be exported/shared.
class GeneralDocumentDetailsScreen extends StatefulWidget {
  const GeneralDocumentDetailsScreen({
    super.key, required this.documentId, this.repository,
    this.initialDocument, this.summary, this.initialTab = 0,
    this.jobName, this.clientName,
  });

  final int documentId;
  final RemoteGeneralDocumentRepository? repository;
  final GeneralDocumentDraft? initialDocument;
  final DocumentRecord? summary;
  final int initialTab;
  final String? jobName, clientName;

  @override
  State<GeneralDocumentDetailsScreen> createState() =>
      _GeneralDocumentDetailsScreenState();
}

class _GeneralDocumentDetailsScreenState
    extends State<GeneralDocumentDetailsScreen> {
  late final RemoteGeneralDocumentRepository _repository;
  GeneralDocumentDraft? _document;
  List<Map<String, dynamic>>? _events;
  bool _loading = true, _busy = false, _historyLoading = false;
  String? _error, _historyError;
  int _tab = 0, _action = 0;

  static const _tabs = ['Details', 'Preview', 'Related', 'History'];
  static const _types = <String, String>{
    'letter': 'Business Letter',
    'statement': 'Statement',
    'power_of_attorney': 'Power of Attorney',
    'acceptance': 'Acceptance Document',
    'custom': 'Custom Document',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RemoteGeneralDocumentRepository.shared;
    _tab = widget.initialTab.clamp(0, 3).toInt();
    final initial = widget.initialDocument;
    if (initial != null && initial.id == widget.documentId &&
        initial.blocks.isNotEmpty) {
      _document = initial;
      _loading = false;
      if (_tab == 3) _loadHistory();
    } else {
      _reload();
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final document = await _repository.detail(widget.documentId);
      if (!mounted) return;
      setState(() {
        _document = document;
        _loading = false;
        _events = null;
      });
      if (_tab == 3) _loadHistory();
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Unable to load this document. Check company access.';
      });
    }
  }

  Future<void> _loadHistory() async {
    if (_historyLoading) return;
    setState(() { _historyLoading = true; _historyError = null; });
    try {
      final events = await _repository.history(widget.documentId);
      if (mounted) setState(() { _events = events; _historyLoading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _historyError = 'Unable to load document activity.';
        _historyLoading = false;
      });
    }
  }

  void _setTab(int index) {
    setState(() => _tab = index);
    if (index == 3 && _events == null && !_historyLoading) _loadHistory();
  }

  String _date(DateTime? value) {
    if (value == null) return 'Not available';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[value.month - 1] + ' ' + value.day.toString() +
        ', ' + value.year.toString();
  }

  String _job(GeneralDocumentDraft d) {
    if (d.jobTitle.trim().isNotEmpty) return d.jobTitle;
    if (widget.jobName?.trim().isNotEmpty ?? false) return widget.jobName!;
    final summary = widget.summary?.project ?? '';
    if (summary.isNotEmpty && summary != 'Not linked to a job') return summary;
    return d.jobId == null ? 'Not linked' : 'Job #' + d.jobId.toString();
  }

  String _client(GeneralDocumentDraft d) {
    if (d.clientName.trim().isNotEmpty) return d.clientName;
    if (widget.clientName?.trim().isNotEmpty ?? false) return widget.clientName!;
    final summary = widget.summary?.customer ?? '';
    if (summary.isNotEmpty) return summary;
    return d.clientId == null ? 'Not linked' : 'Client #' + d.clientId.toString();
  }

  Future<void> _edit() async {
    final d = _document;
    if (_busy || d?.editable != true ||
        !ActiveCompanySession.canWrite('documents')) return;
    await Sign2DigitalNavigation.push<void>(context, MaterialPageRoute<void>(
      builder: (_) => GeneralDocumentEditorScreen(
        documentId: widget.documentId,
        repository: _repository,
        openForEditing: true,
      ),
    ));
    if (mounted) await _reload();
  }

  Future<void> _transition(String action) async {
    final d = _document;
    if (d?.id == null || _busy || !ActiveCompanySession.canWrite('documents') ||
        (action == 'review' && d!.status != 'draft') ||
        (action == 'approve' && d!.status != 'reviewed')) return;
    setState(() => _busy = true);
    try {
      final changed = await _repository.transition(d!.id!, action,
        lockVersion: d.lockVersion);
      if (mounted) {
        setState(() { _document = changed; _events = null; });
        _notice(action == 'approve'
            ? 'Document approved and locked.'
            : 'Document marked reviewed.');
      }
    } catch (_) {
      _notice('Unable to update this document. Please check permissions.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _officialActions() async {
    final d = _document;
    if (d?.id == null || d!.status != 'approved' ||
        !ActiveCompanySession.canWrite('documents')) {
      _notice('Official document actions require an approved document.');
      return;
    }
    await showSign2DigitalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.72,
          child: SingleChildScrollView(
            child: GeneralDocumentIssuedActions(
              documentId: d.id!,
              documentNumber: d.number,
              repository: _repository,
              suggestedSignerName: _client(d) == 'Not linked'
                  ? '' : _client(d),
            ),
          ),
        ),
      )),
    );
    if (mounted) await _reload();
  }

  Future<void> _pdf({required bool share}) async {
    final d = _document;
    if (d?.id == null) return;
    if (d!.status != 'approved') {
      _notice('Approve this document before exporting an official PDF.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // issuedPdf independently validates the stored official PDF checksum.
      final bytes = await _repository.issuedPdf(d.id!);
      final filename = 'Sign2Digital_General_' +
          d.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_') + '.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        await FilePicker.saveFile(
          dialogTitle: 'Save official document',
          fileName: filename, bytes: bytes, type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
      }
    } catch (_) {
      _notice('Official PDF is unavailable. Issue it under Document Actions.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _more() {
    if (_document?.status == 'approved' &&
        ActiveCompanySession.canWrite('documents')) {
      _officialActions();
    } else {
      _setTab(0);
      _notice('Available document actions are at the bottom of Details.');
    }
  }

  Widget _topActions() => Row(
    key: const Key('general-document-top-actions'),
    children: [
      for (var i = 0; i < 4; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: Sign2DigitalSignatureActionCard(
          key: Key('general-document-top-action-$i'),
          label: const ['View', 'Download', 'Share', 'More'][i],
          icon: const [Icons.visibility_outlined, Icons.download_outlined,
            Icons.link_outlined, Icons.more_horiz][i],
          selected: _action == i,
          documentStyling: true,
          height: 74,
          onTap: () {
            if (_busy) return;
            setState(() => _action = i);
            switch (i) {
              case 0: _setTab(1); break;
              case 1: _pdf(share: false); break;
              case 2: _pdf(share: true); break;
              case 3: _more(); break;
            }
          },
        )),
      ],
    ],
  );

  Widget _actionButton(String key, String text, VoidCallback onTap,
      {bool primary = false}) => primary
    ? Sign2DigitalPrimaryButton(
        key: Key(key), label: text, enabled: !_busy, onPressed: onTap)
    : Sign2DigitalOutlinedButton(
        key: Key(key), label: text, primaryOutline: true,
        enabled: !_busy, onPressed: onTap);

  /// Paired actions in rows of two; odd final action uses the full row.
  Widget _detailButtons(GeneralDocumentDraft d) {
    if (!ActiveCompanySession.canWrite('documents')) {
      return const SizedBox.shrink();
    }
    final actions = <({String key, String label, VoidCallback onTap,
        bool primary})>[
      if (d.editable)
        (key: 'general-document-action-edit', label: 'Edit Document',
         onTap: _edit, primary: false),
      if (d.status == 'draft')
        (key: 'general-document-action-review', label: 'Mark Reviewed',
         onTap: () => _transition('review'), primary: true),
      if (d.status == 'reviewed')
        (key: 'general-document-action-approve', label: 'Approve Document',
         onTap: () => _transition('approve'), primary: true),
      if (d.status == 'approved')
        (key: 'general-document-action-issue', label: 'Document Actions',
         onTap: _officialActions, primary: true),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('general-document-bottom-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        for (var i = 0; i < actions.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          if (i + 1 < actions.length)
            Row(children: [
              Expanded(child: _actionButton(actions[i].key, actions[i].label,
                  actions[i].onTap, primary: actions[i].primary)),
              const SizedBox(width: 10),
              Expanded(child: _actionButton(actions[i + 1].key,
                  actions[i + 1].label, actions[i + 1].onTap,
                  primary: actions[i + 1].primary)),
            ])
          else
            _actionButton(actions[i].key, actions[i].label,
                actions[i].onTap, primary: actions[i].primary),
        ],
      ],
    );
  }

  Widget _details(GeneralDocumentDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Sign2DigitalInformationTable(
        heading: 'Document Information',
        rows: [
          Sign2DigitalInformationRow('Document Type:',
            _types[d.type] ?? 'Document'),
          Sign2DigitalInformationRow('Document Number:', d.number),
          Sign2DigitalInformationRow('Job', _job(d)),
          Sign2DigitalInformationRow('Client:', _client(d)),
          const Sign2DigitalInformationRow('Created By:', 'Not available'),
          Sign2DigitalInformationRow('Created Date:', _date(d.createdAt)),
          Sign2DigitalInformationRow('Last Update:', 'Not available'),
          Sign2DigitalInformationRow('Version:', 'v' + d.revision.toString()),
          Sign2DigitalInformationRow('Status:', d.status, isStatus: true),
        ],
      ),
      _detailButtons(d),
    ],
  );

  Widget _preview(GeneralDocumentDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Document Content', style: TextStyle(
        fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600,
        color: AppColors.dark)),
      const SizedBox(height: 12),
      Sign2DigitalOutlinedContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < d.blocks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  (d.blocks[i].type == 'bullet' ? '• ' :
                      d.blocks[i].type == 'numbered'
                          ? (i + 1).toString() + '. ' : '') + d.blocks[i].text,
                  key: Key('general-document-text-preview-$i'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: d.blocks[i].type == 'heading' ? 18 : 14,
                    height: 1.5, color: AppColors.dark,
                    fontWeight: d.blocks[i].bold ||
                        d.blocks[i].type == 'heading'
                        ? FontWeight.w600 : FontWeight.w400,
                    fontStyle: d.blocks[i].italic
                        ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text('Preview of saved document content. Official PDFs are '
        'generated and verified separately after approval.',
        style: TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: AppColors.secondaryText)),
    ],
  );

  Widget _related(GeneralDocumentDraft d) =>
      Sign2DigitalInformationTable(
        heading: 'Related Items',
        rows: [
          Sign2DigitalInformationRow('Job', _job(d)),
          Sign2DigitalInformationRow('Client:', _client(d)),
        ],
      );

  Widget _history() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyError != null) {
      return TextButton(
        key: const Key('general-document-history-retry'),
        onPressed: _loadHistory, child: Text(_historyError! + ' Retry'));
    }
    final events = _events ?? [];
    if (events.isEmpty) {
      return const Text('No document history available.',
        style: TextStyle(fontFamily: 'Inter',
          color: AppColors.secondaryText));
    }
    return Sign2DigitalOutlinedContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: [
        for (final event in events) ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text((event['type'] ?? 'Document activity').toString()
              .replaceAll('_', ' '),
            style: const TextStyle(fontFamily: 'Inter',
              fontSize: 14, color: AppColors.dark)),
          subtitle: Text((event['created_at'] ?? '').toString(),
            style: const TextStyle(fontFamily: 'Inter',
              fontSize: 12, color: AppColors.secondaryText)),
        ),
      ]),
    );
  }

  Widget _body(GeneralDocumentDraft d) => SingleChildScrollView(
    key: const Key('general-document-details-scroll'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sign2DigitalQuoteSummaryCard(
            detailsStyle: true, quoteNumber: d.number,
            titleOverride: d.title, projectName: _job(d),
            status: d.status,
          ),
          const SizedBox(height: 20),
          _topActions(),
          const SizedBox(height: 20),
          Stack(children: [
            const Positioned(bottom: 0, left: 0, right: 0,
              child: Divider(height: 1, thickness: 1,
                color: AppColors.lightBorder)),
            Sign2DigitalDetailsTabs(
              labels: _tabs, selectedIndex: _tab, onSelected: _setTab),
          ]),
          const SizedBox(height: 20),
          if (_tab == 0) _details(d)
          else if (_tab == 1) _preview(d)
          else if (_tab == 2) _related(d)
          else _history(),
        ],
      ),
    )),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.light,
    child: Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(child: Column(children: [
        Sign2DigitalHeader(title: 'Documents',
          onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(child: TextButton(onPressed: _reload,
                key: const Key('general-document-details-retry'),
                child: Text(_error! + ' Retry')))
            : _document == null
              ? const Center(child: Text('Document not found.'))
              : _body(_document!)),
      ])),
    ),
  );
}
