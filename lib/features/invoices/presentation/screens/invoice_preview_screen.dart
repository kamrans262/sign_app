import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../expenses/presentation/widgets/sign2digital_expense_upload_tile.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../quotes/domain/quote_review_models.dart';
import '../../../quotes/presentation/widgets/sign2digital_financial_document_sections.dart';
import '../../domain/invoice_record.dart';
import '../../data/remote_invoice_repository.dart';
import '../../services/invoice_pdf_service.dart';

typedef InvoicePreviewPdfAction = Future<void> Function(
    InvoiceRecord invoice, Uint8List pdf);

/// Uses Quote Preview's actual billing, item, payment and terms widgets.
class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen({
    super.key,
    required this.invoice,
    required this.repository,
    this.selectedNavigationIndex = 4,
    this.onNavigationSelected,
    this.photoSource,
    this.onShare,
    this.onDownload,
  });

  final InvoiceRecord invoice;
  final InvoiceRepository repository;
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  final JobPhotoSource? photoSource;
  final InvoicePreviewPdfAction? onShare, onDownload;

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late InvoiceRecord _record;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _record = widget.invoice;
  }

  @override
  void didUpdateWidget(covariant InvoicePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invoice.id != oldWidget.invoice.id) {
      _record = widget.invoice;
    }
  }

  String get _filename =>
      'Sign2Digital_Invoice_${_record.number.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';

  QuoteReviewDraft get _document {
    final record = _record;
    return QuoteReviewDraft(
      id: record.id,
      jobId: record.jobId,
      clientName: record.clientName,
      quoteNumber: record.number,
      date: record.date,
      validUntil: record.dueDate,
      currency: record.currency,
      vatBasisPoints: record.vatBasisPoints,
      billingAddress: record.billingAddress,
      clientEmail: record.clientEmail,
      clientPhone: record.clientPhone,
      terms: record.terms,
      payment: record.payment ??
          (record.iban.trim().isNotEmpty
              ? QuotePaymentDetails(iban: record.iban)
              : null),
      isDemo: record.demoOnly,
      items: [
        for (var i = 0; i < record.items.length; i++)
          QuoteReviewWorkItem(
            id: 'invoice-line-$i',
            title: record.items[i].description,
            description: record.items[i].description,
            quantity: record.items[i].quantity.toString(),
            unitPrice: record.items[i].unitPriceMinor == null
                ? '' : (record.items[i].unitPriceMinor! / 100)
                    .toStringAsFixed(2),
          ),
      ],
    );
  }

  void _notice(String text) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addPhoto() async {
    if (_busy) { return; }
    final source = widget.photoSource ?? DeviceJobPhotoSource();
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Add Invoice Photo')),
          ListTile(
            key: const Key('invoice-preview-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheet, 'gallery')),
          ListTile(
            key: const Key('invoice-preview-camera'),
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheet, 'camera')),
        ]),
      ),
    );
    if (selection == null || !mounted) { return; }
    setState(() => _busy = true);
    try {
      final selected = selection == 'gallery'
          ? await source.upload()
          : [?await source.camera()];
      final next = [..._record.photos];
      final keys = next.map((photo) => photo.sourceKey).toSet();
      for (final photo in selected) {
        DeviceJobPhotoSource.validate(photo.name, photo.bytes);
        if (keys.add(photo.sourceKey)) { next.add(photo); }
      }
      if (next.length == _record.photos.length) { return; }
      final saved = await widget.repository.updateAttachments(_record.id, next);
      if (!mounted) { return; }
      setState(() => _record = saved);
    } catch (_) {
      _notice('Photo could not be saved. Try again or check permissions.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _removePhoto(int index) async {
    if (_busy) { return; }
    setState(() => _busy = true);
    try {
      final next = [..._record.photos]..removeAt(index);
      final saved = await widget.repository.updateAttachments(_record.id, next);
      if (mounted) { setState(() => _record = saved); }
    } catch (_) {
      _notice('Could not remove the photo.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  bool get _editableAttachments =>
      _record.demoOnly || _record.lifecycleStatus=='draft';

  Widget _photos() => LayoutBuilder(
    builder: (context, bounds) => GridView.builder(
      key: const Key('invoice-preview-photo-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: bounds.maxWidth < 320 ? 1 : 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        mainAxisExtent: 120,
      ),
      itemCount: _record.photos.length + (_editableAttachments ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _record.photos.length) {
          return Sign2DigitalExpenseUploadTile(
            key: const Key('invoice-preview-add-photo'),
            enabled: !_busy, onTap: _addPhoto);
        }
        final file=_record.photos[index];
        if(file.name.toLowerCase().endsWith('.pdf')){
          return SizedBox(
            key:Key('invoice-preview-photo-$index'),
            height:120,
            child:Center(child:Icon(Icons.picture_as_pdf_outlined,
              size:40,color:AppColors.primary)),
          );
        }
        return Sign2DigitalPhotoPreview(
          key: Key('invoice-preview-photo-$index'),
          bytes: file.bytes,
          showDemo: false,
          compactTile: true,
          showRemove: _editableAttachments,
          onRemove: () => _removePhoto(index),
        );
      },
    ),
  );


  Future<void> _pdf({required bool share}) async {
    if(_busy)return;
    setState(()=>_busy=true);
    try{
      final record=_record;
      final bytes=record.demoOnly
          ? await const Sign2DigitalInvoicePdfBuilder().build(record)
          : await (widget.repository is RemoteInvoiceRepository
              ? (widget.repository as RemoteInvoiceRepository).issuedPdf(record.id)
              : Future<Uint8List>.error(
                  StateError('Official invoice API unavailable')));
      if(bytes.isEmpty)throw StateError('PDF is empty');
      if(share){
        if(widget.onShare!=null){
          await widget.onShare!(record,bytes);
        }else{
          await Printing.sharePdf(bytes:bytes,filename:_filename);
        }
        _notice('Share sheet opened; email delivery is not confirmed.');
      }else{
        if(widget.onDownload!=null){
          await widget.onDownload!(record,bytes);
        }else{
          final path=await FilePicker.saveFile(
            dialogTitle:'Save Invoice PDF',fileName:_filename,
            type:FileType.custom,allowedExtensions:['pdf'],bytes:bytes);
          if(path==null)return;
        }
        _notice('Invoice PDF saved.');
      }
    }catch(_){
      _notice('Could not ${share ? 'share' : 'save'} invoice PDF.');
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  void _navigate(int index) {
    if (index == widget.selectedNavigationIndex) { return; }
    final callback = widget.onNavigationSelected;
    if (callback == null) {
      Navigator.of(context).maybePop();
    } else {
      Navigator.of(context).pop();
      callback(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = Sign2DigitalFinancialDocumentSections(
      document: _document,
      documentTitle: 'Invoice',
      dateLabel: 'Due Date:',
      showSignature: false,
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(bottom: false, child: Column(children: [
        Sign2DigitalHeader(
          title: 'Invoice Preview',
          onBack: () => Navigator.of(context).maybePop()),
        Expanded(child: SingleChildScrollView(
          key: const Key('invoice-preview-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sections.invoiceOrQuoteDocument(),
                if (_record.depositPaidMinor > 0 ||
                    _record.receivedMinor > 0 ||
                    _record.amountDueMinor != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight,
                    child: Text(
                      'Deposit paid: ${quoteMoney(_record.depositPaidMinor, _record.currency)}'
                      '   Received: ${quoteMoney(_record.receivedMinor, _record.currency)}'
                      '   Amount due: ${quoteMoney(_record.amountDueMinor, _record.currency)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'Inter',
                        fontSize: 12, color: AppColors.placeholder),
                    )),
                ],
                const SizedBox(height: 20),
                sections.paymentDetails(),
                const SizedBox(height: 20),
                sections.terms(),
                const SizedBox(height: 20),
                _photos(),
                const SizedBox(height: 25),
                Row(children: [
                  Expanded(child: Sign2DigitalOutlinedButton(
                    key: const Key('invoice-preview-share'),
                    label: 'Share', primaryOutline: true,
                    enabled: !_busy && (_record.demoOnly ||
                      const ['approved','sent'].contains(_record.lifecycleStatus)),
          onPressed: () => _pdf(share: true))),
                  const SizedBox(width: 10),
                  Expanded(child: Sign2DigitalPrimaryButton(
                    key: const Key('invoice-preview-download'),
                    label: 'Download PDF',
                    enabled: !_busy && (_record.demoOnly ||
                      const ['approved','sent'].contains(_record.lifecycleStatus)),
          onPressed: () => _pdf(share: false))),
                ]),
              ],
            ),
          )),
        )),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigate),
    );
  }
}
