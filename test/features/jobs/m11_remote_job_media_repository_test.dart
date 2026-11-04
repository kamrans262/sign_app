import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign2digital/core/services/active_company_session.dart';
import 'package:sign2digital/core/services/sign_api_client.dart';
import 'package:sign2digital/features/jobs/data/remote_job_media_repository.dart';
import 'package:sign2digital/features/jobs/data/local_job_photo_source.dart';
import 'package:sign2digital/features/jobs/domain/job_photo_model.dart';

void main() {
  setUp(() => ActiveCompanySession.set(7));
  tearDown(() => ActiveCompanySession.clear());

  SignApiClient client(Future<http.Response> Function(http.Request) handler) =>
      SignApiClient(
        baseUrl: Uri.parse('https://example.test'),
        tokenProvider: () async => 'test-token',
        activeCompanyId: () => ActiveCompanySession.companyId,
        httpClient: MockClient(handler),
      );

  test('notes use active tenant token and never show another job', () async {
    final api = client((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['X-Company-Id'], '7');
      expect(request.url.path, '/api/v1/jobs/51/notes');
      return http.Response(jsonEncode({'data': {'notes': [
        {
          'id': 8, 'company_id': 7, 'job_id': 51,
          'type': 'text', 'visibility': 'private', 'has_audio': false,
          'title': 'Note', 'body': 'Measured on site',
          'created_at': '2026-11-04T14:00:00Z',
        }
      ]}}), 200, headers: {'content-type':'application/json'});
    });
    final notes = await RemoteJobMediaRepository(api: api).listNotes('51');
    expect(notes.single.title, 'Note');
    expect(notes.single.audioPath, null);
    api.dispose();
  });

  test('photo integrity checked after authenticated private download', () async {
    final png = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRzcAAAAASUVORK5CYII='));
    final digest = sha256.convert(png).toString();
    final api = client((request) async {
      expect(request.headers['X-Company-Id'], '7');
      if (request.url.path.endsWith('/file')) {
        return http.Response.bytes(png, 200, headers: {'content-type':'image/png'});
      }
      return http.Response(jsonEncode({'data': {'photos': [
        {
          'id': 5, 'company_id': 7, 'job_id': 51,
          'category':'before','caption':'Entry','title':'Entry',
          'mime_type':'image/png','sha256':digest,
          'created_at':'2026-11-04 12:00:00',
        }
      ]}}), 200, headers: {'content-type':'application/json'});
    });
    final photos = await RemoteJobMediaRepository(api: api).listPhotos('51');
    expect(photos.single.id, '5');
    expect(photos.single.category, JobPhotoCategory.before);
    expect(photos.single.bytes, png);
    api.dispose();
  });

  test('upload ties file and category to the real job and tenant', () async {
    final png = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRzcAAAAASUVORK5CYII='));
    final digest = sha256.convert(png).toString();
    final api = client((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/jobs/51/photos');
      expect(request.headers['X-Company-Id'], '7');
      return http.Response(jsonEncode({'data': {'photo': {
        'id': 12, 'job_id': 51, 'company_id': 7,
        'category':'during', 'sha256':digest,
      }}}), 201, headers: {'content-type':'application/json'});
    });
    final saved = await RemoteJobMediaRepository(api: api).uploadPhoto(
      '51', LocalJobPhotoSelection(
        name:'entry.png', bytes: png, sourceKey:'entry.png'),
      JobPhotoCategory.during, 'Entrance');
    expect(saved.id, '12');
    expect(saved.caption, 'Entrance');
    api.dispose();
  });
}
