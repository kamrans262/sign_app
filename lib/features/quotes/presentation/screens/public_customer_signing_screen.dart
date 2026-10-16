import 'package:flutter/material.dart';

import '../../services/public_quote_signing_gateway.dart';
import 'customer_document_view_screen.dart';

/// Public web entry point: a customer opens an opaque link without login.
///
/// An HTTPS API must validate that token and issue a signer/document-version
/// context. The token by itself is not proof of identity or consent.
class PublicCustomerSigningScreen extends StatefulWidget {
  const PublicCustomerSigningScreen({
    super.key,
    required this.token,
    this.gateway,
  });

  final String token;
  final PublicQuoteSigningGateway? gateway;

  @override
  State<PublicCustomerSigningScreen> createState() =>
      _PublicCustomerSigningScreenState();
}

class _PublicCustomerSigningScreenState
    extends State<PublicCustomerSigningScreen> {
  static const _api = String.fromEnvironment(
    'SIGN2DIGITAL_SIGNING_API_BASE_URL',
  );
  late final PublicQuoteSigningGateway? _gateway;
  late final Future<PublicQuoteSigningSession> _load;

  @override
  void initState() {
    super.initState();
    if (widget.gateway != null) {
      _gateway = widget.gateway;
    } else {
      final endpoint = Uri.tryParse(_api);
      _gateway = endpoint != null &&
              endpoint.scheme == 'https' &&
              endpoint.host.isNotEmpty
          ? HttpPublicQuoteSigningGateway(apiBase: endpoint)
          : null;
    }
    _load = _gateway == null
        ? Future<PublicQuoteSigningSession>.error(
            StateError('Public signing is not configured.'),
          )
        : _gateway!.open(widget.token);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<PublicQuoteSigningSession>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              key: Key('public-signing-unavailable'),
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This secure signing link is unavailable or expired. '
                      'Please request a new link from the business.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final session = snapshot.data!;
          return CustomerDocumentViewScreen(
            quote: session.quote,
            tracking: session.tracking,
            documentTitle: 'Quote',
            signingContext: session.signer,
            onSubmitVerifiedSignature: (draft) =>
                _gateway!.submit(widget.token, draft),
          );
        },
      );
}
