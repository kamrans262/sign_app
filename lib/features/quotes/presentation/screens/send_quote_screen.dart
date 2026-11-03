import 'package:flutter/material.dart';
import '../../../documents/data/document_activity_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../domain/quote_document_tracking.dart';
import '../../domain/quote_tracking_home_session.dart';
import '../../domain/quote_review_models.dart';
import '../../data/remote_quote_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../domain/quote_signature_draft.dart';
import '../../domain/quote_signing_context.dart';
import 'document_signed_success_screen.dart';
import '../../services/quote_pdf_service.dart';
import '../widgets/sign2digital_quote_shadow_panel.dart';
import '../widgets/sign2digital_sending_method_card.dart';
import 'signature_request_screen.dart';

/// Opening an email/share chooser does not prove that a quote was delivered.
/// Secure links require a trusted provider, not a locally manufactured URL.
enum QuoteSendingMethod { email, secureLink, other }

class QuoteSendDraft {
  QuoteSendDraft({required this.name, required this.email,
    required this.phone, required this.address, required this.message,
    this.method = QuoteSendingMethod.email, this.pdfAttached = true});

  String name;
  String email;
  String phone;
  String address;
  String message;
  QuoteSendingMethod method;
  bool pdfAttached;

  QuoteSendDraft copy() => QuoteSendDraft(name: name, email: email,
    phone: phone, address: address, message: message,
    method: method, pdfAttached: pdfAttached);
}

/// Session-local changes: does not mutate permanent customer records.
class QuoteSendSessionStore {
  QuoteSendSessionStore._();
  static final Map<String, QuoteSendDraft> _drafts = {};
  static bool _listeningForCompanyChanges = false;
  static void _ensureCompanyIsolation() {
    if (_listeningForCompanyChanges) return;
    _listeningForCompanyChanges = true;
    ActiveCompanySession.selected.addListener(clear);
  }
  static QuoteSendDraft? load(String id) {
    _ensureCompanyIsolation();
    return _drafts[id]?.copy();
  }
  static void save(String id, QuoteSendDraft draft) {
    _ensureCompanyIsolation();
    _drafts[id] = draft.copy();
  }
  static void clear() => _drafts.clear();
}

typedef QuotePdfGenerator = Future<Uint8List> Function(QuoteReviewDraft quote);

class SendQuoteScreen extends StatefulWidget {
  const SendQuoteScreen({super.key, required this.quote,
    this.pdfGenerator, this.secureDocumentUrl, this.secureLinkExpiresAt,
    this.secureLinkDelivery, this.tracking, this.signingContext,
    this.onSubmitSignature, this.onSubmitVerifiedSignature});

  final QuoteReviewDraft quote;
  final QuoteDocumentTracking? tracking;
  final QuoteSigningContext? signingContext;
  final Future<bool> Function(QuoteSignatureDraft)? onSubmitSignature;
  final Future<QuoteSignedDisplayData?> Function(QuoteSignatureDraft)?
      onSubmitVerifiedSignature;
  final QuotePdfGenerator? pdfGenerator;
  /// A genuine HTTPS link returned by a trusted backend, if integrated.
  final String? secureDocumentUrl;
  final DateTime? secureLinkExpiresAt;
  /// Must actually dispatch via a connected delivery service. No fake success.
  final Future<bool> Function(Uri link, QuoteSendDraft draft)? secureLinkDelivery;

  @override
  State<SendQuoteScreen> createState() => _SendQuoteScreenState();
}

class _SendQuoteScreenState extends State<SendQuoteScreen> {
  late final QuoteReviewDraft _quote = widget.quote.copy();
  late QuoteSendDraft _sendDraft;
  late final TextEditingController _messageController;
  Uint8List? _pdfBytes;
  bool _preparing = false;
  bool _busy = false;
  bool _messageEdited = false;
  String? _pdfError;
  String? _serverSecureLink;
  DateTime? _serverLinkExpiresAt;

  static const _border = AppColors.lightBorder;
  static const _hint = AppColors.placeholder;
  static const _infoBlue = Color(0xFFE3ECF0);

