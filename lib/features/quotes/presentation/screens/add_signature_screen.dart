import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/services/local_file_selection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/quote_signature_draft.dart';

/// Local signature capture for an already-authorized document. The business
/// shell may show its navigation bar; an external customer link must not.
/// [onSubmit] must perform trusted authorization, document binding, signature
/// storage and confirmation; return true ONLY after submission has succeeded.
class AddSignatureScreen extends StatefulWidget {
  const AddSignatureScreen({
    super.key,
    required this.quoteId,
    required this.documentId,
    required this.requestId,
    required this.signerId,
    required this.documentVersion,
    required this.consentReference,
    required this.termsText,
    this.onSubmit,
    this.showBusinessNavigation = false,
    this.selectedBottomTab = 0,
    this.onTabSelected,
  });

  final String quoteId;
  final String documentId;
  final String requestId;
  final String signerId;
  final String documentVersion;
  final String consentReference;
  final String termsText;
  final Future<bool> Function(QuoteSignatureDraft draft)? onSubmit;
  final bool showBusinessNavigation;
  final int selectedBottomTab;
  final ValueChanged<int>? onTabSelected;

  @override
  State<AddSignatureScreen> createState() => _AddSignatureScreenState();
}

class _AddSignatureScreenState extends State<AddSignatureScreen> {
  static const _ink = AppColors.dark;
  static const _grey = AppColors.placeholder;
  static const _border = Color(0x4DD9E2EA);
  static const _canvas = Color(0x1A8A9AA8);
  final _drawCaptureKey = GlobalKey();
  final _typeCaptureKey = GlobalKey();
  final _uploadCaptureKey = GlobalKey();
  late QuoteSignatureLocalDraft _draft;
  late TextEditingController _name;
  bool _submitting = false;
  bool _uploading = false;
  bool _successfullySubmitted = false;
  String? _error;

  String get _cacheKey => QuoteSignatureDraftSession.key(
    widget.quoteId, widget.documentId, widget.requestId,
  );

