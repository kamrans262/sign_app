import 'dart:typed_data';
import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/quote_review_models.dart';

/// Real M6 quote persistence. Server verifies tenant, RBAC, money and approval.
class RemoteQuoteRepository {
  RemoteQuoteRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final RemoteQuoteRepository shared = RemoteQuoteRepository();
  final SignApiClient _api;

  int _company() {
    final id = ActiveCompanySession.companyId;
    if (id == null || id <= 0) {
      throw const SignApiException('Select a company before creating a quote.');
    }
    return id;
  }
  void _check(int initial) {
    if (ActiveCompanySession.companyId != initial) {
      throw const SignApiException('Company changed while saving the quote.');
    }
  }
  static Map<String, dynamic> _data(Map<String,dynamic> response) {
    final data=response['data'];
    if (data is! Map<String,dynamic>) {
      throw const SignApiException('Invalid quote server response.');
    }
    return data;
  }
  static int _id(Object? x) => x is int ? x : int.tryParse('$x') ?? 0;
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-'
      '${d.month.toString().padLeft(2,'0')}-'
      '${d.day.toString().padLeft(2,'0')}';

  Map<String,dynamic> _body(QuoteReviewDraft q) => {
    if (int.tryParse(q.clientId ?? '') case final int id when id > 0)
      'client_id':id,
    if (int.tryParse(q.jobId ?? '') case final int id when id > 0)
      'job_id':id,
    // Preserve user-edited Quote Number; the server keeps its own immutable reference.
    'quote_number':q.quoteNumber.trim().isEmpty ? null : q.quoteNumber.trim(),
    'client_name':q.clientName.trim(),
    'client_email':q.clientEmail.trim().isEmpty ? null : q.clientEmail.trim(),
    'client_phone':q.clientPhone.trim().isEmpty ? null : q.clientPhone.trim(),
    'billing_address':q.billingAddress.trim(),
    'quote_date':_date(q.date),
    'valid_until':q.validUntil == null ? null : _date(q.validUntil!),
    'currency':q.currency,
    'vat_basis_points':q.vatBasisPoints,
    'deposit_basis_points':q.depositBasisPoints,
    'terms':q.terms,
    'source_method':q.sourceMethod,
    if(q.serverId != null && q.serverRevision != null)
      'expected_revision':q.serverRevision,
    'payment_details':q.payment == null ? null : {
      'iban':q.payment!.iban,
      'accountHolder':q.payment!.accountHolder,
      'street':q.payment!.street,
      'buildingNumber':q.payment!.buildingNumber,
      'postalCode':q.payment!.postalCode,
      'city':q.payment!.city,
      'country':q.payment!.country,
      'paymentReference':q.payment!.paymentReference,
    },
    'items': [
      for(final item in q.items) {
        'title':item.title.trim(),
        'description':item.description.trim(),
        'quantity':item.validQuantity,
        'dimensions':item.dimensions,
        'unit_price_minor':item.priceMinor,
        'other_fields':Map<String,String>.from(item.otherFields),
        'unresolved_fields':item.unresolvedOtherFields.toList(),
      },
    ],
  };

  QuoteReviewDraft _applied(QuoteReviewDraft draft,
      Map<String,dynamic> response,int company) {
    final raw=_data(response)['quote'];
    if (raw is! Map<String,dynamic> ||
        _id(raw['company_id']) != company || _id(raw['id']) <= 0) {
      throw const SignApiException('Invalid or cross-company quote response.');
    }
    if (draft.serverId != null && draft.serverId != _id(raw['id'])) {
      throw const SignApiException('Saved quote identity changed.');
    }
    final copy=draft.copy();
    copy.serverId=_id(raw['id']);
    if (_id(raw['revision']) > 0) {
      copy.serverRevision=_id(raw['revision']);
    }
    copy.quoteNumber=(raw['quote_number'] ?? raw['reference_number'] ?? '').toString();
    copy.serverStatus=(raw['status'] ?? 'draft').toString();
    copy.approvedLocally=
        raw['status']=='approved' || raw['status']=='sent';
    return copy;
  }

