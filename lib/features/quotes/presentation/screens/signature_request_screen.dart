import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../domain/quote_document_tracking.dart';
import '../../data/remote_signature_request_repository.dart';
import '../../domain/quote_review_models.dart';
import '../../domain/quote_tracking_home_session.dart';
import '../../domain/quote_signature_draft.dart';
import 'document_signed_success_screen.dart';
import '../widgets/sign2digital_document_status_timeline.dart';
import '../widgets/sign2digital_signature_action_card.dart';
import 'customer_document_view_screen.dart';

/// Tracking screen. A share-sheet open does NOT establish a sent/viewed/signed
/// event. Pass verified events obtained from a trusted integration explicitly.
class SignatureRequestScreen extends StatefulWidget {
  const SignatureRequestScreen({
    super.key,
    required this.quote,
    this.tracking,
    this.onResend,
    this.signingContext,
    this.onSubmitSignature,
    this.onSubmitVerifiedSignature,
    this.onNavigationSelected,
    this.selectedTab = 0,
  });

  final QuoteReviewDraft quote;
  final QuoteDocumentTracking? tracking;
  final Future<bool> Function(QuoteDocumentTracking)? onResend;
  final QuoteSigningContext? signingContext;
  final Future<bool> Function(QuoteSignatureDraft)? onSubmitSignature;
  final Future<QuoteSignedDisplayData?> Function(QuoteSignatureDraft)?
      onSubmitVerifiedSignature;
  final ValueChanged<int>? onNavigationSelected;
  final int selectedTab;

  @override
  State<SignatureRequestScreen> createState() => _SignatureRequestScreenState();
}

class _SignatureRequestScreenState extends State<SignatureRequestScreen> {
  late final QuoteReviewDraft _quote = widget.quote.copy();
  late QuoteDocumentTracking _tracking;
  late bool _remindersEnabled;
  bool _resending = false;
  int? _serverRequestId;
  bool _loadingRequest = false;

  static const _border = AppColors.lightBorder;
  static const _info = Color(0xFFE3ECF0);

