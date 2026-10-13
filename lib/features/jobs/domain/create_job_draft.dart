import 'package:flutter/foundation.dart';

/// UI-only form payload; ready to map to a backend DTO in a later milestone.
@immutable
class CreateJobDraft {
  const CreateJobDraft({
    required this.clientId,
    required this.clientName,
    required this.address,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.budgetChf,
    required this.teamMemberIds,
  });

  final String clientId;
  final String clientName;
  final String address;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final double? budgetChf;
  final List<String> teamMemberIds;
}
