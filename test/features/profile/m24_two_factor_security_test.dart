import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/profile/data/remote_security_access_repository.dart';
import 'package:sign2digital/features/profile/presentation/screens/two_factor_setup_screen.dart';
import 'package:sign2digital/features/profile/presentation/screens/two_factor_proof_screen.dart';

void main() {
  testWidgets('QR enrollment requires server code and presents one-time recovery codes',
      (tester) async {
    final seen = <String>[];
    final repo = RemoteSecurityAccessRepository(api: SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        seen.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path == '/api/v1/me/2fa/setup') {
          expect(body['password'], 'MyPassword@262');
          return http.Response(jsonEncode({'data': {
            'secret': 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
            'otpauth_uri': 'otpauth://totp/Sign2Digital%3Atest?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=Sign2Digital',
            'expires_in': 600,
          }}), 200);
        }
        if (request.url.path == '/api/v1/me/2fa/confirm') {
          expect(body['code'], '345678');
          return http.Response(jsonEncode({'data': {
            'enabled': true,
            'recovery_codes': List.generate(10,
                (i) => 'AAAA-BBBB-CCCC-${i.toString().padLeft(4, '0')}'),
          }}), 200);
        }
        throw StateError('Unexpected request');
      }),
    ));
    await tester.pumpWidget(MaterialApp(
      home: TwoFactorSetupScreen(
        repository: repo, password: 'MyPassword@262'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byKey(const Key('m24-setup-secret')), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '345678');
    await tester.ensureVisible(find.byKey(const Key('m24-setup-enable')));
    await tester.tap(find.byKey(const Key('m24-setup-enable')));
    await tester.pumpAndSettle();
    expect(find.text('Save Your Recovery Codes'), findsOneWidget);
    expect(find.byKey(const Key('m24-recovery-copy')), findsOneWidget);
    expect(seen, ['/api/v1/me/2fa/setup', '/api/v1/me/2fa/confirm']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disable requires code and never updates the toggle optimistically',
      (tester) async {
    final repo = RemoteSecurityAccessRepository(api: SignApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/me/2fa/disable');
        final body = jsonDecode(request.body) as Map<String,dynamic>;
        expect(body['password'], 'MyPassword@262');
        if (body['code'] != '123456') {
          return http.Response(jsonEncode({'message': 'Invalid authenticator code.'}), 422);
        }
        return http.Response(jsonEncode({'data': {'enabled': false}}), 200);
      }),
    ));
    await tester.pumpWidget(MaterialApp(
      home: TwoFactorProofScreen(
        repository: repo, password: 'MyPassword@262', regenerate: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Confirm 2FA Removal'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.byKey(const Key('m24-manage-confirm')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
