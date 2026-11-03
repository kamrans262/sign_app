import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';

class SignedJobDocument {
  const SignedJobDocument({
    required this.id,
    required this.documentId,
    required this.quoteNumber,
    required this.jobId,
    required this.signedAt,
    required this.signedPdfSha256,
  });
  final int id;
  final String documentId;
  final String quoteNumber;
  final String? jobId;
  final DateTime signedAt;
  final String signedPdfSha256;
}

/// Live company-scoped signed job history; no local signing status is trusted.
class RemoteSignedDocumentRepository {
  RemoteSignedDocumentRepository({SignApiClient? api})
      : _api=api ?? MobileAuthRepository.shared.api;
  static final shared=RemoteSignedDocumentRepository();
  final SignApiClient _api;

  int _company() {
    final id=ActiveCompanySession.companyId;
    if(id==null || id<=0) {
      throw const SignApiException('Select a company first.');
    }
    return id;
  }

  Future<List<SignedJobDocument>> list({String? jobId}) async {
    final company=_company();
    final response=await _api.request(
      'GET','/api/v1/signed-documents',
      queryParameters: jobId==null ? null : {'job_id':jobId},
      companyScoped:true,
    );
    if(company!=ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed while loading documents.');
    }
    final data=response['data'];
    if(data is! Map || data['documents'] is! List) {
      throw const SignApiException('Invalid signed document listing.');
    }
    final documents=<SignedJobDocument>[];
    for(final value in data['documents'] as List) {
      if(value is! Map) continue;
      final raw=Map<String,dynamic>.from(value);
      final id=raw['id'] is num ? (raw['id'] as num).toInt()
          : int.tryParse(raw['id'].toString()) ?? 0;
      final date=DateTime.tryParse((raw['signed_at'] ?? '').toString());
      final sha=(raw['signed_pdf_sha256'] ?? '').toString();
      final ref=(raw['document_id'] ?? '').toString();
      if(id<=0 || date==null || sha.length!=64 || ref.isEmpty) {
        throw const SignApiException('Invalid signed document metadata.');
      }
      final actualJobId=raw['job_id']?.toString();
      if(jobId!=null && actualJobId!=jobId) {
        throw const SignApiException('Signed document belongs to another job.');
      }
      documents.add(SignedJobDocument(
        id:id,
        documentId:ref,
        quoteNumber:(raw['quote_number'] ?? '').toString(),
        jobId:actualJobId,
        signedAt:date,
        signedPdfSha256:sha,
      ));
    }
    return documents;
  }

  Future<Uint8List> download(SignedJobDocument document) async {
    final company=_company();
    final bytes=await _api.getPdf(
      '/api/v1/signed-documents/' + document.id.toString() + '/pdf',
      companyScoped:true,maxBytes:12*1024*1024,
    );
    if(company!=ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed while downloading the PDF.');
    }
    if(sha256.convert(bytes).toString()!=document.signedPdfSha256) {
      throw const SignApiException('Signed PDF integrity verification failed.');
    }
    return bytes;
  }
}
