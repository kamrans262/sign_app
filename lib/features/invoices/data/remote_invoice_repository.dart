import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../jobs/data/local_job_photo_source.dart';
import '../../jobs/data/remote_job_repository.dart';
import '../../jobs/domain/job_model.dart';
import '../../quotes/domain/quote_review_models.dart';
import '../domain/invoice_record.dart';

/// M17: server-led invoice records, never demo data for authenticated users.
class RemoteInvoiceRepository extends InvoiceRepository {
  RemoteInvoiceRepository({SignApiClient? api})
      : _api=api??MobileAuthRepository.shared.api;
  static final shared=RemoteInvoiceRepository();
  final SignApiClient _api;

  int _company(){
    final c=ActiveCompanySession.companyId;
    if(c==null||c<1)throw const SignApiException('Select a company first.');
    return c;
  }
  void _check(int c){
    if(ActiveCompanySession.companyId!=c){
      throw const SignApiException('Company changed during invoice request.');
    }
  }
  static Map<String,dynamic> _map(Object? raw){
    if(raw is! Map)throw const SignApiException('Invalid invoice response.');
    return Map<String,dynamic>.from(raw);
  }
  static Map<String,dynamic> _data(Map<String,dynamic> raw)=>_map(raw['data']);
  static int _int(Object? raw)=>raw is int?raw:int.tryParse('$raw')??0;
  static DateTime _date(Object? raw){
    final d=DateTime.tryParse('$raw');
    if(d==null)throw const SignApiException('Invalid invoice date.');
    return d;
  }
  static int _id(String s){
    final match=RegExp(r'^invoice-([1-9]\d*)$').firstMatch(s);
    if(match==null)throw const SignApiException('Invalid invoice ID.');
    return int.parse(match.group(1)!);
  }
  static int? _fileId(String s){
    final match=RegExp(r'^invoice-attachment-([1-9]\d*)$').firstMatch(s);
    return match==null?null:int.parse(match.group(1)!);
  }
  InvoiceRecord _record(Object? raw,int company,{
    List<InvoiceLineItem> items=const [],
    List<InvoicePaymentRecord> payments=const [],
    List<InvoiceHistoryEvent> history=const [],
    List<LocalJobPhotoSelection> photos=const [],
  }){
    final row=_map(raw);
    final id=_int(row['id']),job=_int(row['job_id']);
    final total=_int(row['total_minor']),version=_int(row['lock_version']);
    final status=switch(row['status']){
      'draft'=>InvoiceStatus.draft,
      'approved'=>InvoiceStatus.pending,
      'pending'=>InvoiceStatus.pending,
      'sent'=>InvoiceStatus.sent,
      'partially_paid'=>InvoiceStatus.partiallyPaid,
      'paid'=>InvoiceStatus.paid,
      'overdue'=>InvoiceStatus.overdue,
      'void'=>InvoiceStatus.voided,
      _=>throw const SignApiException('Invalid invoice lifecycle.'),
    };
    if(id<1||job<1||total<1||version<1||
        row['currency']!='CHF'||_int(row['company_id'])!=company){
      throw const SignApiException('Invalid or cross-company invoice.');
    }
    return InvoiceRecord(
      id:'invoice-$id',number:(row['number']??'').toString(),
      project:(row['job']??'').toString(),jobId:'$job',
      clientName:(row['client_name']??'').toString(),
      amount:total/100.0,date:_date(row['invoice_date']),
      dueDate:_date(row['due_date']),
      status:status,demoOnly:false,
      currency:'CHF',iban:(row['iban']??'').toString(),
      notes:(row['notes']??'').toString(),
      terms:(row['terms']??'').toString(),
      vatBasisPoints:_int(row['vat_basis_points']),
      depositPaidMinor:_int(row['deposit_paid_minor']),
      billingAddress:(row['billing_address']??'').toString(),
      clientEmail:(row['client_email']??'').toString(),
      clientPhone:(row['client_phone']??'').toString(),
      lockVersion:version,invoiceType:(row['type']??'final').toString(),
      lifecycleStatus:(row['lifecycle_status']??'draft').toString(),
      sourceQuoteId:row['quote_id']==null?null:_int(row['quote_id']),
      sourceAddendaIds:[
        if(row['source_addenda_ids'] is List)
          for(final raw in row['source_addenda_ids'] as List)_int(raw),
      ],
      sentAt:row['sent_at']==null?null:_date(row['sent_at']),
      items:items,payments:payments,history:history,photos:photos,
      payment:QuotePaymentDetails(iban:(row['iban']??'').toString()),
    );
  }

