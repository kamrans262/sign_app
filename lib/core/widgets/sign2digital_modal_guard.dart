import 'dart:collection';
import 'package:flutter/material.dart';

/// Navigator-scoped synchronous gate for approved modal picker surfaces.
/// One sheet at a time, held until the route closes. No timers, UI or animation changes.
abstract final class Sign2DigitalModalGuard {
  static final Set<NavigatorState> _active = HashSet<NavigatorState>.identity();

  static Future<T?> run<T>(
    BuildContext context,
    Future<T?> Function() showModal,
  ) async {
    if (!context.mounted) return null;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !_active.add(navigator)) return null;
    try {
      return await showModal();
    } finally {
      _active.remove(navigator);
    }
  }
}
