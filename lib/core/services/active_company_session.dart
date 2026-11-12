import 'package:flutter/foundation.dart';

/// One verified tenant and its server-provided grants. An ID alone is not
/// enough to authorize UI modules or actions.
class CompanyAccess {
  CompanyAccess({required this.companyId, required this.role,
    required Iterable<String> permissions})
      : permissions = Set<String>.unmodifiable(permissions);

  final int companyId;
  final String role;
  final Set<String> permissions;
}

abstract final class ActiveCompanySession {
  static final ValueNotifier<int?> selected = ValueNotifier<int?>(null);
  static final ValueNotifier<CompanyAccess?> access =
      ValueNotifier<CompanyAccess?>(null);

  static int? get companyId => selected.value;
  static String get role => access.value?.role ?? '';
  static bool get isOwner => role == 'owner';

  static bool can(String module, String action) {
    final context = access.value;
    if (context == null || context.companyId != companyId) {
      // Unauthenticated preview mode has no selected tenant; authenticated
      // sessions must complete the verified company gate first.
      return companyId == null;
    }
    return context.role == 'owner' ||
        context.permissions.contains('$module.$action');
  }

  static bool canRead(String module) => can(module, 'read');
  static bool canWrite(String module) => can(module, 'write');

  static void setVerified(int id, {required String role,
    required Iterable<String> permissions}) {
    if (id <= 0) { clear(); return; }
    access.value = CompanyAccess(companyId: id, role: role,
      permissions: permissions);
    selected.value = id;
  }

  static void set(int? id) {
    final next = (id != null && id > 0) ? id : null;
    if (next != selected.value) access.value = null;
    selected.value = next;
  }

  static void clear() {
    access.value = null;
    selected.value = null;
  }
}
