import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../quotes/presentation/widgets/sign2digital_signature_draw_canvas.dart';
import '../../domain/expense_record.dart';
import '../../data/remote_expense_repository.dart';
import '../widgets/sign2digital_expense_upload_tile.dart';

typedef ReceiptShare = Future<void> Function(LocalJobPhotoSelection receipt);
typedef ReceiptDownload = Future<bool> Function(LocalJobPhotoSelection receipt);

/// Receipt viewer/editor for the expense's actual attachments.
/// No static demo receipt is substituted for a missing file.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.expense,
    required this.repository,
    this.onExpenseChanged,
    this.photoSource,
    this.canEdit,
    this.onShare,
    this.onDownload,
    this.selectedNavigationIndex = 4,
    this.onNavigationSelected,
    this.initialIndex = 0,
  });

  final ExpenseRecord expense;
  final ExpenseRepository repository;
  final ValueChanged<ExpenseRecord>? onExpenseChanged;
  final JobPhotoSource? photoSource;
  final bool? canEdit;
  final ReceiptShare? onShare;
  final ReceiptDownload? onDownload;
  final int selectedNavigationIndex;
  final ValueChanged<int>? onNavigationSelected;
  final int initialIndex;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late ExpenseRecord _record;
  int _selected = 0;
  bool _busy = false;

  List<LocalJobPhotoSelection> get _attachments => _record.photos;
  bool get _canEdit => widget.canEdit ??
      (_record.demoOnly || _record.status == ExpenseStatus.toReview);
  LocalJobPhotoSelection? get _current =>
      _attachments.isEmpty ? null : _attachments[_selected.clamp(0, _attachments.length - 1).toInt()];

  @override
  void initState() {
    super.initState();
    _record = widget.expense;
    _selected = _attachments.isEmpty ? 0
        : widget.initialIndex.clamp(0, _attachments.length - 1).toInt();
  }

  static bool _pdf(LocalJobPhotoSelection file) =>
      file.name.toLowerCase().endsWith('.pdf');

  static String _fileName(LocalJobPhotoSelection file) {
    final original = file.name.split(RegExp(r'[\\/]')).last;
    final safe = original.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return safe.isEmpty ? 'receipt.png' : safe;
  }

  void _message(String value) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _savePhotos(List<LocalJobPhotoSelection> photos,
      {int? selected}) async {
    if (_busy || !_canEdit) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final saved = _record.copyWith(
        photos: List.unmodifiable(photos),
        updatedAt: now,
        history: [
          ..._record.history,
          ExpenseHistoryEvent(
            id: 'receipt-${now.microsecondsSinceEpoch}',
            title: 'Expense Updated',
            occurredAt: now,
            description: 'Receipt attachments updated locally.',
          ),
        ],
      );
      await widget.repository.updateExpense(saved);
      final confirmed = widget.repository is RemoteExpenseRepository
          ? await (widget.repository as RemoteExpenseRepository).getExpense(saved.id)
          : saved;
      if (!mounted) return;
      setState(() {
        _record = confirmed;
        _selected = confirmed.photos.isEmpty ? 0
            : (selected ?? _selected).clamp(0, confirmed.photos.length - 1).toInt();
      });
      widget.onExpenseChanged?.call(confirmed);
    } catch (_) {
      _message('Could not save receipt changes. No attachments were changed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static void _validate(LocalJobPhotoSelection file) {
    if (_pdf(file)) {
      final bytes = file.bytes;
      if (bytes.length < 5 || bytes.length > DeviceJobPhotoSource.maxBytes ||
          bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 ||
          bytes[3] != 0x46 || bytes[4] != 0x2d) {
        throw const FormatException('Choose a valid PDF up to 20 MB.');
      }
    } else {
      DeviceJobPhotoSource.validate(file.name, file.bytes);
    }
  }

  Future<void> _add() async {
    if (_busy || !_canEdit) return;
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const Key('receipt-pick-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheet).pop('gallery')),
          ListTile(key: const Key('receipt-pick-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheet).pop('camera')),
          ListTile(key: const Key('receipt-pick-pdf'),
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Choose PDF receipt'),
            onTap: () => Navigator.of(sheet).pop('pdf')),
        ],
      )),
    );
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    try {
      List<LocalJobPhotoSelection> chosen = [];
      if (source == 'pdf') {
        final result = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf'],
          allowMultiple: true, withData: true);
        if (result != null) {
          chosen = [
            for (final file in result.files)
              if (file.bytes != null)
                LocalJobPhotoSelection(
                  name: file.name, bytes: file.bytes!,
                  sourceKey: file.path ?? '${file.name}:${file.size}',
                ),
          ];
          if (chosen.length != result.files.length) {
            throw const FormatException('Unable to read every selected PDF.');
          }
        }
      } else {
        final picker = widget.photoSource ?? DeviceJobPhotoSource();
        if (source == 'camera') {
          final photo = await picker.camera();
          chosen = [if (photo != null) photo];
        } else {
          chosen = await picker.upload();
        }
      }
      for (final file in chosen) { _validate(file); }
      if (!mounted || chosen.isEmpty) return;
      final photos = List<LocalJobPhotoSelection>.of(_attachments);
      final keys = photos.map((f) => f.sourceKey).toSet();
      for (final file in chosen) {
        if (keys.add(file.sourceKey)) photos.add(file);
      }
      // Save only if at least one attachment is newly selected.
      if (photos.length == _attachments.length) {
        _message('These receipts are already attached.');
        return;
      }
      setState(() => _busy = false);
      await _savePhotos(photos, selected: photos.length - 1);
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Could not access receipt files. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(int index) async {
    if (_busy || !_canEdit || index >= _attachments.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove receipt?'),
        content: Text('Remove ${_fileName(_attachments[index])} from this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel')),
          TextButton(key: const Key('receipt-confirm-remove'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = List<LocalJobPhotoSelection>.of(_attachments)..removeAt(index);
    await _savePhotos(updated, selected: updated.isEmpty ? 0
        : index <= _selected ? (_selected - 1).clamp(0, updated.length - 1).toInt() : _selected);
  }

  Future<void> _share() async {
    final file = _current;
    if (_busy || file == null) { _message('No receipt available to share.'); return; }
    setState(() => _busy = true);
    try {
      if (widget.onShare != null) {
        await widget.onShare!(file);
      } else if (_pdf(file)) {
        await Printing.sharePdf(bytes: file.bytes, filename: _fileName(file));
      } else {
        // The existing printing integration can share image receipts as PDF.
        // A native image-sharing integration can preserve the image format later.
        final document = pw.Document();
        final photo = pw.MemoryImage(file.bytes);
        document.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(child: pw.Image(photo, fit: pw.BoxFit.contain)),
        ));
        await Printing.sharePdf(bytes: await document.save(),
          filename: '${_fileName(file).replaceAll(RegExp(r'\.[^.]+$'), '')}.pdf');
      }
    } catch (_) {
      _message('Could not open the receipt sharing sheet.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _download() async {
    final file = _current;
    if (_busy || file == null) { _message('No receipt available to download.'); return; }
    setState(() => _busy = true);
    try {
      if (widget.onDownload != null) {
        if (await widget.onDownload!(file)) _message('Receipt saved.');
      } else {
        final path = await FilePicker.saveFile(
          dialogTitle: 'Save receipt',
          fileName: _fileName(file),
          type: FileType.custom,
          allowedExtensions: [_fileName(file).split('.').last.toLowerCase()],
          bytes: file.bytes,
        );
        if (path != null && mounted) _message('Receipt saved.');
      }
    } catch (_) {
      _message('Could not save the receipt. Please try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _preview() {
    final file = _current;
    return LayoutBuilder(builder: (context, box) => Container(
      key: const Key('receipt-preview-panel'),
      width: double.infinity,
      height: (box.maxWidth * 430 / 390).clamp(205.0, 720.0),
      decoration: Sign2DigitalMutedPreviewStyle.decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: file == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_outlined, size: 38,
                    color: AppColors.placeholder),
                  const SizedBox(height: 10),
                  const Text('No receipt attached',
                    key: Key('receipt-preview-empty'),
                    style: TextStyle(fontFamily: 'Inter',
                      fontSize: 14, color: AppColors.placeholder)),
                  if (_canEdit)
                    TextButton(onPressed: _add, child: const Text('Add Photo')),
                ]))
              : _pdf(file)
                  ? PdfPreview(
                      key: const Key('receipt-pdf-preview'),
                      build: (_) async => file.bytes,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      allowPrinting: false,
                      allowSharing: false,
                      maxPageWidth: 550,
                    )
                  : Image.memory(file.bytes,
                      key: const Key('receipt-preview-image'),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('Receipt image could not be displayed.'))),
        ),
      ),
    ));
  }

  Widget _grid() {
    final photos = _attachments;
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth < 240 ? 1 : 2;
      return GridView.builder(
        key: const Key('receipt-thumbnail-grid'),
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 15, mainAxisSpacing: 15,
          childAspectRatio: 188 / 118),
        itemCount: photos.length + (_canEdit ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return Sign2DigitalExpenseUploadTile(
              key: const Key('receipt-add-photo'),
              enabled: !_busy, onTap: _add);
          }
          final selected = index == _selected;
          return Container(
            key: Key('receipt-thumbnail-$index'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected
                  ? AppColors.primary : AppColors.lightBorder,
                width: selected ? 1.5 : 1),
            ),
            child: InkWell(
              onTap: () => setState(() => _selected = index),
              child: _pdf(photos[index])
                  ? Stack(children: [
                      const Center(child: Icon(Icons.picture_as_pdf_outlined,
                        size: 44, color: AppColors.primary)),
                      if (_canEdit) Positioned(top: 0, right: 0,
                        child: IconButton(
                          key: Key('receipt-remove-$index'),
                          onPressed: () => _remove(index),
                          icon: const Icon(Icons.cancel,
                            color: AppColors.primary))),
                    ])
                  : Sign2DigitalPhotoPreview(
                      bytes: photos[index].bytes, showDemo: false,
                      compactTile: true,
                      showRemove: _canEdit && !_busy,
                      onRemove: () => _remove(index),
                    ),
            ),
          );
        },
      );
    });
  }

  void _navigate(int index) {
    if (index == widget.selectedNavigationIndex) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onNavigationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(title: 'Receipt',
        onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
          key: const Key('receipt-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            _preview(),
            const SizedBox(height: 20),
            _grid(),
            const SizedBox(height: 40),
            LayoutBuilder(builder: (context, box) => box.maxWidth < 310
                ? Column(children: [
                    Sign2DigitalOutlinedButton(
                      key: const Key('receipt-share'), label: 'Share',
                      primaryOutline: true,
                      enabled: !_busy, onPressed: _share),
                    const SizedBox(height: 10),
                    Sign2DigitalPrimaryButton(
                      key: const Key('receipt-download'),
                      label: 'Download', enabled: !_busy,
                      onPressed: _download),
                  ])
                : Row(children: [
                    Expanded(child: Sign2DigitalOutlinedButton(
                      key: const Key('receipt-share'), label: 'Share',
                      primaryOutline: true,
                      enabled: !_busy, onPressed: _share)),
                    const SizedBox(width: 10),
                    Expanded(child: Sign2DigitalPrimaryButton(
                      key: const Key('receipt-download'),
                      label: 'Download', enabled: !_busy,
                      onPressed: _download)),
                  ])),
          ],
          ),
        ),
      ),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedNavigationIndex,
      onSelected: _navigate),
  );
}
