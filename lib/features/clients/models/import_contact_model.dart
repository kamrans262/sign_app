import 'package:flutter/foundation.dart';

/// UI-only contact summary, independent of device contacts and Laravel.
@immutable
class ImportContactModel {
  const ImportContactModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    this.avatarAsset,
    this.isSelected = false,
  });

  final String id;
  final String fullName;
  final String phoneNumber;
  final String email;
  final String? avatarAsset;
  final bool isSelected;

  ImportContactModel copyWith({bool? isSelected}) => ImportContactModel(
    id: id,
    fullName: fullName,
    phoneNumber: phoneNumber,
    email: email,
    avatarAsset: avatarAsset,
    isSelected: isSelected ?? this.isSelected,
  );
}
