import 'dart:collection';

import 'package:flutter/material.dart';

/// One dashboard route owns all five bottom tabs. Nested modules may render
/// the same approved navigation bar, but they must not pop intermediate routes
/// independently or create a second dashboard.
abstract final class Sign2DigitalNavigation {
  static final Map<NavigatorState, _DashboardOwner> _dashboards =
      HashMap<NavigatorState, _DashboardOwner>.identity();

  // Locks are keyed per Navigator AND destination, not per elapsed time.
  // They remain held until the pushed route is popped. This prevents both
  // double taps and duplicate async navigation without blocking other routes.
  static final Map<NavigatorState, Set<Object>> _activeActions =
      HashMap<NavigatorState, Set<Object>>.identity();

  static void attachDashboard({
    required NavigatorState navigator,
    required Route<dynamic> route,
    required ValueChanged<int> selectTab,
  }) {
    _dashboards[navigator] = _DashboardOwner(route, selectTab);
  }

  static void detachDashboard(NavigatorState navigator, Route<dynamic> route) {
    final current = _dashboards[navigator];
    if (current != null && identical(current.route, route)) {
      _dashboards.remove(navigator);
      _activeActions.remove(navigator);
    }
  }

  /// Returns true only when a registered dashboard owns this Navigator.
  /// Back and tab navigation are synchronous; animations remain unchanged.
  static bool selectDashboardTab(BuildContext context, int index) {
    if (index < 0 || index >= 5 || !context.mounted) return false;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return false;
    final owner = _dashboards[navigator];
    if (owner == null || !owner.route.isActive) return false;

    if (!identical(ModalRoute.of(context), owner.route)) {
      // Pop ALL children (Add Invoice, Invoices, etc.) exactly once.
      navigator.popUntil((route) => identical(route, owner.route));
    }
    owner.selectTab(index);
    return true;
  }

  /// Protect an asynchronous navigation operation, including the API load
  /// before a push. A different record/destination is never blocked.
  static Future<T?> runOnce<T>(
    BuildContext context,
    Object destination,
    Future<T?> Function() action,
  ) async {
    if (!context.mounted) return null;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return null;
    final locked = _activeActions.putIfAbsent(navigator, () => <Object>{});
    if (!locked.add(destination)) return null;
    try {
      return await action();
    } finally {
      locked.remove(destination);
      if (locked.isEmpty) _activeActions.remove(navigator);
    }
  }

  /// Replacement for direct Navigator.push across modules. The source route
  /// plus destination screen type identifies a single navigation action.
  /// While its child is active a rapid second tap cannot add another copy;
  /// opening that type from a *different* screen remains allowed.
  ///
  /// MaterialPageRoute's builder only constructs the destination widget;
  /// it is still mounted and built exclusively by the original route.
  static Future<T?> push<T>(
    BuildContext context,
    Route<T> route, {
    Object? destination,
  }) {
    // Async callers can complete after their source screen is disposed.
    // Never construct or mount a destination from an invalid context.
    if (!context.mounted) return Future<T?>.value(null);
    final target = destination ??
        (route is MaterialPageRoute<T>
            ? route.builder(context).runtimeType
            : (route.settings.name ?? route.runtimeType));
    final origin = ModalRoute.of(context) ?? context;
    return runOnce<T>(
      context,
      _RouteAction(origin, target),
      () => Navigator.of(context).push<T>(route),
    );
  }

  /// Simple screen push. Its type identifies the menu destination; IDs can
  /// be passed explicitly when multiple records share a screen class.
  static Future<T?> open<T>(
    BuildContext context,
    Widget screen, {
    Object? destination,
  }) =>
      runOnce<T>(
        context,
        destination ?? screen.runtimeType,
        () => Navigator.of(context).push<T>(
          MaterialPageRoute<T>(builder: (_) => screen),
        ),
      );
}

class _DashboardOwner {
  const _DashboardOwner(this.route, this.selectTab);
  final Route<dynamic> route;
  final ValueChanged<int> selectTab;
}

class _RouteAction {
  const _RouteAction(this.origin, this.destination);
  final Object origin;
  final Object destination;

  @override
  bool operator ==(Object other) =>
      other is _RouteAction &&
      identical(other.origin, origin) &&
      other.destination == destination;

  @override
  int get hashCode => Object.hash(identityHashCode(origin), destination);
}
