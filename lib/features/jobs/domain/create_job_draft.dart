import 'package:flutter/foundation.dart';

/// UI-only form payload; ready to map to a backend DTO in a later milestone.
@immutable
class CreateJobDraft {
  const CreateJobDraft({
    this.title,
    required this.clientId,
    required this.clientName,
    required this.address,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.budgetChf,
    required this.teamMemberIds,
  });

  /// Explicit job name, independent of the work description.
  /// Null preserves compatibility with previously saved forms.
  final String? title;
  final String clientId;
  final String clientName;
  final String address;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final double? budgetChf;
  final List<String> teamMemberIds;
}