  @override
  void initState() {
    super.initState();
    _sendDraft = QuoteSendSessionStore.load(_quote.id) ?? QuoteSendDraft(
      name: _quote.clientName,
      email: _quote.clientEmail,
      phone: _quote.clientPhone,
      address: _quote.billingAddress,
      message: _templateText('professional'),
    );
    // Keep the currently selected quote accessible from the Home tab.
    // Do not invent a delivered or signed event.
    QuoteTrackingHomeSession.remember(_quote);
    final trustedTracking = widget.tracking;
    if (trustedTracking != null && trustedTracking.quoteId == _quote.id) {
      QuoteTrackingHomeSession.rememberVerifiedTracking(trustedTracking);
    }
    _messageController = TextEditingController(text: _sendDraft.message);
    _messageEdited = _sendDraft.message != _templateText('professional');
    if (_sendDraft.pdfAttached) { _preparePdf(); }
  }

  @override
  void dispose() {
    _saveSession();
    _messageController.dispose();
    super.dispose();
  }

  void _saveSession() {
    _sendDraft.message = _messageController.text;
    QuoteSendSessionStore.save(_quote.id, _sendDraft);
  }

  void _notify(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _pdfFilename {
    final cleaned = (_quote.quoteNumber.isEmpty ? 'draft' : _quote.quoteNumber)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'Sign2Digital_Quote_$cleaned.pdf';
  }

  String _templateText(String kind) {
    final firstName = _quote.clientName.trim().split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty ? 'there' : firstName;
    return switch (kind) {
      'short' => 'Hi $greeting,\n\nPlease find your quote ${_quote.quoteNumber} attached.\n\nBest regards,\nSign2Digital',
      'followup' => 'Hi $greeting,\n\nFollowing up on quote ${_quote.quoteNumber}. Please let us know if you have any questions.\n\nBest regards,\nSign2Digital',
      _ => 'Hi $greeting,\n\nPlease find your quote attached.\n\nIf you have any questions please let me know.\n\nBest Regards\nSign2Digital',
    };
  }

  Future<void> _preparePdf() async {
    if (_preparing) { return; }
    setState(() { _preparing = true; _pdfError = null; _pdfBytes = null; });
    try {
      final data = await (widget.pdfGenerator?.call(_quote) ??
          (_quote.serverId != null && _quote.approvedLocally && !_quote.isDemo
              ? RemoteQuoteRepository.shared.fetchApprovedPdf(_quote)
              : const Sign2DigitalQuotePdfBuilder().build(_quote)));
      if (data.isEmpty) { throw StateError('The PDF is empty.'); }
      if (mounted) { setState(() => _pdfBytes = data); }
    } catch (error) {
      if (mounted) {
        setState(() => _pdfError = 'Approved PDF unavailable: $error');
      }
    } finally {
      if (mounted) { setState(() => _preparing = false); }
    }
  }

  void _changeMethod(QuoteSendingMethod method) {
    setState(() => _sendDraft.method = method);
    _saveSession();
  }

  Uri? get _usableLink {
    final text = _serverSecureLink ?? widget.secureDocumentUrl;
    if (text == null) { return null; }
    final link = Uri.tryParse(text.trim());
    if (link == null || link.scheme != 'https' || link.host.isEmpty) { return null; }
    final expiresAt = _serverLinkExpiresAt ?? widget.secureLinkExpiresAt;
    if (expiresAt != null && !DateTime.now().isBefore(expiresAt)) {
      return null;
    }
    return link;
  }

  Future<void> _copyLink() async {
    final link = _usableLink;
    if (link == null) {
      _notify('No valid secure document link is available yet.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link.toString()));
    _notify('Secure link copied.');
  }

  Future<void> _editCustomer() async {
    // The TextFormFields own their controllers. Do not dispose text controllers
    // when showDialog returns: the closing dialog may still be animating.
    final editing = _sendDraft.copy();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<QuoteSendDraft>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Recipient'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: editing.name,
                  decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => editing.name = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: editing.email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder(),
                  ),
                  validator: (value) => RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch((value ?? '').trim())
                      ? null
                      : 'Enter a valid email address',
                  onChanged: (value) => editing.email = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: editing.phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone', border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => editing.phone = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: editing.address,
                  decoration: const InputDecoration(
                    labelText: 'Address', border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => editing.address = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, editing.copy());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) { return; }
    setState(() {
      _sendDraft.name = result.name.trim();
      _sendDraft.email = result.email.trim();
      _sendDraft.phone = result.phone.trim();
      _sendDraft.address = result.address.trim();
    });
    _saveSession();
  }

  Future<void> _chooseTemplate() async {
    final choice = await showModalBottomSheet<String>(context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Message Template')),
          ListTile(title: const Text('Professional quote email'),
              onTap: () => Navigator.pop(ctx, 'professional')),
          ListTile(title: const Text('Short quote message'),
              onTap: () => Navigator.pop(ctx, 'short')),
          ListTile(title: const Text('Follow-up message'),
              onTap: () => Navigator.pop(ctx, 'followup')),
        ])));
    if (!mounted || choice == null) { return; }
    if (_messageEdited) {
      final replace = await showDialog<bool>(context: context, builder: (ctx) =>
        AlertDialog(title: const Text('Replace your message?'),
          content: const Text('Your current message has been edited. Replacing it will discard those changes.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace'))]));
      if (!mounted || replace != true) { return; }
    }
    setState(() {
      _messageController.text = _templateText(choice);
      _messageEdited = false;
    });
    _saveSession();
  }

  Future<void> _send() async {
    if (_busy || _preparing) { return; }
    if (!_quote.approvedLocally || _quote.approvalIssues.isNotEmpty) {
      _notify('Please validate your quote in Review Quote before sharing.');
      return;
    }
    if (MobileAuthRepository.shared.isSignedIn &&
        !_quote.isDemo && _quote.serverId != null &&
        _sendDraft.method != QuoteSendingMethod.other) {
      if (_sendDraft.method == QuoteSendingMethod.email) {
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
            .hasMatch(_sendDraft.email.trim())) {
          _notify('Enter a valid recipient email address.');
          return;
        }
        if (_messageController.text.trim().isEmpty) {
          _notify('Write a message before sending.');
          return;
        }
      }
      // When Attach PDF is selected, the real generated bytes must travel
      // with the email; a link-only API response cannot claim an attachment.
      if (_sendDraft.method == QuoteSendingMethod.email &&
          _sendDraft.pdfAttached && _pdfBytes == null) {
        await _preparePdf();
        if (!mounted) return;
        if (_pdfBytes == null) {
          _notify('Quote PDF could not be generated. Please retry.');
          return;
        }
      }
      setState(() => _busy = true);
      try {
        final response = _sendDraft.method == QuoteSendingMethod.email &&
                _sendDraft.pdfAttached
            ? await RemoteQuoteRepository.shared.shareEmailWithPdf(
                _quote,
                email:_sendDraft.email.trim(),
                message:_messageController.text.trim(),
                pdfBytes:_pdfBytes!,
              )
            : await RemoteQuoteRepository.shared.share(
          _quote,
          method: _sendDraft.method == QuoteSendingMethod.email
              ? 'email' : 'secure_link',
          email: _sendDraft.method == QuoteSendingMethod.email
              ? _sendDraft.email.trim() : null,
          message: _messageController.text.trim(),
        );
        if (!mounted) return;
        if (_sendDraft.method == QuoteSendingMethod.email) {
          if (response['delivered'] == true) {
            DocumentActivitySession.deliveryConfirmed(_quote.id);
            _notify(_sendDraft.pdfAttached
                ? 'Quote email with attached PDF and secure link sent.'
                : 'Quote email with secure link sent successfully.');
          } else {
            _notify('Quote email delivery was not confirmed.');
          }
        } else {
          final link = response['secure_link'];
          if (link is! String || !link.startsWith('https://')) {
            throw const FormatException('No verified secure link returned.');
          }
          _serverSecureLink = link;
          _serverLinkExpiresAt =
              DateTime.tryParse((response['expires_at'] ?? '').toString());
          await Clipboard.setData(ClipboardData(text: link));
          if (mounted) {
            setState(() {});
            _notify('Secure link copied. Send it to the customer to deliver.');
          }
        }
      } catch (error) {
        if (mounted) _notify('Could not share quote: $error');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (_sendDraft.method == QuoteSendingMethod.secureLink) {
      final link = _usableLink;
      if (link == null || widget.secureLinkDelivery == null) {
        _notify('Secure link delivery requires a real connected service.');
        return;
      }
      setState(() => _busy = true);
      try {
        final delivered = await widget.secureLinkDelivery!(link, _sendDraft.copy());
        if (delivered) {
          DocumentActivitySession.deliveryConfirmed(_quote.id);
        }
        _notify(delivered ? 'Secure link delivery confirmed by the service.' :
          'Secure link delivery was not confirmed.');
      } catch (error) { _notify('Could not send secure link: $error'); }
      finally { if (mounted) { setState(() => _busy = false); } }
      return;
    }
    if (_sendDraft.method == QuoteSendingMethod.email) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_sendDraft.email)) {
        _notify('Enter a valid recipient email address.');
        return;
      }
      if (_messageController.text.trim().isEmpty) {
        _notify('Write a message before sending.');
        return;
      }
    }
    if (!_sendDraft.pdfAttached) {
      _notify('Reattach the quote PDF before sharing.');
      return;
    }
    if (_pdfBytes == null) {
      await _preparePdf();
      if (!mounted) { return; }
      if (_pdfBytes == null) { _notify('PDF generation failed. Please retry.'); return; }
    }
    setState(() => _busy = true);
    try {
      if (_sendDraft.method == QuoteSendingMethod.email) {
        // Printing shares a real PDF. It cannot pre-fill the body/recipient of
        // every email app; copy them for manual pasting rather than pretend.
        await Clipboard.setData(ClipboardData(
          text: 'To: ${_sendDraft.email}\n\n${_messageController.text}',
        ));
      }
      await Printing.sharePdf(bytes: _pdfBytes!, filename: _pdfFilename);
      if (_sendDraft.method == QuoteSendingMethod.email) {
        _notify('Choose your email app; recipient and message copied for pasting. Delivery is not confirmed.');
      } else {
        _notify('The device share sheet was opened. Delivery is not confirmed.');
      }
    } catch (error) {
      _notify('Could not open the share workflow: $error');
    } finally { if (mounted) { setState(() => _busy = false); } }
  }

  TextStyle _style(double size, {Color color = AppColors.dark,
      FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: 'Inter', fontSize: size, fontWeight: weight, color: color,
    letterSpacing: -0.3,
  );

  Widget _outlinedAction(String label, VoidCallback action, IconData icon) =>
    SizedBox(height: 34, child: OutlinedButton.icon(onPressed: action,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 9),
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      icon: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label, style: _style(14, color: AppColors.primary))));

  Widget _panel(Widget child) => Sign2DigitalQuoteShadowPanel(
    padding: const EdgeInsets.all(20), child: child);

  Widget _heading(String text, {Widget? trailing}) => Row(children: [
    Expanded(child: Text(text, style: _style(18, weight: FontWeight.w600))),
    if (trailing != null) ...[const SizedBox(width: 7), trailing],
  ]);

  Widget _methods() => LayoutBuilder(builder: (context, constraints) {
    final gap = constraints.maxWidth < 330 ? 8.0 : 15.0;
    return Row(children: [
      Expanded(child: Sign2DigitalSendingMethodCard(
        key: const Key('send-method-email'), label: 'E-mail',
        icon: Icons.chat_bubble_outline,
        selected: _sendDraft.method == QuoteSendingMethod.email,
        onTap: () => _changeMethod(QuoteSendingMethod.email))),
      SizedBox(width: gap),
      Expanded(child: Sign2DigitalSendingMethodCard(
        key: const Key('send-method-link'), label: 'Secure Link',
        icon: Icons.link,
        selected: _sendDraft.method == QuoteSendingMethod.secureLink,
        onTap: () => _changeMethod(QuoteSendingMethod.secureLink))),
      SizedBox(width: gap),
      Expanded(child: Sign2DigitalSendingMethodCard(
        key: const Key('send-method-other'), label: 'Other',
        icon: Icons.more_horiz,
        selected: _sendDraft.method == QuoteSendingMethod.other,
        onTap: () => _changeMethod(QuoteSendingMethod.other))),
    ]);
  });

  Widget _customerRow(IconData icon, String value, {bool divider = true}) =>
    Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 24, color: AppColors.dark),
          const SizedBox(width: 10),
          Expanded(child: Text(value.isEmpty ? 'Not provided' : value,
              style: _style(14, weight: FontWeight.w400,
                color: value.isEmpty ? _hint : AppColors.dark))),
        ])),
      if (divider) const Divider(height: 1, color: _border),
    ]);

  Widget _customer() => _panel(Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('Customer Information', trailing:
          _outlinedAction('Edit', _editCustomer, Icons.edit_outlined)),
      const SizedBox(height: 20),
      _customerRow(Icons.person_outline, _sendDraft.name),
      _customerRow(Icons.mail_outline, _sendDraft.email),
      _customerRow(Icons.call_outlined, _sendDraft.phone),
      _customerRow(Icons.location_on_outlined, _sendDraft.address, divider: false),
    ]));

  Widget _message() => _panel(Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('Message', trailing:
          _outlinedAction('Template', _chooseTemplate, Icons.edit_outlined)),
      const SizedBox(height: 20),
      TextField(
        key: const Key('send-message-input'),
        controller: _messageController,
        minLines: 6,
        maxLines: null,
        onChanged: (_) { _messageEdited = true; _saveSession(); },
        style: _style(16, color: _hint, weight: FontWeight.w400),
        decoration: InputDecoration(
          isDense: false,
          contentPadding: const EdgeInsets.all(20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        ),
      ),
    ]));

  String get _pdfSize {
    if (_pdfBytes == null) { return 'Preparing PDF…'; }
    final length = _pdfBytes!.length;
    if (length < 1024 * 1024) { return '${(length / 1024).toStringAsFixed(1)} KB'; }
    return '${(length / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _assetIcon(String name, IconData fallback,
      {double size = 24, Color color = AppColors.primary,
        bool preserveArtwork = false}) =>
    SvgPicture.asset('assets/icons_2/$name.svg', width: size, height: size,
      colorFilter: preserveArtwork ? null : ColorFilter.mode(color, BlendMode.srcIn),
      errorBuilder: (context, error, stackTrace) => Icon(fallback, size: size, color: color));

  Widget _attachments() => _panel(Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('Attachments'),
      const SizedBox(height: 10),
      if (_sendDraft.pdfAttached)
        Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border)),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _assetIcon('pdf', Icons.picture_as_pdf, color: const Color(0xFFE34B51), preserveArtwork: true),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quote ${_quote.quoteNumber.isEmpty ? 'Draft' : _quote.quoteNumber}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: _style(14, weight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(_pdfError ?? _pdfSize, style: _style(12, color: _hint)),
              ])),
            IconButton(key: const Key('send-remove-attachment'),
              tooltip: 'Remove attachment',
              onPressed: () {setState(() => _sendDraft.pdfAttached = false); _saveSession();},
              icon: const Icon(Icons.close, size: 20)),
          ]))
      else OutlinedButton.icon(
        key: const Key('send-restore-attachment'),
        onPressed: () { setState(() => _sendDraft.pdfAttached = true);
          _saveSession(); _preparePdf(); },
        icon: const Icon(Icons.add), label: const Text('Reattach Quote PDF')),
      if (_pdfError != null && _sendDraft.pdfAttached)
        TextButton(onPressed: _preparePdf, child: const Text('Retry PDF generation')),
    ]));

  Widget _linkBox() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _infoBlue,
      borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      _assetIcon('link', Icons.link),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_usableLink != null ? 'Secure document link' :
              'Secure document link unavailable',
              style: _style(14, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_usableLink?.toString() ??
              'A protected, expiring link requires a connected service.',
            softWrap: true, style: _style(12, color: _hint)),
        ])),
      IconButton(key: const Key('send-copy-link'),
        onPressed: _usableLink == null ? null : _copyLink,
        tooltip: 'Copy secure link',
        icon: _assetIcon('copy', Icons.copy_outlined)),
    ]));

  Widget _content() => Column(crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _methods(),
      const SizedBox(height: 20),
      _customer(),
      const SizedBox(height: 20),
      _message(),
      const SizedBox(height: 20),
      _attachments(),
      const SizedBox(height: 20),
      _linkBox(),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerRight, child: TextButton(
        key: const Key('send-view-tracking'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => SignatureRequestScreen(
            quote: _quote.copy(),
            tracking: widget.tracking?.quoteId == _quote.id
                ? widget.tracking
                : QuoteDocumentTracking(quoteId: _quote.id),
            signingContext: widget.signingContext,
            onSubmitSignature: widget.onSubmitSignature,
            onSubmitVerifiedSignature: widget.onSubmitVerifiedSignature,
          )),
        ),
        child: const Text('View document status'),
      )),
    ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          Sign2DigitalHeader(
            title: 'Send Quote',
            onBack: () {
              _saveSession();
              Navigator.of(context).maybePop();
            },
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                key: const Key('send-quote-scroll'),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _content(),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Sign2DigitalPrimaryButton(
                            key: const Key('send-quote-submit'),
                            label: 'Send',
                            loading: _busy,
                            enabled: !_preparing,
                            onPressed: _send,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