  @override
  void initState() {
    super.initState();
    _tracking = widget.tracking ?? QuoteDocumentTracking(quoteId: _quote.id);
    _remindersEnabled = QuoteReminderPreferences.getEnabled(_quote.id);
    if (_quote.serverId != null && _quote.approvedLocally && !_quote.isDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemoteRequest());
    }
  }

  /// M8 uses only backend-authoritative signing events and request IDs.
  Future<void> _loadRemoteRequest() async {
    if (_loadingRequest || !mounted) return;
    setState(() => _loadingRequest = true);
    try {
      final result = await RemoteSignatureRequestRepository.shared.latest(_quote);
      if (!mounted) return;
      setState(() {
        _serverRequestId = result?.id;
        _tracking = result?.tracking ?? QuoteDocumentTracking(quoteId: _quote.id);
      });
    } catch (_) {
      if (mounted) _notify('Could not load confirmed signature activity.');
    } finally {
      if (mounted) setState(() => _loadingRequest = false);
    }
  }

  Future<void> _createRequest() async {
    if (_resending || _loadingRequest) return;
    final email = _quote.clientEmail.trim();
    if (email.isEmpty) {
      _notify('A customer email address is required for a signing request.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request customer signature?'),
        content: Text('Create a secure signing link for ${_quote.clientName}? '
            'You can copy it and share it with the customer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create link')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resending = true);
    try {
      final result = await RemoteSignatureRequestRepository.shared.create(
        _quote,
        signerName: _quote.clientName,
        signerEmail: email,
        delivery: 'link',
      );
      if (!mounted) return;
      setState(() {
        _serverRequestId = result.id;
        _tracking = result.tracking;
      });
      _notify('Secure signing link created. Copy it to share with the customer.');
    } catch (error) {
      if (mounted) _notify('Unable to create signature request: $error');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _notify(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Replace an earlier notice instead of queuing it behind a 4-second snackbar.
    // This matters when users tap Copy Link then Resend in quick succession.
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  TextStyle _type(double size, {Color color = AppColors.dark,
    FontWeight weight = FontWeight.w500}) => TextStyle(
      fontFamily: 'Inter', fontSize: size, fontWeight: weight,
      letterSpacing: -0.3, color: color);

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
        .toUpperCase();
  }

  String _formattedDate(DateTime time) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final date = time.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${date.day} ${names[date.month - 1]} ${date.year}, '
        '$hour:${date.minute.toString().padLeft(2, '0')} '
        '${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Uri? get _link => _tracking.usableUrl(DateTime.now());

  Future<void> _copyLink() async {
    Uri? link=_link;
    if(link==null && _serverRequestId!=null && !_loadingRequest && !_resending) {
      setState(() => _loadingRequest=true);
      try {
        final result=await RemoteSignatureRequestRepository.shared.rotateLink(
          _quote,_serverRequestId!,
        );
        if(!mounted)return;
        setState(() => _tracking=result.tracking);
        link=_tracking.usableUrl(DateTime.now());
      } catch(error) {
        if(mounted)_notify('Could not renew signing link: $error');
        return;
      } finally {
        if(mounted)setState(() => _loadingRequest=false);
      }
    }
    if(link==null) {
      _notify('No genuine secure document link is available yet.');
      return;
    }
    await Clipboard.setData(ClipboardData(text:link.toString()));
    _notify('Document link copied.');
  }


  Future<void> _resend() async {
    if (_resending || _loadingRequest) return;
    if (_serverRequestId == null && widget.onResend == null) {
      if (_quote.serverId != null && _quote.approvedLocally && !_quote.isDemo) {
        await _createRequest();
      } else {
        _notify('Resending requires an active request and connected delivery service.');
      }
      return;
    }
    if (!_tracking.requestIsActive && _serverRequestId == null) {
      _notify('Resending requires an active signature request.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resend signature request?'),
        content: Text('Email another signing request to ${_quote.clientName}? '
            'The previous link will stop working.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Resend')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resending = true);
    try {
      if (_serverRequestId != null) {
        final result = await RemoteSignatureRequestRepository.shared.resend(
          _quote, _serverRequestId!,
        );
        if (!mounted) return;
        setState(() {
          _serverRequestId = result.id;
          _tracking = result.tracking;
        });
        _notify('Signature reminder sent and confirmed by the server.');
      } else {
        final delivered = await widget.onResend!(_tracking);
        if (!mounted) return;
        _notify(delivered
            ? 'Resend confirmed by the connected service.'
            : 'The resend was not confirmed.');
      }
    } catch (error) {
      if (mounted) _notify('Could not resend the document: $error');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _verifiedSigned(QuoteSignedDisplayData receipt) {
    // This event is recorded only after a connected signing service returned
    // matching audit/document details; local signature capture is insufficient.
    if (!mounted || (receipt.demoOnly && !_quote.isDemo)) return;
    final now = receipt.signedAt;
    setState(() => _tracking = _tracking.withEvent(QuoteDocumentEvent(
      id: 'signed-${_tracking.requestId}-${now.microsecondsSinceEpoch}',
      type: QuoteDocumentEventType.documentSigned,
      occurredAt: now,
    )));
    QuoteTrackingHomeSession.rememberVerifiedTracking(_tracking);
  }

  void _viewDocument() {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => CustomerDocumentViewScreen(
        quote: _quote.copy(),
        documentTitle: 'Quote',
        tracking: _tracking,
        signingContext: widget.signingContext,
        onSubmitSignature: widget.onSubmitSignature,
        onSubmitVerifiedSignature: widget.onSubmitVerifiedSignature,
        onVerifiedSignature: _verifiedSigned,
      ),
    ));
  }

  void _selectTab(int index) {
    if (index == widget.selectedTab) return;
    final navigator = Navigator.of(context);
    if (widget.onNavigationSelected != null) {
      // Embedded Home tracking is already at the root of the dashboard.
      // Do not pop the dashboard route when switching tabs.
      widget.onNavigationSelected!(index);
    } else if (index == 0) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      _notify('Switch tabs from the main dashboard.');
    }
  }

  Widget _sectionTitle(String title) => Text(title,
    style: _type(18, weight: FontWeight.w600));

  Widget _statusBox() {
    final status = _tracking.statusAt(DateTime.now());
    final message = switch (status) {
      QuoteSignatureStatus.signed =>
        'The document is signed. Check the signed document in the job.',
      QuoteSignatureStatus.expired =>
        'This signing request has expired. A new authorized request is required.',
      QuoteSignatureStatus.awaitingSignature =>
        'The document is awaiting the customer signature.',
      QuoteSignatureStatus.viewed =>
        "The customer has viewed the document. We'll notify you when it's signed.",
      QuoteSignatureStatus.sent =>
        'The document has been sent. A customer view is not confirmed yet.',
      QuoteSignatureStatus.draft =>
        'Document delivery has not been confirmed yet.',
    };
    return Container(
      key: const Key('signature-status-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: _info,
        borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.mail_outline, color: AppColors.primary, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status.label,
              key: const Key('signature-current-status'),
              style: _type(13, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(message,
              style: _type(13, color: AppColors.placeholder,
                  weight: FontWeight.w400)),
          ],
        )),
        IconButton(
          key: const Key('signature-banner-copy'),
          tooltip: 'Copy secure document link',
          onPressed: _link == null && _serverRequestId == null ? null : _copyLink,
          icon: SvgPicture.asset('assets/icons_2/copy.svg',
            width: 22, height: 22,
            colorFilter: const ColorFilter.mode(
              AppColors.primary, BlendMode.srcIn),
            errorBuilder: (ctx, error, stack) => const Icon(
              Icons.copy_outlined, color: AppColors.primary, size: 22)),
        ),
      ]),
    );
  }

  Widget _customer() {
    final name = _quote.clientName.trim().isEmpty
        ? 'Customer not provided' : _quote.clientName.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('Customer'),
      const SizedBox(height: 10),
      Row(children: [
        CircleAvatar(radius: 25, backgroundColor: const Color(0xFFE8ECF0),
          child: Text(_initials(name), style: _type(19,
              color: Colors.white, weight: FontWeight.w600))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: _type(16, weight: FontWeight.w600)),
            if (_quote.clientEmail.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(_quote.clientEmail, softWrap: true,
                style: _type(14, color: AppColors.placeholder)),
            ],
            if (_quote.clientPhone.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(_quote.clientPhone, softWrap: true,
                style: _type(14, color: AppColors.placeholder)),
            ],
          ],
        )),
      ]),
    ]);
  }

  Widget _actions() => LayoutBuilder(builder: (context, constraints) {
    final gap = constraints.maxWidth < 350 ? 8.0 : 15.0;
    return Row(children: [
      Expanded(child: Sign2DigitalSignatureActionCard(
        key: const Key('signature-resend'),
        label: _resending ? 'Working…' :
            (_tracking.requestId == null && _quote.serverId != null &&
                    _quote.approvedLocally && !_quote.isDemo
                ? 'Request Signature' : 'Resend Request'),
        icon: Icons.chat_bubble_outline, onTap: _resend)),
      SizedBox(width: gap),
      Expanded(child: Sign2DigitalSignatureActionCard(
        key: const Key('signature-copy-link'),
        label: 'Copy Link', icon: Icons.link, onTap: _copyLink)),
      SizedBox(width: gap),
      Expanded(child: Sign2DigitalSignatureActionCard(
        key: const Key('signature-view-document'),
        label: 'View document', icon: Icons.description_outlined,
        onTap: _viewDocument)),
    ]);
  });

  Widget _reminders() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Reminders'),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Send Automatic Reminders',
                style: _type(14, weight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('Remind me every 3 days until signed',
                style: _type(12, color: AppColors.placeholder,
                  weight: FontWeight.w400)),
            ],
          )),
          // Keep the preference switch paint-scaled without exceeding its
          // layout constraints (including after hot reload/reassembly).
          SizedBox(
            width: 40,
            height: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Transform.scale(
                    scale: 0.4,
                    child: Switch(
                      key: const Key('signature-reminders-toggle'),
                      value: _remindersEnabled,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) {
                        setState(() => _remindersEnabled = value);
                        QuoteReminderPreferences.setEnabled(_quote.id, value);
                        _notify('Preference saved locally. Automatic reminder delivery requires a connected service.');
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    ],
  );

  Widget _history() {
    final events = _tracking.latestFirst;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('History'),
      const SizedBox(height: 10),
      if (events.isEmpty)
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10)),
          child: Text('No confirmed document activity yet.',
            style: _type(12, color: AppColors.placeholder))),
      for (final event in events) ...[
        Container(
          key: Key('signature-history-${event.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            SvgPicture.asset('assets/icons_2/pdf.svg', width: 24, height: 24,
              errorBuilder: (ctx, error, stack) => const Icon(
                Icons.picture_as_pdf, size: 24, color: Color(0xFFE34B51))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: _type(14, weight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(_formattedDate(event.occurredAt),
                  style: _type(12, color: AppColors.placeholder,
                    weight: FontWeight.w400)),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(title: 'Create Quote',
        onBack: () {
          if (widget.onNavigationSelected != null) {
            widget.onNavigationSelected!(2);
          } else {
            Navigator.of(context).maybePop();
          }
        }),
      Expanded(child: SingleChildScrollView(
        key: const Key('signature-request-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Align(alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_tracking.quoteId != _quote.id) ...[
                Text('Document data does not match this quote.',
                  style: _type(13, color: Colors.red)),
                const SizedBox(height: 12),
              ],
              Sign2DigitalDocumentStatusTimeline(tracking: _tracking),
              const SizedBox(height: 20),
              _statusBox(),
              const SizedBox(height: 20),
              _customer(),
              const SizedBox(height: 20),
              _actions(),
              const SizedBox(height: 20),
              _reminders(),
              const SizedBox(height: 20),
              _history(),
            ]),
          ),
        ),
      )),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedTab,
      onSelected: _selectTab,
    ),
  );
}
