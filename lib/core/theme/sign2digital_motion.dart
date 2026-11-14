import 'package:flutter/material.dart';

/// Consistent, restrained motion for Sign2Digital; visual tokens stay intact.
/// Native Cupertino page transitions retain iOS edge-swipe navigation.
abstract final class Sign2DigitalMotion {
  static const Duration keyboard = Duration(milliseconds: 260);
  static const Duration chatScroll = Duration(milliseconds: 220);
  static const AnimationStyle bottomSheet = AnimationStyle(
    duration: Duration(milliseconds: 300),
    reverseDuration: Duration(milliseconds: 250),
  );
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _Sign2DigitalPageTransition(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: _Sign2DigitalPageTransition(),
      TargetPlatform.linux: _Sign2DigitalPageTransition(),
      TargetPlatform.fuchsia: _Sign2DigitalPageTransition(),
    },
  );
}

class _Sign2DigitalPageTransition extends PageTransitionsBuilder {
  const _Sign2DigitalPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || MediaQuery.of(context).disableAnimations) {
      return child;
    }
    final opacity = animation.drive(
      CurveTween(curve: Curves.easeOutCubic));
    final slide = animation.drive(
      Tween<Offset>(begin: const Offset(0.045, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic)));
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
