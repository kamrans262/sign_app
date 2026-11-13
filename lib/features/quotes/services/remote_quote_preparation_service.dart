import 'dart:io';
import 'package:flutter/material.dart' show Icons;

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../domain/quote_draft_input.dart';
import '../domain/quote_extraction_models.dart';
import '../domain/quote_preparation_service.dart';

/// M6 OpenAI via authenticated Laravel ONLY. No API key enters Flutter.
/// Never transforms missing data into made-up prices, tax or measurements.
class RemoteQuotePreparationService implements QuotePreparationService {
  RemoteQuotePreparationService({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  final SignApiClient _api;

  @override
  Stream<QuotePreparationSnapshot> prepare(QuoteDraftInput input) async* {
    final company=ActiveCompanySession.companyId;
    if (company == null || company <= 0) {
      throw const SignApiException('Select a company before generating a quote.');
    }
    yield const QuotePreparationSnapshot(stage:QuotePreparationStage.extracting);
    late Map<String,dynamic> response;
    if (input.method == QuoteInputMethod.text) {
      final description=input.description?.trim() ?? '';
      if (description.isEmpty) {
        throw const SignApiException('Enter your quote instructions.');
      }
      response=await _api.post('/api/v1/quotes/prepare/text',
          companyScoped:true,data:{
            'text':description,
            if (input.clarification?.trim().isNotEmpty ?? false)
              'clarification':input.clarification!.trim(),
          });
    } else {
      final path=input.method == QuoteInputMethod.voice
          ? input.audioPath : input.photoPath;
      if (path == null || path.trim().isEmpty) {
        throw const SignApiException('Select a valid recording or photo.');
      }
      final selected=File(path);
      if(!await selected.exists()) {
        throw const SignApiException('The selected source file is missing.');
      }
      final max=input.method == QuoteInputMethod.voice
          ? 25*1024*1024 : 15*1024*1024;
      final bytes=await selected.length();
      if(bytes == 0 || bytes > max) {
        throw const SignApiException('The source file is too large or empty.');
      }
      response=await _api.postMultipart(
        input.method == QuoteInputMethod.voice
            ? '/api/v1/quotes/prepare/audio'
            : '/api/v1/quotes/prepare/image',
        filename:selected.path.split(Platform.pathSeparator).last,
        bytes:await selected.readAsBytes(),
        companyScoped:true,maxBytes:max,
        fields: input.clarification?.trim().isNotEmpty ?? false
            ? {'clarification':input.clarification!.trim()} : null,
      );
    }
    if (ActiveCompanySession.companyId != company) {
      throw const SignApiException('Company changed during quote processing.');
    }
    final data=response['data'];
    if (data is! Map<String,dynamic> ||
        data['snapshot'] is! Map<String,dynamic>) {
      throw const SignApiException('Invalid AI extraction response.');
    }
    final snapshot=data['snapshot'] as Map<String,dynamic>;
    if (snapshot['stage'] == 'needs_clarification' &&
        snapshot['items'] is List &&
        (snapshot['items'] as List).isEmpty) {
      final question=snapshot['clarification_question'];
      yield QuotePreparationSnapshot(
        stage: QuotePreparationStage.needsClarification,
        clarificationQuestion: question is String && question.trim().isNotEmpty
            ? question.trim() : 'What work should be included in the quotation?',
        message: 'Please add the work details to continue.',
      );
      return;
    }
    if (snapshot['stage'] != 'completed' || snapshot['items'] is! List) {
      throw const SignApiException('AI extraction was not completed.');
    }
    final list=snapshot['items'] as List;
    if(list.isEmpty || list.length>25) {
      throw const SignApiException('No valid work items were extracted.');
    }
    String? value(Object? raw) {
      if(raw is! String) return null;
      final cleaned=raw.trim();
      return cleaned.isEmpty ? null : cleaned;
    }
    final items=<QuotePreparedWorkItem>[];
    for(final raw in list) {
      if(raw is! Map<String,dynamic>) continue;
      final title=value(raw['title']);
      if(title == null) continue;
      final q=raw['quantity'];
      final qty=q is int && q>0 && q<=100000 ? q : null;
      items.add(QuotePreparedWorkItem(
        title:title,
        description:value(raw['description']) ?? '',
        quantity:qty,
        dimensions:value(raw['dimensions']),
      ));
    }
    if(items.isEmpty) {
      throw const SignApiException('The AI did not identify clear work items.');
    }
    final currency=value(snapshot['currency']);
    final verifiedCurrency=['CHF','EUR','GBP','USD'].contains(currency)
        ? currency : null;
    final location=value(snapshot['location']);
    final notes=value(snapshot['notes']);
    yield QuotePreparationSnapshot(
      stage:QuotePreparationStage.completed,
      items:items,currency:verifiedCurrency,
      fields:[
        QuoteExtractedField(id:'ai-items',label:'Items',
          value:'${items.length} work ${items.length == 1 ? 'item' : 'items'}',
          status:QuoteExtractionStatus.needsReview,
          fallbackIcon:Icons.shopping_cart_outlined),
        QuoteExtractedField(id:'ai-quantity',label:'Quantity',
          value:'${items.where((i)=>i.quantity!=null).length} of ${items.length} specified',
          status:items.every((i)=>i.quantity!=null)
              ? QuoteExtractionStatus.needsReview : QuoteExtractionStatus.unclear,
          fallbackIcon:Icons.shopping_cart_outlined),
        if (items.any((i)=>i.dimensions!=null))
          QuoteExtractedField(id:'ai-dimensions',label:'Dimensions',
            value:items.where((i)=>i.dimensions!=null)
                .map((i)=>'${i.title}: ${i.dimensions}').join('; '),
            status:QuoteExtractionStatus.needsReview,
            fallbackIcon:Icons.open_in_full_outlined),
        if(notes!=null) QuoteExtractedField(id:'ai-notes',
          label:'Installation',value:notes,
          status:QuoteExtractionStatus.needsReview,
          fallbackIcon:Icons.layers_outlined),
        if(location!=null) QuoteExtractedField(id:'ai-location',
          label:'Location',value:location,
          status:QuoteExtractionStatus.needsReview,
          fallbackIcon:Icons.location_on_outlined),
        const QuoteExtractedField(id:'ai-price-warning',label:'Pricing',
          value:'Enter and confirm unit prices',
          status:QuoteExtractionStatus.missing,
          fallbackIcon:Icons.description_outlined),
      ],
      message:'Review these AI suggestions. Prices and VAT were not generated.',
    );
  }
}
