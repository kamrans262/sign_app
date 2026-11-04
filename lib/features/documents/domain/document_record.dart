import '../../quotes/domain/quote_review_models.dart';
import '../../jobs/data/local_job_photo_source.dart';
import 'work_acceptance_data.dart';

/// Local UI record; status is not evidence that a remote signing service ran.
enum DocumentCategory {
  quotes, contacts, reports, addends,
  receipts, invoices, other,
}

/// Report-specific filtering, stored on the existing document record.
enum ReportKind {
  siteReport('Site Report'),
  workAcceptance('Work acceptance'),
  meetingMinutes('Meeting Minutes');

  const ReportKind(this.label);
  final String label;
}

/// One selectable section in a site report; tied to the existing Report record.
enum SiteReportSection {
  siteProgress('Site Progress'),
  photos('Photos'),
  notes('Notes & observations'),
  issues('Issues/Risks'),
  materials('Materials Delivery'),
  labour('Labour & time');

  const SiteReportSection(this.label);
  final String label;
}

/// Actual user-entered report fields; no server-side completion implied.
class SiteReportDetails {
  const SiteReportDetails({
    required this.reportDate,
    required this.preparedBy,
    required this.weatherCondition,
    required this.selectedSections,
    required this.sectionContent,
    this.photos = const [],
    this.location = '',
    this.attendees = const [],
    this.absentees = const [],
    this.decisions = const [],
    this.outstandingPoints = const [],
    this.nextSteps = const [],
    this.actionItems = const [],
  });

  final String location;
  final List<String> attendees;
  final List<String> absentees;
  final List<String> decisions;
  final List<String> outstandingPoints;
  final List<String> nextSteps;
  final List<MeetingActionItem> actionItems;
  final DateTime reportDate;
  final String preparedBy;
  final String weatherCondition;
  final List<SiteReportSection> selectedSections;
  final Map<SiteReportSection, String> sectionContent;
  final List<LocalJobPhotoSelection> photos;
}

/// Accountable meeting action with an optional owner and due date.
class MeetingActionItem {
  const MeetingActionItem({
    required this.description, this.assignee = '', this.dueDate,
  });

  final String description;
  final String assignee;
  final DateTime? dueDate;
}

/// Real M12 meeting minutes, distinct from the work acceptance milestone.
class MeetingMinutesDetails {
  const MeetingMinutesDetails({
    required this.location,
    required this.preparedBy,
    this.attendees = const [],
    this.absentees = const [],
    this.decisions = const [],
    this.nextSteps = const [],
    this.outstandingPoints = const [],
    this.actionItems = const [],
    this.actionDetails = const [],
    this.summary = '',
  });

  final String location;
  final String preparedBy;
  final List<String> attendees;
  final List<String> absentees;
  final List<String> decisions;
  final List<String> nextSteps;
  final List<String> outstandingPoints;
  final List<String> actionItems;
  final List<MeetingActionItem> actionDetails;
  final String summary;
}

/// A documented event linked to a particular document. Production callers
/// must supply only verified source events; UI-only fixtures stay in demo mode.
enum DocumentHistoryType {
  created, edited, sent, emailOpened, viewed, signed,
  downloaded, versionChanged, approved, archived, attachmentAdded,
}

class DocumentHistoryEvent {
  const DocumentHistoryEvent({
    required this.id,
    required this.documentId,
    required this.type,
    required this.occurredAt,
    this.actorName,
    this.actorEmail,
    this.description,
    this.signatureReference,
  });

  final String id;
  final String documentId;
  final DocumentHistoryType type;
  final DateTime occurredAt;
  final String? actorName;
  final String? actorEmail;
  final String? description;
  final String? signatureReference;

  String get title => switch (type) {
    DocumentHistoryType.created => 'Document Created',
    DocumentHistoryType.edited => 'Document Edited',
    DocumentHistoryType.downloaded => 'Document Downloaded',
    DocumentHistoryType.versionChanged => 'Document Version Changed',
    DocumentHistoryType.approved => 'Document Approved',
    DocumentHistoryType.archived => 'Document Archived',
    DocumentHistoryType.attachmentAdded => 'Attachment Added',
    DocumentHistoryType.sent => 'Document Sent',
    DocumentHistoryType.emailOpened => 'E-mail Opened',
    DocumentHistoryType.viewed => 'Viewed by Customers',
    DocumentHistoryType.signed => 'Document Signed',
  };
}

class DocumentPermissionDeniedException implements Exception {
  const DocumentPermissionDeniedException();
}

/// A private file stored separately from an immutable source document.
class DocumentAttachmentReference {
  const DocumentAttachmentReference({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sha256,
  });

  final int id;
  final String name;
  final String mimeType;
  final String sha256;
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.category,
    required this.number,
    required this.title,
    required this.project,
    required this.customer,
    required this.timestamp,
    required this.status,
    this.quote,
    this.demoOnly = false,
    this.verifiedSignedPdfAvailable = false,
    this.version = 1,
    this.jobId,
    this.attachmentNames = const [],
    this.attachments = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.validUntil,
    this.history = const [],
    this.related = const [],
    this.addendumDraftId,
    this.reportKind,
    this.siteReportDetails,
    this.meetingMinutesDetails,
    this.reportManagedDocumentId,
    this.workAcceptance,
  });

  final String id;
  final DocumentCategory category;
  final String number;
  final String title;
  final String project;
  final String customer;
  final DateTime timestamp;
  final String status;
  final QuoteReviewDraft? quote;
  final bool demoOnly;
  final bool verifiedSignedPdfAvailable;
  /// Local record revision; backend audit versions remain authoritative.
  final int version;
  /// Authoritative linked job for company-scoped document records.
  final String? jobId;
  final List<String> attachmentNames;
  final List<DocumentAttachmentReference> attachments;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? validUntil;
  final List<DocumentHistoryEvent> history;
  final List<DocumentRecord> related;
  /// Session-local editable addendum entry, not a server document.
  final String? addendumDraftId;
  final ReportKind? reportKind;
  final SiteReportDetails? siteReportDetails;
  final MeetingMinutesDetails? meetingMinutesDetails;
  final int? reportManagedDocumentId;
  final WorkAcceptanceEvidence? workAcceptance;

  /// Return a view with linked records while preserving the source document's
  /// identity, status, PDF authenticity and all immutable metadata.
  DocumentRecord withRelated(List<DocumentRecord> documents) => DocumentRecord(
    id: id,
    category: category,
    number: number,
    title: title,
    project: project,
    customer: customer,
    timestamp: timestamp,
    status: status,
    quote: quote,
    demoOnly: demoOnly,
    verifiedSignedPdfAvailable: verifiedSignedPdfAvailable,
    version: version,
    jobId: jobId,
    attachmentNames: attachmentNames,
    attachments: attachments,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    validUntil: validUntil,
    history: history,
    related: List.unmodifiable(documents),
    addendumDraftId: addendumDraftId,
    reportKind: reportKind,
    siteReportDetails: siteReportDetails,
    meetingMinutesDetails: meetingMinutesDetails,
    reportManagedDocumentId: reportManagedDocumentId,
    workAcceptance: workAcceptance,
  );

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      id, number, title, project, customer,
      category.name, status, quote?.jobId ?? '', reportKind?.label ?? '',
      quote?.clientId ?? '', quote?.clientEmail ?? '',
      'v$version', jobId ?? '', ...attachmentNames,
    ].any((field) => field.toLowerCase().contains(needle));
  }
}

abstract class DocumentRepository {
  Future<List<DocumentRecord>> listDocuments();
}