  @override
  void initState() {
    super.initState();
    _draft = QuoteSignatureDraftSession.retrieve(_cacheKey) ??
        QuoteSignatureLocalDraft();
    _name = TextEditingController(text: _draft.typedName);
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    _draft.typedName = _name.text;
    QuoteSignatureDraftSession.save(_cacheKey, _draft);
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    if (!_successfullySubmitted) {
      QuoteSignatureDraftSession.save(_cacheKey, _draft);
    }
    _name.removeListener(_onNameChanged);
    _name.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _select(QuoteSignatureMethod method) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_draft.method == method) return;
    setState(() { _draft.method = method; _error = null; });
    QuoteSignatureDraftSession.save(_cacheKey, _draft);
  }

  void _clearActive() {
    setState(() {
      switch (_draft.method) {
        case QuoteSignatureMethod.draw:
          _draft.strokes.clear();
          break;
        case QuoteSignatureMethod.type:
          _name.clear();
          break;
        case QuoteSignatureMethod.upload:
          _draft.uploadBytes = null;
          _draft.uploadName = null;
          break;
      }
      _error = null;
    });
    QuoteSignatureDraftSession.save(_cacheKey, _draft);
  }

  Offset _normal(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _startStroke(Offset localPosition, Size size) {
    setState(() {
      _draft.strokes.add([_normal(localPosition, size)]);
      _error = null;
    });
    QuoteSignatureDraftSession.save(_cacheKey, _draft);
  }

  void _updateStroke(Offset localPosition, Size size) {
    if (_draft.strokes.isEmpty) return;
    setState(() {
      _draft.strokes.last.add(_normal(localPosition, size));
    });
  }

  Widget _drawCanvas() => LayoutBuilder(builder: (context, constraints) {
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    return RawGestureDetector(
      key: const Key('signature-draw-canvas'),
      behavior: HitTestBehavior.opaque,
      // Claim drawing pointers immediately so a vertical stroke cannot
      // accidentally scroll the parent SingleChildScrollView.
      gestures: <Type, GestureRecognizerFactory>{
        EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
          () => EagerGestureRecognizer(),
          (instance) {},
        ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _startStroke(event.localPosition, size),
        onPointerMove: (event) => _updateStroke(event.localPosition, size),
        onPointerUp: (_) => QuoteSignatureDraftSession.save(_cacheKey, _draft),
        onPointerCancel: (_) => QuoteSignatureDraftSession.save(_cacheKey, _draft),
        child: RepaintBoundary(
          key: _drawCaptureKey,
          child: CustomPaint(
            painter: _StrokePainter(_draft.strokes),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  });

  Widget _typeCanvas() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
    child: Column(children: [
      TextField(
        key: const Key('signature-type-input'),
        controller: _name,
        decoration: InputDecoration(
          labelText: 'Type your signature',
          hintText: 'Enter your full name',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        textInputAction: TextInputAction.done,
      ),
      const SizedBox(height: 14),
      Expanded(child: Center(child: RepaintBoundary(
        key: _typeCaptureKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(
            _name.text.trim(),
            key: const Key('signature-type-preview'),
            style: const TextStyle(
              fontFamily: 'cursive', // Platform script until a licensed font is provided.
              fontSize: 42, fontStyle: FontStyle.italic, color: _ink,
            ),
          )),
        ),
      ))),
    ]),
  );

  Future<void> _chooseUpload() async {
    if (_uploading) return;
    setState(() { _uploading = true; _error = null; });
    try {
      final file = await LocalFileSelection.choose(
        extensions: const ['png', 'jpg', 'jpeg'],
      );
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || !isSupportedSignatureImage(bytes)) {
        throw const FormatException('Choose a valid PNG or JPEG image.');
      }
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final width = image.width, height = image.height;
        image.dispose();
        if (width < 10 || height < 10 || width > 6000 || height > 6000) {
          throw const FormatException('Signature image dimensions are invalid.');
        }
      } finally { codec.dispose(); }
      if (!mounted) return;
      setState(() { _draft.uploadBytes = bytes; _draft.uploadName = file.name; });
      QuoteSignatureDraftSession.save(_cacheKey, _draft);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read that signature image.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _uploadCanvas() => Center(child: _draft.uploadBytes == null
      ? InkWell(
          key: const Key('signature-upload-pick'),
          borderRadius: BorderRadius.circular(10),
          onTap: _chooseUpload,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_uploading) const CircularProgressIndicator()
              else const Icon(Icons.upload_file_outlined, size: 34,
                color: AppColors.primary),
              const SizedBox(height: 10),
              const Text('Upload Signature', style: TextStyle(
                fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
                color: AppColors.primary)),
              const SizedBox(height: 6),
              const Text('Choose an image of your signature',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                  color: _grey)),
            ]),
          ),
        )
      : Column(children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(16),
            child: Center(child: RepaintBoundary(
              key: _uploadCaptureKey,
              child: Image.memory(_draft.uploadBytes!,
                fit: BoxFit.contain, gaplessPlayback: true,
                errorBuilder: (_, _, _) => const Text('Image unavailable')),
            )),
          )),
          TextButton(onPressed: _chooseUpload, child: const Text('Replace image')),
        ]));

  Widget _clearButton() => Align(
    alignment: Alignment.bottomRight,
    child: Padding(padding: const EdgeInsets.all(15),
      child: TextButton.icon(
        key: const Key('signature-clear'),
        onPressed: _clearActive,
        icon: SvgPicture.asset('assets/icons_2/arrow-reset.svg',
          width: 20, height: 20,
          colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
        label: const Text('Clear', style: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 16,
          letterSpacing: -0.3, color: AppColors.primary)),
      ),
    ),
  );

  Widget _inputPanel() => Container(
    key: const Key('signature-input-panel'),
    height: 336,
    decoration: BoxDecoration(color: _canvas,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(10)),
    clipBehavior: Clip.antiAlias,
    child: Stack(children: [
      Positioned.fill(bottom: 55, child: switch (_draft.method) {
        QuoteSignatureMethod.draw => _drawCanvas(),
        QuoteSignatureMethod.type => _typeCanvas(),
        QuoteSignatureMethod.upload => _uploadCanvas(),
      }),
      _clearButton(),
    ]),
  );

  Widget _tabs() => SizedBox(width: double.infinity, child: Stack(children: [
    Positioned(left: 0, right: 0, bottom: 0,
      child: Container(height: 1, color: _border)),
    Row(mainAxisSize: MainAxisSize.min, children: [
      for (final method in QuoteSignatureMethod.values) ...[
        if (method != QuoteSignatureMethod.draw) const SizedBox(width: 30),
        InkWell(
          key: Key('signature-tab-${method.name}'),
          onTap: () => _select(method),
          child: Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(
              color: _draft.method == method ? AppColors.primary : Colors.transparent,
              width: 2))),
            child: Text(switch (method) {
              QuoteSignatureMethod.draw => 'Draw',
              QuoteSignatureMethod.type => 'Type',
              QuoteSignatureMethod.upload => 'Upload',
            }, style: TextStyle(
              fontFamily: 'Inter', fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _draft.method == method ? AppColors.primary : _grey)),
          ),
        ),
      ],
    ]),
  ]));

  bool get _validSignature => switch (_draft.method) {
    QuoteSignatureMethod.draw => _draft.strokes.any((stroke) =>
      stroke.length > 1 && _distance(stroke.first, stroke.last) > 0.003 ||
      stroke.length > 2),
    QuoteSignatureMethod.type => _name.text.trim().isNotEmpty,
    QuoteSignatureMethod.upload => _draft.uploadBytes != null &&
      _draft.uploadBytes!.isNotEmpty,
  };

  double _distance(Offset a, Offset b) => (a - b).distance;

  Future<bool> _confirmConsent() async {
    bool accepted = false;
    final result = await showDialog<bool>(context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Confirm agreement'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(child: Text(widget.termsText.isEmpty
                ? 'The document has no terms to accept.' : widget.termsText))),
            CheckboxListTile(
              key: const Key('signature-consent-checkbox'),
              contentPadding: EdgeInsets.zero,
              value: accepted,
              title: const Text('I have read and agree to these terms.'),
              onChanged: (value) => setDialogState(() => accepted = value ?? false),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
            TextButton(
              key: const Key('signature-consent-continue'),
              onPressed: accepted ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('Continue')),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    if (widget.quoteId.trim().isEmpty || widget.documentId.trim().isEmpty ||
        widget.requestId.trim().isEmpty || widget.signerId.trim().isEmpty ||
        widget.documentVersion.trim().isEmpty ||
        widget.consentReference.trim().isEmpty || widget.termsText.trim().isEmpty) {
      _message('A valid signing request and applicable terms are required.');
      return;
    }
    if (!_validSignature) {
      _message('Please add a signature before continuing.');
      return;
    }
    if (!await _confirmConsent() || !mounted) return;
    setState(() => _submitting = true);
    try {
      final captureKey = switch (_draft.method) {
        QuoteSignatureMethod.draw => _drawCaptureKey,
        QuoteSignatureMethod.type => _typeCaptureKey,
        QuoteSignatureMethod.upload => _uploadCaptureKey,
      };
      final boundary = captureKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.attached) {
        throw const FormatException('The signature preview is not ready.');
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null || data.lengthInBytes == 0) {
        throw const FormatException('Unable to export signature.');
      }
      final submission = QuoteSignatureDraft(
        quoteId: widget.quoteId,
        documentId: widget.documentId,
        requestId: widget.requestId,
        signerId: widget.signerId,
        documentVersion: widget.documentVersion,
        consentReference: widget.consentReference,
        method: _draft.method,
        pngBytes: data.buffer.asUint8List(),
        capturedAt: DateTime.now().toUtc(),
        consentAccepted: true,
        typedName: _draft.method == QuoteSignatureMethod.type
          ? _name.text.trim() : null,
        normalizedStrokes: _draft.method == QuoteSignatureMethod.draw
          ? _draft.strokes.map((stroke) => List<Offset>.unmodifiable(stroke)).toList()
          : const [],
      );
      if (widget.onSubmit == null) {
        _message('Signature captured locally. Secure submission is not connected yet.');
        return;
      }
      final accepted = await widget.onSubmit!(submission);
      if (!mounted) return;
      if (accepted) {
        _successfullySubmitted = true;
        QuoteSignatureDraftSession.clear(_cacheKey);
        // The callback is the trusted service boundary for signing completion.
        Navigator.of(context).pop<QuoteSignatureDraft>(submission);
      } else {
        _message('Signature was not submitted. Your draft is preserved.');
      }
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Signature submission failed. Your draft is preserved.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: 'Add Signature',
        onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: LayoutBuilder(builder: (context, viewport) =>
        SingleChildScrollView(
          key: const Key('signature-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight - 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _tabs(),
                  const SizedBox(height: 25),
                  _inputPanel(),
                  const SizedBox(height: 20),
                  Sign2DigitalInfoBanner(
                    iconAsset: 'assets/icons_2/fingerprint.svg',
                    verticalPadding: 10,
                    message: 'By signing, you confirm that you agree to our Terms & Conditions and Services.',
                  ),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ]),
                  const SizedBox(height: 40),
                  Sign2DigitalPrimaryButton(
                    label: 'Confirm Signature',
                    onPressed: _confirm,
                    loading: _submitting,
                  ),
                ],
              ),
            ),
          )),
        ))),
    ])),
    bottomNavigationBar: widget.showBusinessNavigation && widget.onTabSelected != null
      ? Sign2DigitalBottomNavigationBar(
          selectedIndex: widget.selectedBottomTab,
          onSelected: widget.onTabSelected!,
        )
      : null,
  );
}

bool isSupportedSignatureImage(Uint8List bytes) {
  if (bytes.length < 4) return false;
  final png = bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 &&
      bytes[2] == 0x4e && bytes[3] == 0x47 && bytes[4] == 0x0d &&
      bytes[5] == 0x0a && bytes[6] == 0x1a && bytes[7] == 0x0a;
  final jpeg = bytes[0] == 0xff && bytes[1] == 0xd8 &&
      bytes[bytes.length - 2] == 0xff && bytes[bytes.length - 1] == 0xd9;
  return png || jpeg;
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dark
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final first = _scaled(stroke.first, size);
      final path = Path()..moveTo(first.dx, first.dy);
      for (var i = 1; i < stroke.length - 1; i++) {
        final current = _scaled(stroke[i], size);
        final next = _scaled(stroke[i + 1], size);
        path.quadraticBezierTo(current.dx, current.dy,
          (current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
      }
      final last = _scaled(stroke.last, size);
      path.lineTo(last.dx, last.dy);
      canvas.drawPath(path, paint);
    }
  }

  Offset _scaled(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
