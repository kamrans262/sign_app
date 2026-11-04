import 'dart:typed_data';

/// Work acceptance is evidence-driven, not inferred from a report status.
enum WorkAcceptanceStage {
  workCompleted('Work Completed'),
  clientNotified('Client Notified'),
  clientViewed('Client Viewed'),
  clientSigned('Client Signed'),
  completed('Completed');

  const WorkAcceptanceStage(this.label);
  final String label;
}

class WorkAcceptanceEvent {
  const WorkAcceptanceEvent({
    required this.id,
    required this.documentId,
    required this.stage,
    required this.occurredAt,
    required this.actorName,
  });

  final String id;
  final String documentId;
  final WorkAcceptanceStage stage;
  final DateTime occurredAt;
  final String actorName;
}

/// Verified assets must be supplied by a trusted production data source.
/// Local signing drafts are not acceptable as confirmation of signing.
class WorkAcceptanceEvidence {
  const WorkAcceptanceEvidence({
    this.events = const [],
    this.verifiedSignaturePng,
    this.verifiedReportPdf,
    this.acceptanceResult, this.reservation = '',
    this.outstandingIssues = '', this.customerComment = '',
    this.customerRating, this.signedAt,
  });

  final List<WorkAcceptanceEvent> events;
  final Uint8List? verifiedSignaturePng;
  final Uint8List? verifiedReportPdf;

  /// These fields come from the verified customer acceptance record.
  final String? acceptanceResult;
  final String reservation;
  final String outstandingIssues;
  final String customerComment;
  final int? customerRating;
  final DateTime? signedAt;
}
