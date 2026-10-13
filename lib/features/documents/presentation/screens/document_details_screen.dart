import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../../quotes/presentation/widgets/sign2digital_signature_action_card.dart';
import '../../../quotes/services/quote_pdf_service.dart';
import '../../domain/document_record.dart';
import '../widgets/sign2digital_document_history.dart';

typedef DocumentDetailsLoader = Future<DocumentRecord?> Function(String id);
typedef DocumentPdfLoader = Future<Uint8List?> Function(DocumentRecord record);

/// Document details and its four tabs. No global bottom navigation.
class DocumentDetailsScreen extends StatefulWidget {
  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
    this.document,
    this.loadDocument,
    this.loadSignedPdf,
    this.onViewSignatures,
    this.initialTab = 0,
  });

  final String documentId;
  final DocumentRecord? document;
  final DocumentDetailsLoader? loadDocument;
  final DocumentPdfLoader? loadSignedPdf;
  final ValueChanged<DocumentHistoryEvent>? onViewSignatures;
  final int initialTab;

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  DocumentRecord? _record;
  String? _loadError;
  bool _denied = false;
  bool _loading = false;
  int _tab = 0;
  int _action = 0;
  Future<Uint8List?>? _pdfFuture;

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
      if (mounted) setState(() { _loading = false; _denied = true; });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false; _loadError = 'Could not load document details.';
      });
    }
  }

  void _message(String value) {
    if (!mounted) { return; }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(value)));
  }

  bool get _signed => _record?.status.toLowerCase() == 'signed';

  Future<Uint8List?> _makePdf(DocumentRecord record) async {
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
    if (record.quote == null) return null;
    return const Sign2DigitalQuotePdfBuilder().build(record.quote!);
  }

  Future<Uint8List?> _pdf(DocumentRecord record) =>
      _pdfFuture ??= _makePdf(record);

  String _filename(DocumentRecord record) =>
      'Sign2Digital_${record.category.name}_${record.number.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';

  Future<void> _doDownload() async {
    final record = _record;
    if (record == null) return;
    setState(() => _action = 1);
    try {
      final bytes = await _pdf(record);
      if (bytes == null) { _message('No document PDF is available.'); return; }
      await FilePicker.saveFile(
        dialogTitle: 'Save document',
        fileName: _filename(record),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
    } catch (_) { _message('Could not export this document PDF.'); }
  }

  Future<void> _doShare() async {
    final record = _record;
    if (record == null) return;
    setState(() => _action = 2);
    try {
      final bytes = await _pdf(record);
      if (bytes == null) { _message('No document PDF is available.'); return; }
      await Printing.sharePdf(bytes: bytes, filename: _filename(record));
    } catch (_) { _message('Could not open the document share sheet.'); }
  }

  void _more() {
    final record = _record;
    if (record == null) return;
    setState(() => _action = 3);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListTile(
          key: const Key('document-copy-reference'),
          leading: const Icon(Icons.copy_outlined),
          title: const Text('Copy document reference'),
          onTap: () async {
            Navigator.pop(sheet);
            await Clipboard.setData(ClipboardData(text: record.number));
            _message('Document reference copied.');
          },
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
  }

  void _view() {
    setState(() { _action = 0; _tab = 1; });
  }

  static const _label = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, color: AppColors.placeholder,
  );
  static const _value = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: -0.3, color: AppColors.dark,
  );

  String _date(DateTime? date) {
    if (date == null) return 'Not available';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _detailsRow(String name, String value, {bool status = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: LayoutBuilder(builder: (context, constraints) {
          final labelWidth = (constraints.maxWidth * .43)
              .clamp(100.0, 180.0).toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: labelWidth,
                child: Text(name, style: _label, softWrap: true)),
              const SizedBox(width: 10),
              Expanded(child: Align(
                alignment: Alignment.centerLeft,
                child: status
                    ? Sign2DigitalStatusBadge(status: value)
                    : Text(value, style: _value, softWrap: true),
              )),
            ],
          );
        }),
      );

  Widget _details(DocumentRecord record) {
    final data = <(String, String)>[
      ('Document Type:', switch (record.category) {
        DocumentCategory.quotes => 'Quote',
        DocumentCategory.contacts => 'Contact',
        DocumentCategory.reports => 'Report',
        DocumentCategory.addends => 'Addend',
      }),
      ('Quote Number:', record.number),
      ('Job', record.project),
      ('Client:', record.customer),
      ('Created By:', record.createdBy ?? 'Not available'),
      ('Created Date:', _date(record.createdAt ?? record.quote?.date)),
      ('Last Update:', _date(record.updatedAt ?? record.timestamp)),
      ('Valid Until:', _date(record.validUntil ?? record.quote?.validUntil)),
      ('Status:', record.status),
    ];
    return Sign2DigitalOutlinedContainer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text('Document Information',
                style: TextStyle(fontFamily: 'Inter', fontSize: 20,
                  fontWeight: FontWeight.w600, color: AppColors.dark)),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < data.length; i++) ...[
              _detailsRow(data[i].$1, data[i].$2, status: i == data.length - 1),
              if (i < data.length - 1)
                const Divider(height: 1, thickness: 1,
                  color: AppColors.lightBorder),
            ],
          ],
        ),
      ),
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
    if (_signed && !record.demoOnly &&
        (!record.verifiedSignedPdfAvailable || widget.loadSignedPdf == null)) {
      return const Text(
        'The verified signed document is not available yet.',
        key: Key('document-signed-pdf-unavailable'),
        style: _label,
      );
    }
    if (record.quote == null && !record.verifiedSignedPdfAvailable) {
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
              child: PdfPreview(
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
              documentId: linked[i].id, document: linked[i],
              loadSignedPdf: widget.loadSignedPdf,
              onViewSignatures: widget.onViewSignatures,
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
      constraints: const BoxConstraints(maxWidth: 720),
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
            document: record, onViewSignatures: widget.onViewSignatures),
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
