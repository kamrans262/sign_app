import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../../quotes/presentation/widgets/sign2digital_signature_action_card.dart';
import '../../../quotes/domain/quote_review_models.dart' show quoteMoney;
import '../../../quotes/services/quote_pdf_service.dart';
import '../../../quotes/presentation/widgets/sign2digital_financial_document_sections.dart';
import '../../../quotes/presentation/screens/send_quote_screen.dart';
import '../../data/document_activity_session.dart';
import '../../domain/document_record.dart';
import '../../domain/addendum_draft.dart';
import '../../domain/addendum_signature_request.dart';
import '../../services/addendum_pdf_service.dart';
import 'create_addendum_screen.dart';
import '../widgets/sign2digital_document_history.dart';

typedef DocumentDetailsLoader = Future<DocumentRecord?> Function(String id);
typedef DocumentPdfLoader = Future<Uint8List?> Function(DocumentRecord record);
typedef DocumentPdfPreviewBuilder = Widget Function(Uint8List bytes);
typedef DocumentAttachmentLoader = Future<Uint8List> Function(
    DocumentRecord document, DocumentAttachmentReference attachment);
typedef DocumentFileAction = Future<void> Function(
    DocumentRecord record, String name, Uint8List bytes);
typedef DocumentVersionAction = Future<DocumentRecord> Function(
    DocumentRecord record, String name, Uint8List bytes);

/// Document details and its four tabs. No global bottom navigation.
class DocumentDetailsScreen extends StatefulWidget {
  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
    this.document,
    this.loadDocument,
    this.loadSignedPdf,
    this.onAddAttachment,
    this.onDownloadAttachment,
    this.onAddVersion,
    this.pdfPreviewBuilder,
    this.onViewSignatures,
    this.requestAddendumSignature,
    this.onApproveAddendum,
    this.initialTab = 0,
  });

  final String documentId;
  final DocumentRecord? document;
  final DocumentDetailsLoader? loadDocument;
  final DocumentPdfLoader? loadSignedPdf;
  final DocumentFileAction? onAddAttachment;
  final DocumentAttachmentLoader? onDownloadAttachment;
  final DocumentVersionAction? onAddVersion;
  /// Optional renderer for isolated widget tests; normal UI uses PdfPreview.
  final DocumentPdfPreviewBuilder? pdfPreviewBuilder;
  final ValueChanged<DocumentHistoryEvent>? onViewSignatures;
  final AddendumSignatureRequestService? requestAddendumSignature;
  final Future<DocumentRecord> Function(DocumentRecord)? onApproveAddendum;
  final int initialTab;

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

/// Existing Sign2Digital bottom-sheet controls, not a new screen.
class _AddendumApprovalConfirmation extends StatefulWidget {
  const _AddendumApprovalConfirmation({
    required this.draft, required this.onConfirmed,
  });
  final AddendumDraft draft;
  final VoidCallback onConfirmed;

  @override
  State<_AddendumApprovalConfirmation> createState() =>
      _AddendumApprovalConfirmationState();
}

