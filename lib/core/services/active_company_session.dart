import 'package:flutter/foundation.dart';

/// Backend-verified company context; never trust a display name as a tenant ID.
abstract final class ActiveCompanySession {
  static final ValueNotifier<int?> selected = ValueNotifier<int?>(null);
  static int? get companyId => selected.value;
  static void set(int? id) => selected.value = (id != null && id > 0) ? id : null;
  static void clear() => selected.value = null;
}
