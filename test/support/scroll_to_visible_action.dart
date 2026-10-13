// Shared test utility for long forms and lazily built bottom actions.
// A finder may match a widget that is outside the hit-testable viewport, or
// may not match a sliver child until its region has been laid out.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> scrollToVisibleAction(
  WidgetTester tester, {
  required Key scrollKey,
  required Finder target,
}) async {
  final scrollView = find.byKey(scrollKey);
  expect(scrollView, findsOneWidget);

  final scrollableFinder = find.descendant(
    of: scrollView,
    matching: find.byType(Scrollable),
  );
  expect(scrollableFinder, findsWidgets);
  final scrollable = tester.state<ScrollableState>(scrollableFinder.first);
  final viewport = tester.getRect(scrollView);

  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    if (target.evaluate().isNotEmpty) {
      final targetRect = tester.getRect(target);
      // Check the actual hit-target center, not just existence in the tree.
      if (viewport.deflate(1).contains(targetRect.center)) {
        return;
      }
    }

    final position = scrollable.position;
    final next = math.min(
      position.maxScrollExtent,
      position.pixels + math.max(120.0, viewport.height * 0.7),
    );
    if (next <= position.pixels + 0.5) {
      throw TestFailure(
        'Could not scroll the target into view. '
        'Check the screen layout or scroll extent for $scrollKey.',
      );
    }
    position.jumpTo(next);
    await tester.pumpAndSettle();
  }
  throw TestFailure('Target never became visible after scrolling.');
}
