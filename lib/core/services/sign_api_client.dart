import 'dart:convert';
import 'dart:typed_data';

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
       // The public named configuration stays stable; internal callbacks stay private.
       // ignore: prefer_initializing_formals
       _tokenProvider = tokenProvider,
       // ignore: prefer_initializing_formals
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

  Uri _uri(String endpoint, {Map<String, String>? queryParameters}) {
    if (!endpoint.startsWith('/') ||
        endpoint.startsWith('//') ||
        endpoint.contains('..') ||
        endpoint.contains('?') ||
        endpoint.contains('#')) {
      throw ArgumentError('API endpoints must be absolute paths without query strings.');
    }
    return _base.replace(
      path: _base.path.replaceAll(RegExp(r"/+$"), "") + endpoint,
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
      fragment: null,
    );
  }

  Future<Map<String, dynamic>> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParameters,
    bool authenticated = true,
    bool companyScoped = false,
  }) async {
    final headers = await _headers(
      authenticated: authenticated,
      companyScoped: companyScoped,
    );
    if (data != null) headers['Content-Type'] = 'application/json';

    final request = http.Request(
      method,
      _uri(endpoint, queryParameters: queryParameters),
    )..followRedirects = false;
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

  /// Fetch authenticated, private PDF bytes without treating them as JSON.
  /// Used for approved quotes so Download/Send uses the frozen document.
  Future<Uint8List> getPdf(String endpoint, {
    bool companyScoped = false,
    int maxBytes = 5 * 1024 * 1024,
  }) async {
    final request = http.Request('GET', _uri(endpoint))
      ..followRedirects = false;
    request.headers.addAll(await _headers(
      authenticated: true, companyScoped: companyScoped,
    ));
    try {
      final streamed = await _http.send(request)
          .timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _decode(response); // Preserve Laravel's useful 409/403/404 response.
        throw SignApiException('Unable to download approved PDF.',
            statusCode: response.statusCode);
      }
      final data = response.bodyBytes;
      if (!(response.headers['content-type'] ?? '')
              .toLowerCase().startsWith('application/pdf') ||
          data.length < 12 || data.length > maxBytes ||
          data[0] != 37 || data[1] != 80 || data[2] != 68 ||
          data[3] != 70 || data[4] != 45 ||
          !latin1.decode(data.sublist(data.length > 4096
              ? data.length - 4096 : 0)).contains('%%EOF')) {
        throw const SignApiException('Invalid approved PDF response.');
      }
      return data;
    } on SignApiException {
      rethrow;
    } catch (_) {
      throw const SignApiException('Unable to download the approved PDF.');
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required String filename,
    required Uint8List bytes,
    bool companyScoped = false,
    int maxBytes = 2 * 1024 * 1024,
    Map<String, String>? fields,
  }) async {
    if (maxBytes <= 0 || maxBytes > 25 * 1024 * 1024 ||
        bytes.isEmpty || bytes.length > maxBytes) {
      throw const SignApiException('The selected file exceeds the allowed size.');
    }
    final request = http.MultipartRequest('POST', _uri(endpoint))
      ..followRedirects = false;
    request.headers.addAll(await _headers(
      authenticated: true, companyScoped: companyScoped,
    ));
    request.files.add(http.MultipartFile.fromBytes(
      'file', bytes, filename: filename,
    ));
    if (fields != null) request.fields.addAll(fields);
    try {
      final streamed = await _http.send(request).timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 25));
      return _decode(response);
    } on SignApiException {
      rethrow;
    } catch (_) {
      throw const SignApiException('Unable to upload this company file.');
    }
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
    bool companyScoped = false,
  }) => request(
    'GET',
    endpoint,
    queryParameters: queryParameters,
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
    // Laravel DELETE endpoints may correctly return an empty 204 response.
    if (response.statusCode == 204) return <String, dynamic>{};
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