  Future<QuoteReviewDraft> saveDraft(QuoteReviewDraft quote) async {
    if (quote.isDemo) {
      throw const SignApiException('Demo quote cannot be saved to the server.');
    }
    final company=_company();
    final id=quote.serverId;
    final result=id == null
        ? await _api.post('/api/v1/quotes',
            data:_body(quote),companyScoped:true)
        : await _api.request('PATCH','/api/v1/quotes/$id',
            data:_body(quote),companyScoped:true);
    _check(company);
    return _applied(quote,result,company);
  }

  Future<QuoteReviewDraft> approve(QuoteReviewDraft quote) async {
    if (quote.isDemo || quote.terms.trim().isEmpty ||
        quote.approvalIssues.any(
          (issue) => issue != 'Quote Number is required.',
        )) {
      throw const SignApiException('Review all fields, pricing and terms first.');
    }
    // The server allocates the immutable real quote number on first save.
    final saved=await saveDraft(quote);
    if (saved.approvalIssues.isNotEmpty) {
      throw const SignApiException('Resolve all quote fields before approval.');
    }
    final company=_company();
    final response=await _api.post(
      '/api/v1/quotes/${saved.serverId}/approve',
      data:{'confirmed':true, if (saved.serverRevision != null) 'expected_revision':saved.serverRevision},companyScoped:true,
    );
    _check(company);
    final approved=_applied(saved,response,company);
    if(!approved.approvedLocally) {
      throw const SignApiException('Quote approval was not confirmed by the server.');
    }
    return approved;
  }

  Future<Map<String,dynamic>> share(QuoteReviewDraft quote, {
    required String method, String? email, String? message,
  }) async {
    final company=_company();
    if (quote.serverId == null || !quote.approvedLocally) {
      throw const SignApiException('Save and approve this quote before sending.');
    }
    if (method != 'email' && method != 'secure_link') {
      throw const SignApiException('Unsupported quote delivery method.');
    }
    final response=await _api.post(
      '/api/v1/quotes/${quote.serverId}/share',
      companyScoped:true,
      data:{'method':method,'recipient_email':email,'message':message},
    );
    _check(company);
    return _data(response);
  }

  /// Sends the actual Flutter-generated, reviewed PDF as an email attachment
  /// alongside the server's independently verifiable quote-view link.
  Future<Map<String,dynamic>> shareEmailWithPdf(
    QuoteReviewDraft quote, {
    required String email,
    required String message,
    required Uint8List pdfBytes,
  }) async {
    final company=_company();
    if (quote.serverId == null || !quote.approvedLocally || quote.isDemo) {
      throw const SignApiException('Approve this quote before attaching a PDF.');
    }
    if (pdfBytes.length < 8 || pdfBytes.length > 5 * 1024 * 1024 ||
        pdfBytes[0] != 37 || pdfBytes[1] != 80 ||
        pdfBytes[2] != 68 || pdfBytes[3] != 70 || pdfBytes[4] != 45) {
      throw const SignApiException('Generate a valid PDF under 5 MB to send.');
    }
    final response=await _api.postMultipart(
      '/api/v1/quotes/${quote.serverId}/share-email-pdf',
      filename:'Sign2Digital_Quote.pdf',
      bytes:pdfBytes,
      maxBytes:5 * 1024 * 1024,
      companyScoped:true,
      fields:{'recipient_email':email.trim(),'message':message.trim()},
    );
    _check(company);
    return _data(response);
  }