  @override
  Future<List<InvoiceRecord>> listInvoices() async {
    final company=_company(),out=<InvoiceRecord>[];
    var page=1;
    while(true){
      final data=_data(await _api.get('/api/v1/invoices',
        companyScoped:true,
        queryParameters:{'page':'$page','per_page':'100'}));
      _check(company);
      if(data['records'] is! List){
        throw const SignApiException('Invalid invoice listing.');
      }
      out.addAll((data['records'] as List).map((r)=>_record(r,company)));
      final last=_int(data['last_page']);
      if(last<1||last>100||page>last){
        throw const SignApiException('Invalid invoice pagination.');
      }
      if(page==last)break;
      page++;
    }
    return out;
  }

  Future<List<JobModel>> jobs() async {
    final company=_company();
    final rows=await RemoteJobRepository.shared.listJobs();
    _check(company);
    return rows.where((x)=>x.category!=JobCategory.archived).toList();
  }

  Future<Map<String,dynamic>> sources(int job) async {
    final company=_company();
    final data=_data(await _api.get('/api/v1/jobs/$job/invoice-sources',
      companyScoped:true));
    _check(company);
    if(_int(data['job_id'])!=job||data['currency']!='CHF'||
        data['quotes'] is! List||data['addenda'] is! List||
        data['completed_work'] is! List){
      throw const SignApiException('Invalid approved invoice sources.');
    }
    return data;
  }

  Future<Map<String,dynamic>> _availability(int job) async {
    final company=_company();
    final data=_data(await _api.get(
      '/api/v1/jobs/$job/invoice-deposits',companyScoped:true));
    _check(company);
    if(_int(data['job_id'])!=job||data['currency']!='CHF'||
        data['allocation_policy']!='whole_deposits_once'||
        _int(data['available_minor'])<0){
      throw const SignApiException('Invalid deposit credit summary.');
    }
    return data;
  }

  Future<int> availableDeposits(int job) async =>
      _int((await _availability(job))['available_minor']);

