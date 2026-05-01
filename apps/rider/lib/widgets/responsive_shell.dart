import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Wraps any builder with a phone-sized container when running on wide
/// screens (web/desktop). On narrow screens (real phones) it's a no-op.
///
/// Used as MaterialApp.builder so every route is constrained.
class ResponsiveShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveShell({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final shouldFrame = (kIsWeb || _isDesktopHost()) && width > maxWidth + 24;

    if (!shouldFrame) return child;

    return Container(
      color: const Color(0xFF05070C),
      alignment: Alignment.center,
      child: Container(
        width: maxWidth,
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              spreadRadius: 4,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(maxWidth, MediaQuery.of(context).size.height),
          ),
          child: child,
        ),
      ),
    );
  }

  bool _isDesktopHost() {
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}
