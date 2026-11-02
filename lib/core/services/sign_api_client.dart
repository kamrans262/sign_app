import 'dart:convert';

import 'package:http/http.dart' as http;

/// The deployed Sign2Digital API. Override only for intentional environments.
/// No developer-defined variable is needed for the default test deployment.
abstract final class SignApiConfig {
  static final Uri baseUrl = Uri.parse(
    const String.fromEnvironment(
      'SIGN_API_BASE_URL',
      defaultValue: 'https://forestgreen-pigeon-673192.hostingersite.com',
    ),
  );
}

class SignApiException implements Exception {
  const SignApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SignApiException($statusCode): $message';
}

/// Pure API infrastructure. Screens keep their existing UI/repositories
/// until their module is migrated from demo data to authenticated APIs.
///
/// Tokens are supplied by the authentication module (M2); they are never
/// embedded in the application or persisted by this client.
class SignApiClient {
  SignApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    Future<String?> Function()? tokenProvider,
    int? Function()? activeCompanyId,
  }) : _base = baseUrl ?? SignApiConfig.baseUrl,
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _tokenProvider = tokenProvider,
       _activeCompanyId = activeCompanyId {
    if (_base.scheme != 'https' || _base.host.isEmpty) {
      throw ArgumentError('Sign2Digital API requires an HTTPS base URL.');
    }
  }

  final Uri _base;
  final http.Client _http;
  final bool _ownsHttp;
  final Future<String?> Function()? _tokenProvider;
  final int? Function()? _activeCompanyId;

  Uri _uri(String endpoint) {
    if (!endpoint.startsWith('/') || endpoint.contains('..')) {
      throw ArgumentError('API endpoints must be absolute paths.');
    }
    return _base.replace(
      path: _base.path.replaceAll(RegExp(r"/+$"), "") + endpoint,
      query: null,
      fragment: null,
    );
  }

  Future<Map<String, dynamic>> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
    bool authenticated = true,
    bool companyScoped = false,
  }) async {
    final headers = await _headers(
      authenticated: authenticated,
      companyScoped: companyScoped,
    );
    if (data != null) headers['Content-Type'] = 'application/json';

    final request = http.Request(method, _uri(endpoint));
    request.headers.addAll(headers);
    if (data != null) request.body = jsonEncode(data);

    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response
          .fromStream(streamed)
          .timeout(const Duration(seconds: 20));
      return _decode(response);
    } on SignApiException {
      rethrow;
    } catch (_) {
      throw const SignApiException('Unable to connect to Sign2Digital.');
    }
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool authenticated = true,
    bool companyScoped = false,
  }) => request(
    'GET',
    endpoint,
    authenticated: authenticated,
    companyScoped: companyScoped,
  );

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? data,
    bool authenticated = true,
    bool companyScoped = false,
  }) => request(
    'POST',
    endpoint,
    data: data,
    authenticated: authenticated,
    companyScoped: companyScoped,
  );

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? data,
    bool companyScoped = false,
  }) => request(
    'PUT',
    endpoint,
    data: data,
    companyScoped: companyScoped,
  );

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool companyScoped = false,
  }) => request('DELETE', endpoint, companyScoped: companyScoped);

  Future<Map<String, String>> _headers({
    required bool authenticated,
    required bool companyScoped,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (authenticated) {
      final token = await _tokenProvider?.call();
      if (token == null || token.trim().isEmpty) {
        throw const SignApiException('Authentication is required.', statusCode: 401);
      }
      headers['Authorization'] = 'Bearer $token';
    }
    if (companyScoped) {
      if (!authenticated) {
        throw ArgumentError('Company requests must be authenticated.');
      }
      final id = _activeCompanyId?.call();
      if (id == null || id <= 0) {
        throw const SignApiException('Select a company first.', statusCode: 422);
      }
      headers['X-Company-Id'] = id.toString();
    }
    return headers;
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Expected an object.');
      }
      json = parsed;
    } catch (_) {
      throw SignApiException(
        'Unexpected response from the server.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage = json['message'];
      throw SignApiException(
        rawMessage is String && rawMessage.isNotEmpty
            ? rawMessage
            : 'Request failed.',
        statusCode: response.statusCode,
      );
    }
    return json;
  }

  Future<Map<String, dynamic>> health() =>
      get('/api/health', authenticated: false);

  Future<Map<String, dynamic>> currentAccount() => get('/api/v1/me');

  Future<Map<String, dynamic>> currentCompany() =>
      get('/api/v1/company-context', companyScoped: true);

  void dispose() {
    if (_ownsHttp) _http.close();
  }
}