  /// Mirrors the server's whole-deposit, oldest-first allocation policy.
  /// Total available is not the same as credit that fits an invoice.
  Future<List<int>> availableDepositCandidates(int job) async {
    final data=await _availability(job);
    final raw=data['deposit_candidates'];
    if(raw is! List){
      throw const SignApiException('Missing deposit allocation candidates.');
    }
    final ids=<int>{},amounts=<int>[];
    var total=0;
    for(final item in raw){
      final row=_map(item);
      final id=_int(row['id']),amount=_int(row['amount_minor']);
      if(id<1||amount<1||!ids.add(id)){
        throw const SignApiException('Invalid invoice deposit allocation.');
      }
      amounts.add(amount);
      total+=amount;
    }
    if(total!=_int(data['available_minor'])){
      throw const SignApiException('Deposit allocation summary mismatch.');
    }
    return amounts;
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<InvoiceRecord> invoiceDetail(String identifier) async {
    final company=_company(),id=_id(identifier);
    final data=_data(await _api.get('/api/v1/invoices/$id',
      companyScoped:true));
    _check(company);
    if(data['items'] is! List||data['payments'] is! List||
        data['history'] is! List||data['attachments'] is! List){
      throw const SignApiException('Incomplete invoice detail response.');
    }
    final items=<InvoiceLineItem>[
      for(final raw in data['items'] as List)
        InvoiceLineItem(
          description:(_map(raw)['description']??'').toString(),
          quantity:_int(_map(raw)['quantity']),
          unitPriceMinor:_int(_map(raw)['unit_price_minor']),
        ),
    ];
    final payments=<InvoicePaymentRecord>[
      for(final raw in data['payments'] as List)
        InvoicePaymentRecord(
          id:_map(raw)['id'].toString(),
          amountMinor:_int(_map(raw)['amount_minor']),
          paidAt:_date(_map(raw)['paid_at']),
          method:(_map(raw)['method']??'').toString(),
          referenceNumber:_map(raw)['reference_number']?.toString(),
          status:(_map(raw)['status']??'').toString(),
        ),
    ];
    final history=<InvoiceHistoryEvent>[
      for(final raw in data['history'] as List)
        InvoiceHistoryEvent(
          id:_map(raw)['id'].toString(),
          title:(_map(raw)['type']??'').toString().replaceAll('_',' '),
          occurredAt:_date(_map(raw)['created_at']),
          description:_map(raw)['actor_user_id']==null?null:
            'User #${_map(raw)['actor_user_id']}',
        ),
    ];
    final files=<LocalJobPhotoSelection>[];
    for(final raw in data['attachments'] as List){
      final row=_map(raw),id=_int(_map(raw)['id']);
      final mime=(row['mime_type']??'').toString();
      if(id<1||!const ['image/png','image/jpeg','application/pdf'].contains(mime)){
        throw const SignApiException('Invalid invoice attachment type.');
      }
      final bytes=await _api.getPrivateAttachment(
        '/api/v1/invoices/${_id(identifier)}/attachments/$id',
        mimeType:mime,maxBytes:10*1024*1024);
      _check(company);
      if(bytes.length!=_int(row['byte_size'])||
          sha256.convert(bytes).toString()!=row['sha256']){
        throw const SignApiException('Invoice SHA-256 fingerprint mismatch.');
      }
      files.add(LocalJobPhotoSelection(
        name:(row['name']??'attachment').toString(),
        bytes:bytes,sourceKey:'invoice-attachment-$id',
      ));
    }
    return _record(data['invoice'],company,
      items:items,payments:payments,history:history,photos:files);
  }

  static Map<String,dynamic> _fields(InvoiceRecord draft){
    final job=int.tryParse(draft.jobId??'');
    if(job==null||job<1||draft.items.isEmpty||
        draft.dueDate==null||draft.totalMinor==null||draft.totalMinor!<=0||
        !const ['final','deposit'].contains(draft.invoiceType)){
      throw const SignApiException('Select a saved job and actual invoice items.');
    }
    final items=<Map<String,dynamic>>[];
    for(final item in draft.items){
      if(!item.valid||item.unitPriceMinor==null){
        throw const SignApiException('Price every invoice item.');
      }
      items.add({
        'description':item.description.trim(),'quantity':item.quantity,
        'unit_price_minor':item.unitPriceMinor,
      });
    }
    String day(DateTime d)=>[
      d.year.toString().padLeft(4,'0'),d.month.toString().padLeft(2,'0'),
      d.day.toString().padLeft(2,'0'),
    ].join('-');
    final result=<String,dynamic>{
      'job_id':job,'quote_id':draft.sourceQuoteId,
      'addenda_ids':draft.sourceAddendaIds,
      'invoice_type':draft.invoiceType,
      'invoice_number':draft.number.trim(),
      'invoice_date':day(draft.date),'due_date':day(draft.dueDate!),
      'vat_basis_points':draft.vatBasisPoints,
      'iban':draft.iban.trim(),'notes':draft.notes.trim(),
      'terms':draft.terms.trim(),'items':items,
      'allocate_deposits':draft.invoiceType=='final',
      if(draft.id.startsWith('invoice-'))'lock_version':draft.lockVersion,
    };
    if(RegExp(r'^[A-Za-z0-9._-]{8,100}$').hasMatch(draft.id)&&
        !draft.id.startsWith('invoice-')){
      result['request_key']=draft.id;
    }
    return result;
  }

  @override
  Future<void> saveDraft(InvoiceRecord invoice) async {
    final company=_company();
    final response=_data(await _api.post('/api/v1/invoices',
      companyScoped:true,data:_fields(invoice)));
    _check(company);
    if(_record(response['invoice'],company).status!=InvoiceStatus.draft){
      throw const SignApiException('Invoice was not saved as a draft.');
    }
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<InvoiceRecord> updateInvoice(InvoiceRecord invoice) async {
    final company=_company(),id=_id(invoice.id);
    if(invoice.lifecycleStatus!='draft'||invoice.status!=InvoiceStatus.draft){
      throw const SignApiException('Approved invoices cannot be edited.');
    }
    final data=_data(await _api.request('PATCH','/api/v1/invoices/$id',
      companyScoped:true,data:_fields(invoice)));
    _check(company);
    if(_record(data['invoice'],company).id!=invoice.id){
      throw const SignApiException('Invoice ID changed.');
    }
    return invoiceDetail(invoice.id);
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<InvoiceRecord> approveInvoice(String identifier) async {
    final company=_company(),before=await invoiceDetail(identifier);
    _check(company);
    if(before.lifecycleStatus!='draft'){
      throw const SignApiException('Only draft invoices can be approved.');
    }
    final data=_data(await _api.post(
      '/api/v1/invoices/${_id(identifier)}/approve',
      companyScoped:true,data:{
        'confirm':true,'lock_version':before.lockVersion,
      }));
    _check(company);
    if(_record(data['invoice'],company).lifecycleStatus!='approved'){
      throw const SignApiException('Invoice approval not confirmed.');
    }
    return invoiceDetail(identifier);
  }

  @override
  Future<InvoiceRecord> markAsPaid(String identifier) async {
    final company=_company(),before=await invoiceDetail(identifier);
    _check(company);
    if(before.status==InvoiceStatus.paid)return before;
    final due=before.amountDueMinor;
    if(!before.status.canMarkPaid||due==null||due<=0){
      throw const SignApiException('Invoice must be approved first.');
    }
    final now=DateTime.now();
    final response=_data(await _api.post(
      '/api/v1/invoices/${_id(identifier)}/payments',
      companyScoped:true,data:{
        'confirm':true,'amount':(due/100).toStringAsFixed(2),
        'method':'other',
        'payment_date':[
          now.year.toString().padLeft(4,'0'),now.month.toString().padLeft(2,'0'),
          now.day.toString().padLeft(2,'0'),
        ].join('-'),
        'reference_number':'Manual payment confirmed in app',
        'request_key':'invoice-paid-${_id(identifier)}-$due',
      }));
    _check(company);
    if(_map(response['invoice'])['status']!='paid'){
      throw const SignApiException('Invoice still has an outstanding balance.');
    }
    return invoiceDetail(identifier);
  }

  static void _valid(LocalJobPhotoSelection p){
    if(p.bytes.isEmpty||p.bytes.length>10*1024*1024){
      throw const SignApiException('Invoice attachment exceeds 10 MB.');
    }
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<InvoiceRecord> updateAttachments(String identifier,
      List<LocalJobPhotoSelection> photos) async {
    final company=_company(),id=_id(identifier);
    final existing=await invoiceDetail(identifier);
    _check(company);
    if(existing.status!=InvoiceStatus.draft){
      throw const SignApiException('Approved invoice attachments are locked.');
    }
    if(photos.length>10)throw const SignApiException('Maximum 10 attachments.');
    final previous=existing.photos.map((p)=>_fileId(p.sourceKey))
        .whereType<int>().toSet();
    final keep=<int>{};
    for(final photo in photos){
      _valid(photo);
      final key=_fileId(photo.sourceKey);
      if(key!=null){
        if(!previous.contains(key)){
          throw const SignApiException('Attachment belongs to another invoice.');
        }
        keep.add(key);
      }
    }
    for(final photo in photos){
      if(_fileId(photo.sourceKey)==null){
        await _api.postMultipart('/api/v1/invoices/$id/attachments',
          filename:photo.name,bytes:photo.bytes,companyScoped:true,
          maxBytes:10*1024*1024);
      }
      _check(company);
    }
    for(final key in previous.difference(keep)){
      await _api.delete('/api/v1/invoices/$id/attachments/$key',
        companyScoped:true);
      _check(company);
    }
    return invoiceDetail(identifier);
  }
}