  Future<List<QuoteReviewDraft>> listQuotes({String? jobId}) async {
    final company=_company();
    final records=<QuoteReviewDraft>[];
    var page=1;
    while(true) {
      final data=_data(await _api.get(
        '/api/v1/quotes',companyScoped:true,
        queryParameters:{
          'page':'$page','per_page':'100',
          if (int.tryParse(jobId ?? '') case final int id when id > 0)
            'job_id':'$id',
        },
      ));
      _check(company);
      final rows=data['quotes'];
      if (rows is! List) {
        throw const SignApiException('Invalid quote list.');
      }
      for (final item in rows) {
        if (item is! Map<String,dynamic> ||
            _id(item['company_id']) != company) {
          throw const SignApiException('Cross-company quote response.');
        }
        final lines=item['items'];
        if (lines is! List) throw const SignApiException('Missing quote items.');
        String fromMinor(Object? minor) {
          final n=int.tryParse('$minor');
          if(n == null) return '';
          return '${n ~/ 100}.${(n % 100).toString().padLeft(2,'0')}';
        }
        records.add(QuoteReviewDraft(
          id:'server-quote-${item['id']}',
          serverId:_id(item['id']),
          serverRevision:_id(item['revision']) > 0
              ? _id(item['revision']) : null,
          clientId:item['client_id']?.toString(),
          jobId:item['job_id']?.toString(),
          companyId:'$company',
          clientName:(item['client_name'] ?? '').toString(),
          clientEmail:(item['client_email'] ?? '').toString(),
          clientPhone:(item['client_phone'] ?? '').toString(),
          billingAddress:(item['billing_address'] ?? '').toString(),
          quoteNumber:(item['quote_number'] ?? item['reference_number'] ?? '').toString(),
          date:DateTime.tryParse('${item['quote_date']}') ?? DateTime.now(),
          validUntil:DateTime.tryParse('${item['valid_until']}'),
          currency:(item['currency'] ?? 'CHF').toString(),
          vatBasisPoints:_id(item['vat_basis_points']),
          depositBasisPoints:_id(item['deposit_basis_points']),
          terms:(item['terms'] ?? '').toString(),
          sourceMethod:(item['source_method'] ?? 'manual').toString(),
          payment:item['payment_details'] is Map ? QuotePaymentDetails(
            iban: (item['payment_details']['iban'] ?? '').toString(),
            accountHolder: (item['payment_details']['accountHolder'] ?? '').toString(),
            street: (item['payment_details']['street'] ?? '').toString(),
            buildingNumber: (item['payment_details']['buildingNumber'] ?? '').toString(),
            postalCode: (item['payment_details']['postalCode'] ?? '').toString(),
            city: (item['payment_details']['city'] ?? '').toString(),
            country: (item['payment_details']['country'] ?? 'CH').toString(),
            paymentReference: (item['payment_details']['paymentReference'] ?? '').toString(),
          ) : null,
          approvedLocally:item['status']=='approved' || item['status']=='sent',
          serverStatus:(item['status'] ?? 'draft').toString(),
          items:[
            for (final line in lines)
              if(line is Map<String,dynamic>)
                QuoteReviewWorkItem(
                  id:'${line['id']}',
                  title:(line['title'] ?? '').toString(),
                  description:(line['description'] ?? '').toString(),
                  quantity:line['quantity']?.toString() ?? '',
                  unitPrice:fromMinor(line['unit_price_minor']),
                  dimensions:line['dimensions']?.toString(),
                  otherFields:line['other_fields'] is Map
                      ? (line['other_fields'] as Map)
                          .map((k,v)=>MapEntry('$k','$v')) : null,
                  unresolvedOtherFields:line['unresolved_fields'] is List
                      ? (line['unresolved_fields'] as List)
                          .map((v)=>'$v').toSet() : null,
                ),
          ],
        ));
      }
      final pagination=data['pagination'];
      if (pagination is! Map || _id(pagination['last_page']) < page) {
        throw const SignApiException('Invalid quote pagination.');
      }
      if(page == _id(pagination['last_page'])) break;
      if (++page > 10000) {
        throw const SignApiException('Quote pagination limit exceeded.');
      }
    }
    _check(company);
    return List<QuoteReviewDraft>.unmodifiable(records);
  }
}
