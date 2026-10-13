import 'package:flutter/foundation.dart';

import 'client_profile.dart';

/// UI-only detail data associated with an existing client identity.
@immutable
class ClientDetailsModel {
  const ClientDetailsModel({
    required this.client,
    required this.status,
    required this.totalQuotes,
    required this.totalDocuments,
    required this.totalInvoices,
    required this.jobs,
    required this.quotes,
    required this.documents,
    required this.invoices,
    required this.notes,
    required this.displayAddress,
  });

  final ClientProfile client;
  final String status;
  final int totalQuotes;
  final int totalDocuments;
  final int totalInvoices;
  final String displayAddress;
  final List<ClientRelatedRecord> jobs;
  final List<ClientRelatedRecord> quotes;
  final List<ClientRelatedRecord> documents;
  final List<ClientRelatedRecord> invoices;
  final List<ClientRelatedRecord> notes;
}

@immutable
class ClientRelatedRecord {
  const ClientRelatedRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.meta,
    this.status,
  });

  final String id;
  final String title;
  final String description;
  final String meta;
  final String? status;
}