class _AddendumApprovalConfirmationState
    extends State<_AddendumApprovalConfirmation> {
  bool _confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Review Addendum',
        style: TextStyle(fontFamily: 'Inter', fontSize: 18,
          fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(height: 14),
      Text(widget.draft.number, style: const TextStyle(fontFamily: 'Inter',
        fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(widget.draft.title),
      const SizedBox(height: 8),
      Text(widget.draft.description),
      if (widget.draft.hasPricedWork) ...[
        const SizedBox(height: 8),
        Text('Additional work: ${widget.draft.additionalWork}'),
        Text('Quantity: ${widget.draft.quantity}'),
      ],
      const SizedBox(height: 8),
      Text('Total: ${quoteMoney(
        widget.draft.totalMinor, widget.draft.currency)}'),
      const SizedBox(height: 12),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _confirmed,
        activeColor: AppColors.primary,
        title: const Text(
          'I reviewed and approve this exact separate addendum.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
        onChanged: (checked) =>
            setState(() => _confirmed = checked ?? false),
      ),
      Sign2DigitalPrimaryButton(
        key: const Key('addendum-confirm-approval'),
        label: 'Approve Addendum',
        enabled: _confirmed,
        onPressed: widget.onConfirmed,
      ),
    ],
  );
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  DocumentRecord? _record;
  String? _loadError;
  bool _denied = false;
  bool _loading = false;
  int _tab = 0;
  int _action = 0;
  Future<Uint8List?>? _pdfFuture;
  List<DocumentHistoryEvent> _extraHistory = const [];
  bool _requestingAddendum = false;

  static const tabs = ['Details', 'Preview', 'Related', 'History'];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3).toInt();
    _record = widget.document?.id == widget.documentId ? widget.document : null;
    if (_record == null && widget.loadDocument != null) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.loadDocument == null) return;
    setState(() { _loading = true; _loadError = null; _denied = false; });
    try {
      final data = await widget.loadDocument!(widget.documentId);
      if (!mounted) { return; }
      setState(() {
        _record = data?.id == widget.documentId ? data : null;
        _loading = false;
        _pdfFuture = null;
      });
    } on DocumentPermissionDeniedException {
      if (mounted) { setState(() { _loading = false; _denied = true; }); }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false; _loadError = 'Could not load document details.';
        });
      }
    }
  }

  void _message(String value) {
    if (!mounted) { return; }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(value)));
  }

  bool get _signed => _record?.status.toLowerCase() == 'signed';

  /// Only authoritative catalog quotes use the read-only fallback.
  /// Locally composed quotes may have numeric IDs too.
  bool _needsReadOnlyQuotePreview(DocumentRecord record) {
    if (record.demoOnly || record.verifiedSignedPdfAvailable) return false;
    final match = RegExp(r'^quote-([1-9][0-9]*)$').firstMatch(record.id);
    if (match == null) return false;
    final serverId = int.parse(match.group(1)!);
    return record.quote?.serverId == serverId ||
        (record.quote == null && widget.loadDocument != null);
  }

  Future<Uint8List?> _makePdf(DocumentRecord record) async {
    // A saved/approved/signed M10 addendum must use the exact server PDF,
    // never a newly rendered local preview of the frozen original.
    if (!record.demoOnly && record.verifiedSignedPdfAvailable &&
        widget.loadSignedPdf != null) {
      final pdf = await widget.loadSignedPdf!(record);
      if (pdf == null || pdf.isEmpty) {
        throw const FormatException('Verified document PDF is unavailable.');
      }
      return pdf;
    }
    if (record.category == DocumentCategory.addends &&
        record.addendumDraftId != null) {
      final draft = AddendumDraftSession.load(record.addendumDraftId!);
      if (draft == null || !draft.isCreatedLocally) {
        return null;
      }
      final originals = record.related.where(
        (source) => source.id == draft.linkedDocumentId &&
            source.category != DocumentCategory.addends,
      ).toList();
      if (originals.length != 1) {
        throw const FormatException('Original addendum reference is missing.');
      }
      return const AddendumPdfService().build(draft, originals.single);
    }
    if (record.reportKind == ReportKind.workAcceptance) {
      if (record.demoOnly) return null;
      return record.workAcceptance?.verifiedReportPdf;
    }
    if (record.status.toLowerCase() == 'signed' && !record.demoOnly) {
      if (!record.verifiedSignedPdfAvailable || widget.loadSignedPdf == null) {
        throw const FormatException('Verified signed PDF is not available.');
      }
      final pdf = await widget.loadSignedPdf!(record);
      if (pdf == null || pdf.isEmpty) {
        throw const FormatException('Verified signed PDF is not available.');
      }
      return pdf;
    }
    // An M6 draft/legacy quote may have saved structured data but no
    // immutable approved file. Its in-app preview must never be exported as
    // the original customer-approved or signed PDF.
    if (_needsReadOnlyQuotePreview(record)) {
      throw const FormatException(
        'No verified approved PDF is available for this quote.');
    }
    if (record.quote == null) return null;
    return const Sign2DigitalQuotePdfBuilder().build(record.quote!);
  }

  Future<Uint8List?> _pdf(DocumentRecord record) =>
      _pdfFuture ??= _makePdf(record);

  String _filename(DocumentRecord record) =>
      'Sign2Digital_${record.category.name}_${record.number.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';

  bool _isUnapprovedServerAddendum(DocumentRecord record) {
    if (record.category != DocumentCategory.addends ||
        record.verifiedSignedPdfAvailable) return false;
    final draft = AddendumDraftSession.load(record.addendumDraftId ?? '');
    return draft?.serverId != null;
  }

  Future<void> _doDownload() async {
    final record = _record;
    if (record == null) return;
    if (_isUnapprovedServerAddendum(record)) {
      _message('This is an unsigned draft preview. Approve the addendum '
          'before downloading an official PDF.');
      return;
    }
    if (_needsReadOnlyQuotePreview(record)) {
      _message('No verified quote PDF exists. The Preview tab shows '
          'saved quote details only.');
      return;
    }
    setState(() => _action = 1);
    try {
      final bytes = await _pdf(record);
      if (bytes == null) { _message('No document PDF is available.'); return; }
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save document',
        fileName: _filename(record),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (savedPath != null && mounted && !record.demoOnly) {
        DocumentActivitySession.downloaded(record.id);
        final existingIds = record.history.map((event) => event.id).toSet();
        setState(() => _extraHistory = DocumentActivitySession
            .forDocument(record.id)
            .where((event) => !existingIds.contains(event.id))
            .toList());
      }
    } catch (_) { _message('Could not export this document PDF.'); }
  }

  Future<void> _doShare() async {
    final record = _record;
    if (record == null) return;
    if (_isUnapprovedServerAddendum(record)) {
      _message('This is an unsigned draft preview. Approve the addendum '
          'before sharing an official PDF.');
      return;
    }
    if (_needsReadOnlyQuotePreview(record)) {
      _message('No verified quote PDF exists. The Preview tab shows '
          'saved quote details only.');
      return;
    }
    setState(() => _action = 2);
    try {
      final bytes = await _pdf(record);
      if (bytes == null) { _message('No document PDF is available.'); return; }
      await Printing.sharePdf(bytes: bytes, filename: _filename(record));
    } catch (_) { _message('Could not open the document share sheet.'); }
  }

  Future<void> _approveAddendum() async {
    final record = _record;
    final action = widget.onApproveAddendum;
    final draft = AddendumDraftSession.load(record?.addendumDraftId ?? '');
    if (record == null || action == null || draft == null ||
        draft.serverId == null || draft.serverStatus != 'draft' ||
        _requestingAddendum) {
      _message('A saved server addendum draft is required for approval.');
      return;
    }
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          // Viewing the sheet is not approval; the user must check consent.
          child: _AddendumApprovalConfirmation(
            draft: draft,
            onConfirmed: () => Navigator.pop(sheet, true),
          ),
        ),
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _requestingAddendum = true);
    try {
      final latest = await action(record);
      if (!mounted) return;
      setState(() {
        _record = latest;
        _pdfFuture = null;
      });
      _message('Addendum approved and original PDF frozen securely.');
    } catch (_) {
      _message('Could not approve addendum. Reload and review again.');
    } finally {
      if (mounted) setState(() => _requestingAddendum = false);
    }
  }

  Future<void> _sendAddendumForSignature() async {
    final record = _record;
    if (record == null || _requestingAddendum) return;
    final service = widget.requestAddendumSignature;
    if (service == null) {
      _message('Sending an addendum for signature requires a connected '
          'verified signing service.');
      return;
    }
    final id = record.addendumDraftId;
    final draft = id == null ? null : AddendumDraftSession.load(id);
    if (draft == null || !draft.isCreatedLocally ||
        draft.validationIssues.isNotEmpty) {
      _message('Create and review the addendum before requesting signature.');
      return;
    }
    final sources = record.related.where((source) =>
        source.id == draft.linkedDocumentId &&
        source.category != DocumentCategory.addends).toList();
    if (sources.length != 1) {
      _message('The original reference is missing or has changed.');
      return;
    }
    setState(() => _requestingAddendum = true);
    try {
      final response = await service(draft, sources.single);
      if (!mounted) return;
      if (response == null) {
        _message('Signing request was not confirmed by the service.');
        return;
      }
      AddendumSignatureRequestSession.remember(draft, sources.single, response);
      if (!mounted) return;
      final link = response.secureUrl.toString();
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheet) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Addendum Signature Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('Addendum: ${draft.number}'),
            Text('Original document: ${sources.single.number}'),
            Text('Status: ${response.status}',
              key: const Key('addendum-signature-request-status')),
            const SizedBox(height: 10),
            const Text('The customer must sign the separate addendum. '
              'The original signed document remains unchanged.'),
            const SizedBox(height: 10),
            SelectableText(link),
            TextButton.icon(
              key: const Key('addendum-copy-secure-link'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!sheet.mounted) return;
                ScaffoldMessenger.of(sheet).showSnackBar(
                  const SnackBar(content: Text('Secure link copied. '
                    'Copying does not confirm delivery.')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy secure link'),
            ),
          ]),
        )),
      );
    } catch (_) {
      if (mounted) {
        _message('Could not confirm the addendum signing request.');
      }
    } finally {
      if (mounted) setState(() => _requestingAddendum = false);
    }
  }

  Future<void> _addDocumentFile({required bool newVersion}) async {
    final record = _record;
    if (record == null) return;
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: newVersion
            ? ['pdf'] : ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (selection == null || selection.files.isEmpty || !mounted) return;
      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Selected file could not be read.');
      }
      if (newVersion) {
        if (widget.onAddVersion == null) return;
        await widget.onAddVersion!(record, file.name, bytes);
      } else {
        if (widget.onAddAttachment == null) return;
        await widget.onAddAttachment!(record, file.name, bytes);
      }
      if (!mounted) return;
      _pdfFuture = null;
      if (widget.loadDocument != null) {
        await _load();
      }
      _message(newVersion
          ? 'New PDF version was saved.'
          : 'Attachment added. Original PDF unchanged.');
    } catch (_) {
      _message(newVersion
          ? 'Unable to upload document version.'
          : 'Unable to add document attachment.');
    }
  }

  Future<void> _saveAttachment(
      DocumentRecord record, DocumentAttachmentReference attachment) async {
    final loader = widget.onDownloadAttachment;
    if (loader == null) return;
    try {
      final bytes = await loader(record, attachment);
      if (!mounted) return;
      final extension = switch (attachment.mimeType) {
        'application/pdf' => 'pdf',
        'image/png' => 'png',
        _ => 'jpg',
      };
      final cleaned = attachment.name.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]'), '_');
      final filename = cleaned.toLowerCase().endsWith('.$extension')
          ? cleaned : 'Sign2Digital_Attachment_${attachment.id}.$extension';
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save attachment',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );
      if (saved != null) {
        _message('Attachment saved.');
      }
    } catch (_) {
      _message('Unable to download this attachment.');
    }
  }

  Future<void> _chooseAttachment() async {
    final record = _record;
    if (record == null || record.attachments.isEmpty ||
        widget.onDownloadAttachment == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Attachments', style: TextStyle(
                  fontFamily: 'Inter', fontWeight: FontWeight.w600,
                  fontSize: 18, color: AppColors.dark,
                )),
              ),
              for (final attachment in record.attachments)
                ListTile(
                  key: Key('document-attachment-${attachment.id}'),
                  leading: const Icon(Icons.download_outlined),
                  title: Text(attachment.name),
                  onTap: () {
                    Navigator.pop(sheet);
                    _saveAttachment(record, attachment);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _more() {
    final record = _record;
    if (record == null) return;
    setState(() => _action = 3);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (record.category == DocumentCategory.quotes &&
              record.quote?.approvedLocally == true &&
              record.status.toLowerCase() != 'signed' &&
              !record.demoOnly)
            ListTile(
              key: const Key('document-send-quote'),
              leading: const Icon(Icons.send_outlined),
              title: const Text('Send Quote'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => SendQuoteScreen(
                    quote: record.quote!.copy()),
                ));
              },
            ),
          if (record.category == DocumentCategory.addends &&
              record.status.toLowerCase() == 'draft' &&
              RegExp(r'^addendum-[1-9][0-9]*$').hasMatch(record.id) &&
              widget.onApproveAddendum != null)
            ListTile(
              key: const Key('addendum-edit-server-draft'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Addendum Draft'),
              onTap: () async {
                Navigator.pop(sheet);
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CreateAddendumScreen(
                      draftId: record.id,
                      linkedDocument: record.related.firstWhere(
                        (item) => item.id.startsWith('signed-'),
                      ),
                    ),
                  ),
                );
                if (mounted && widget.loadDocument != null) {
                  await _load();
                }
              },
            ),
          if (record.category == DocumentCategory.addends &&
              record.status.toLowerCase() == 'draft' &&
              RegExp(r'^addendum-[1-9][0-9]*$').hasMatch(record.id) &&
              widget.onApproveAddendum != null)
            ListTile(
              key: const Key('addendum-approve'),
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Review and Approve Addendum'),
              onTap: () {
                Navigator.pop(sheet);
                _approveAddendum();
              },
            ),
          if (record.category == DocumentCategory.addends &&
              AddendumDraftSession.load(record.addendumDraftId ?? '')
                  ?.isCreatedLocally == true &&
              (AddendumDraftSession.load(record.addendumDraftId ?? '')
                      ?.serverId == null ||
                  ['approved','sent'].contains(record.status.toLowerCase())))
            ListTile(
              key: const Key('addendum-send-for-signature'),
              leading: const Icon(Icons.draw_outlined),
              title: const Text('Send for Signature'),
              onTap: () {
                Navigator.pop(sheet);
                _sendAddendumForSignature();
              },
            ),
          if (widget.onDownloadAttachment != null &&
              record.attachments.isNotEmpty)
            ListTile(
              key: const Key('document-download-attachment'),
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download Attachment'),
              onTap: () {
                Navigator.pop(sheet);
                _chooseAttachment();
              },
            ),
          if (widget.onAddAttachment != null &&
              RegExp(r'^(quote|signed|managed)-').hasMatch(record.id))
            ListTile(
              key: const Key('document-add-attachment'),
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('Add Attachment'),
              onTap: () {
                Navigator.pop(sheet);
                _addDocumentFile(newVersion: false);
              },
            ),
          if (widget.onAddVersion != null &&
              record.id.startsWith('managed-'))
            ListTile(
              key: const Key('document-add-version'),
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Add PDF Version'),
              onTap: () {
                Navigator.pop(sheet);
                _addDocumentFile(newVersion: true);
              },
            ),
          if (record.category == DocumentCategory.quotes &&
              (widget.loadDocument == null ||
                  record.id.startsWith('signed-') &&
                      record.verifiedSignedPdfAvailable))
            ListTile(
              key: const Key('document-create-addendum'),
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Create Addendum'),
              onTap: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => CreateAddendumScreen(
                    linkedDocument: record),
                ));
              },
            ),
          ListTile(
          key: const Key('document-copy-reference'),
          leading: const Icon(Icons.copy_outlined),
          title: const Text('Copy document reference'),
          onTap: () async {
            Navigator.pop(sheet);
            await Clipboard.setData(ClipboardData(text: record.number));
            _message('Document reference copied.');
          },
        ),
        ]),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
  }

  bool _historyCanPreview(DocumentRecord record) {
    if (record.category == DocumentCategory.addends &&
        record.addendumDraftId != null) {
      return AddendumDraftSession.load(record.addendumDraftId!)
              ?.isCreatedLocally == true;
    }
    if (record.reportKind == ReportKind.workAcceptance) {
      return !record.demoOnly &&
          (record.workAcceptance?.verifiedReportPdf?.isNotEmpty ?? false);
    }
    if (record.status.toLowerCase() == 'signed' && !record.demoOnly) {
      return record.verifiedSignedPdfAvailable &&
          widget.loadSignedPdf != null;
    }
    return record.quote != null ||
        (record.verifiedSignedPdfAvailable && widget.loadSignedPdf != null);
  }

  void _view() {
    setState(() { _action = 0; _tab = 1; });
  }

  static const _label = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, color: AppColors.placeholder,
  );

  String _date(DateTime? date) {
    if (date == null) return 'Not available';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _details(DocumentRecord record) {
    final data = <(String, String)>[
      ('Document Type:', switch (record.category) {
        DocumentCategory.quotes => 'Quote',
        DocumentCategory.contacts => 'Contact',
        DocumentCategory.reports => 'Report',
        DocumentCategory.addends => 'Addendum',
        DocumentCategory.receipts => 'Receipt',
        DocumentCategory.invoices => 'Invoice',
        DocumentCategory.other => 'Other',
      }),
      (switch (record.category) {
        DocumentCategory.addends => 'Addendum Number:',
        DocumentCategory.reports => 'Report Number:',
        DocumentCategory.receipts => 'Receipt Number:',
        DocumentCategory.invoices => 'Invoice Number:',
        DocumentCategory.other || DocumentCategory.contacts =>
          'Document Number:',
        DocumentCategory.quotes => 'Quote Number:',
      }, record.number),
      ('Job', record.project),
      ('Client:', record.customer),
      ('Created By:', record.createdBy ?? 'Not available'),
      ('Created Date:', _date(record.createdAt ?? record.quote?.date)),
      ('Last Update:', _date(record.updatedAt ?? record.timestamp)),
      if (!record.demoOnly) ('Version:', 'v${record.version}'),
      if (!record.demoOnly && record.attachmentNames.isNotEmpty)
        ('Attachments:', record.attachmentNames.join(', ')),
      ('Valid Until:', _date(record.validUntil ?? record.quote?.validUntil)),
      ('Status:', record.status),
    ];
    return Sign2DigitalInformationTable(
      heading: 'Document Information',
      rows: [
        for (var i = 0; i < data.length; i++)
          Sign2DigitalInformationRow(data[i].$1, data[i].$2,
            isStatus: i == data.length - 1),
      ],
    );
  }

  Widget _actions() => Row(
    key: const Key('document-detail-actions'),
    children: [
      for (var i = 0; i < 4; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: Sign2DigitalSignatureActionCard(
            key: Key('document-action-$i'),
            label: ['View', 'Download', 'Share', 'More'][i],
            icon: [
              Icons.visibility_outlined, Icons.download_outlined,
              Icons.link_outlined, Icons.more_horiz,
            ][i],
            selected: _action == i,
            documentStyling: true,
            height: 74,
            onTap: [ _view, _doDownload, _doShare, _more ][i],
          ),
        ),
      ],
    ],
  );

  Widget _preview(DocumentRecord record) {
    // Existing M6 drafts and legacy approved quotes without frozen PDF bytes
    // can still display their current saved fields using the approved
    // Sign2Digital Quote Preview styling. This is NOT a signed/approved PDF.
    if (_needsReadOnlyQuotePreview(record)) {
      final quote = record.quote;
      if (quote == null) {
        return const Text(
          'The saved quote preview is unavailable for this account.',
          key: Key('document-quote-preview-unavailable'),
          style: _label,
        );
      }
      final isDraft = record.status.toLowerCase() == 'draft';
      return Column(
        key: const Key('document-read-only-quote-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              isDraft
                  ? 'DRAFT PREVIEW — saved quote details, not an approved PDF.'
                  : 'UNVERIFIED QUOTE PREVIEW — the original approved PDF '
                    'is unavailable. These are saved quote details, not '
                    'the original approved or signed document.',
              key: const Key('document-quote-preview-notice'),
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 12,
                fontWeight: FontWeight.w500, color: AppColors.primary,
              ),
            ),
          ),
          Sign2DigitalFinancialDocumentSections(
            document: quote, showSignature: false,
          ).invoiceOrQuoteDocument(),
        ],
      );
    }
    if (_signed && !record.demoOnly &&
        (!record.verifiedSignedPdfAvailable || widget.loadSignedPdf == null)) {
      return const Text(
        'The verified signed document is not available yet.',
        key: Key('document-signed-pdf-unavailable'),
        style: _label,
      );
    }
    final hasWorkAcceptancePdf =
        record.reportKind == ReportKind.workAcceptance &&
        !record.demoOnly &&
        (record.workAcceptance?.verifiedReportPdf?.isNotEmpty ?? false);
    final addendumReady = record.category == DocumentCategory.addends &&
        record.addendumDraftId != null &&
        AddendumDraftSession.load(record.addendumDraftId!)?.isCreatedLocally ==
            true;
    if (record.quote == null &&
        !record.verifiedSignedPdfAvailable &&
        !hasWorkAcceptancePdf && !addendumReady) {
      return const Text('No document preview is available.', style: _label);
    }
    return FutureBuilder<Uint8List?>(
      future: _pdf(record),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load the PDF preview.', style: _label);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Text('No document preview is available.', style: _label);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (record.demoOnly)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'DEMO PDF — not a verified signed document.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                    color: AppColors.primary),
                ),
              ),
            SizedBox(
              height: 480,
              child: widget.pdfPreviewBuilder?.call(bytes) ?? PdfPreview(
                key: const Key('document-pdf-preview'),
                build: (_) async => bytes,
                allowPrinting: false,
                allowSharing: false,
                canChangeOrientation: false,
                canChangePageFormat: false,
                useActions: false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _related(DocumentRecord record) {
    final linked = record.related.where((item) => item.id != record.id).toList();
    if (linked.isEmpty) {
      return const Text('No related documents are available.',
        key: Key('document-related-empty'), style: _label);
    }
    return Column(children: [
      for (var i = 0; i < linked.length; i++) ...[
        Sign2DigitalQuoteSummaryCard(
          quoteNumber: linked[i].number,
          titleOverride: linked[i].title,
          projectName: linked[i].project,
          customerName: linked[i].customer,
          status: linked[i].status,
          documentDate: linked[i].timestamp,
          listStyle: true,
          onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(
            builder: (_) => DocumentDetailsScreen(
              documentId: linked[i].id,
              document: widget.loadDocument != null &&
                      (linked[i].id.startsWith('quote-') &&
                              !linked[i].verifiedSignedPdfAvailable ||
                          linked[i].id.startsWith('addendum-'))
                  ? null : linked[i],
              loadDocument: widget.loadDocument,
              loadSignedPdf: widget.loadSignedPdf,
              onAddVersion: widget.onAddVersion,
              onAddAttachment: widget.onAddAttachment,
              onDownloadAttachment: widget.onDownloadAttachment,
              onViewSignatures: widget.onViewSignatures,
              onApproveAddendum: widget.onApproveAddendum,
              requestAddendumSignature: widget.requestAddendumSignature,
            ),
          )),
        ),
        if (i < linked.length - 1) const SizedBox(height: 20),
      ],
    ]);
  }

  Widget _body(DocumentRecord record) => SingleChildScrollView(
    key: const Key('document-details-scroll'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Center(child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth:
          MediaQuery.sizeOf(context).width >= 900 ? double.infinity : 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sign2DigitalQuoteSummaryCard(
            detailsStyle: true,
            quoteNumber: record.number,
            titleOverride: record.title,
            projectName: record.project,
            status: record.status,
          ),
          const SizedBox(height: 20),
          if (_tab != 3) ...[
            _actions(),
            const SizedBox(height: 20),
          ],
          Stack(children: [
            const Positioned(
              bottom: 0, left: 0, right: 0,
              child: Divider(height: 1, thickness: 1,
                color: AppColors.lightBorder),
            ),
            Sign2DigitalDetailsTabs(
              labels: tabs, selectedIndex: _tab,
              onSelected: _selectTab,
            ),
          ]),
          SizedBox(height: _tab == 3 ? 25 : 20),
          if (_tab == 0) _details(record)
          else if (_tab == 1) _preview(record)
          else if (_tab == 2) _related(record)
          else Sign2DigitalDocumentHistory(
            document: record,
            onViewSignatures: widget.onViewSignatures,
            onOpenDocument: _selectTab,
            canPreview: _historyCanPreview(record),
            additionalEvents: _extraHistory),
        ],
      ),
    )),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: Column(
      children: [
        Sign2DigitalHeader(title: 'Documents',
          onBack: () => Navigator.of(context).maybePop()),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  key: Key('document-details-loading')))
              : _denied
                  ? const Center(child: Text('Permission denied for this document.'))
                  : _loadError != null
                      ? Center(child: TextButton(
                          key: const Key('document-details-retry'),
                          onPressed: _load, child: Text('$_loadError Retry')))
                      : _record == null
                          ? const Center(child: Text('Document not found.',
                              key: Key('document-details-missing')))
                          : _body(_record!),
        ),
      ],
    )),
  );
}
