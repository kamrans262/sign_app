import 'dart:collection';
import 'package:flutter/material.dart';

/// One modal at a time per *origin route*, not per entire navigator.
/// Nested selection sheets are valid (filter -> client picker); repeated taps
/// on the same originating screen/sheet cannot stack duplicate modal routes.
/// Locks live until the pushed route closes. No debounce or animation changes.
abstract final class Sign2DigitalModalGuard {
  static final Map<NavigatorState, Set<Object>> _active =
      HashMap<NavigatorState, Set<Object>>.identity();

  static Future<T?> run<T>(
    BuildContext context,
    Future<T?> Function() showModal,
  ) async {
    if (!context.mounted) return null;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return null;
    final origin = ModalRoute.of(context) ?? context;
    final locked = _active.putIfAbsent(
      navigator, () => HashSet<Object>.identity(),
    );
    if (!locked.add(origin)) return null;
    try {
      return await showModal();
    } finally {
      locked.remove(origin);
      if (locked.isEmpty) _active.remove(navigator);
    }
  }
}
