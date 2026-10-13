// Sign2Digital Navigation Fix — plain white, centered original logo only.
import 'dart:async';

import 'package:flutter/material.dart';

/// Splash presentation with an optional callback for feature/widget reuse.
/// The main app owns its own startup navigation timer.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.onFinished,
    this.minimumDuration = const Duration(milliseconds: 2600),
  });

  final VoidCallback? onFinished;
  final Duration minimumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    if (widget.onFinished != null) {
      _completionTimer = Timer(widget.minimumDuration, () {
        if (mounted) widget.onFinished?.call();
      });
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Image.asset(
              'assets/logo_splash.png',
              fit: BoxFit.contain,
              semanticLabel: 'Sign2Digital logo',
            ),
          ),
        ),
      ),
    );
  }
}
