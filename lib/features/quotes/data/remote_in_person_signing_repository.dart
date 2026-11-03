import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/quote_review_models.dart';
import '../domain/quote_signature_draft.dart';
import '../domain/quote_signed_display_data.dart';

class RemoteInPersonSession {
  const RemoteInPersonSession({
    required this.id,
    required this.quoteId,
    required this.documentId,
    required this.requestId,
    required this.customerSignerId,
    required this.businessSignerId,
    required this.documentVersion,
    required this.consentReference,
    required this.expiresAt,
  });
  final int id;
  final String quoteId;
  final String documentId;
  final String requestId;
  final String customerSignerId;
  final String businessSignerId;
  final String documentVersion;
  final String consentReference;
  final DateTime expiresAt;
}

/// The session, signer IDs, approved revision and signed PDF are all from
/// Laravel. A local signature draft is never a verified signed document.
class RemoteInPersonSigningRepository {
  RemoteInPersonSigningRepository({SignApiClient? api})
      : _api=api ?? MobileAuthRepository.shared.api;
  static final shared=RemoteInPersonSigningRepository();
  final SignApiClient _api;

  static int _num(Object? v) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static Map<String,dynamic> _data(Map<String,dynamic> result) {
    final data=result['data'];
    if(data is! Map) throw const SignApiException('Invalid signing service response.');
    return Map<String,dynamic>.from(data);
  }
  static String _required(Map<String,dynamic> data,String field) {
    final value=data[field];
    if(value is! String || value.trim().isEmpty) {
      throw SignApiException('Signing response is missing $field.');
    }
    return value;
  }
  static int _company() {
    final company=ActiveCompanySession.companyId;
    if(company==null || company<=0) {
      throw const SignApiException('Select a company before signing.');
    }
    return company;
  }

  Future<RemoteInPersonSession> start(QuoteReviewDraft quote) async {
    if(quote.isDemo || quote.serverId==null || !quote.approvedLocally) {
      throw const SignApiException('Approve the actual quote before signing.');
    }
    final company=_company();
    final result=await _api.post(
      '/api/v1/quotes/' + quote.serverId.toString() + '/in-person-signing',
      data:const {},companyScoped:true,
    );
    if(company!=ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed during signing.');
    }
    final data=_data(result);
    final id=_num(data['request_id']);
    final quoteId=_required(data,'quoteId');
    if(id<=0 || quoteId!=quote.serverId.toString()) {
      throw const SignApiException('In-person session belongs to another quote.');
    }
    final expires=DateTime.tryParse(_required(data,'expiresAt'));
    if(expires==null || expires.isBefore(DateTime.now())) {
      throw const SignApiException('Signing session is already expired.');
    }
    return RemoteInPersonSession(
      id:id, quoteId:quoteId,
      documentId:_required(data,'documentId'),
      requestId:_required(data,'requestId'),
      customerSignerId:_required(data,'customerSignerId'),
      businessSignerId:_required(data,'businessSignerId'),
      documentVersion:_required(data,'documentVersion'),
      consentReference:_required(data,'consentReference'),
      expiresAt:expires,
    );
  }

  Future<QuoteSignedDisplayData?> complete(
    QuoteReviewDraft quote,
    RemoteInPersonSession session,
    QuoteInPersonSignatureSubmission submission,
  ) async {
    if(quote.serverId==null || session.quoteId!=quote.serverId.toString() ||
        submission.quoteId!=quote.id ||
        submission.documentId!=session.documentId ||
        submission.customerSignerId!=session.customerSignerId ||
        submission.businessSignerId!=session.businessSignerId ||
        !submission.consentAccepted ||
        DateTime.now().isAfter(session.expiresAt) ||
        submission.customerStrokes.isEmpty ||
        submission.businessStrokes.isEmpty) {
      throw const SignApiException('The signing session or consent does not match.');
    }
    final company=_company();
    List<List<Map<String,double>>> points(List<List<dynamic>> strokes) => [
      for(final stroke in strokes) [
        for(final point in stroke)
          {'x':(point.dx as double).clamp(0,1).toDouble(),
           'y':(point.dy as double).clamp(0,1).toDouble()},
      ],
    ];
    final response=await _api.post(
      '/api/v1/signature-requests/' + session.id.toString() + '/complete-in-person',
      data:{
        'quoteId':session.quoteId,
        'documentId':session.documentId,
        'requestId':session.requestId,
        'customerSignerId':session.customerSignerId,
        'businessSignerId':session.businessSignerId,
        'documentVersion':session.documentVersion,
        'consentReference':session.consentReference,
        'consentAccepted':true,
        'customerStrokes':points(submission.customerStrokes),
        'businessStrokes':points(submission.businessStrokes),
      },
      companyScoped:true,
    );
    if(company!=ActiveCompanySession.companyId) {
      throw const SignApiException('Company changed during signing.');
    }
    final data=_data(response);
    final bytes=base64Decode(_required(data,'signedPdfBase64'));
    if(bytes.length < 20 || bytes.length > 12*1024*1024 ||
        !String.fromCharCodes(bytes.take(5)).startsWith('%PDF-') ||
        sha256.convert(bytes).toString()!=_required(data,'signedPdfSha256')) {
      throw const SignApiException('The signed PDF failed integrity verification.');
    }
    if(_required(data,'documentId')!=session.documentId ||
        _required(data,'quoteId')!=session.quoteId) {
      throw const SignApiException('The final receipt does not match the quote.');
    }
    final date=DateTime.tryParse(_required(data,'signedAt'));
    if(date==null) throw const SignApiException('Signing date was not confirmed.');
    return QuoteSignedDisplayData(
      documentId:session.documentId,
      quoteId:quote.id,
      jobId:quote.jobId,
      quoteNumber:_required(data,'quoteNumber'),
      projectName:_required(data,'projectName'),
      signerName:_required(data,'signerName'),
      signedAt:date,
      ipAddress:data['ipAddress'] as String?,
      signedPdfBytes:Uint8List.fromList(bytes),
    );
  }
}
