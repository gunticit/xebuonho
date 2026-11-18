import 'package:flutter/material.dart';
import '../config/theme.dart';

enum AvatarSize {
  small(36),
  medium(56),
  large(90);

  final double diameter;
  const AvatarSize(this.diameter);
}

class GradientAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final AvatarSize size;
  final bool showOnline;
  final Gradient? ringGradient;

  const GradientAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AvatarSize.medium,
    this.showOnline = false,
    this.ringGradient,
  });

  @override
  State<GradientAvatar> createState() => _GradientAvatarState();
}

class _GradientAvatarState extends State<GradientAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulse;

  @override
  void initState() {
    super.initState();
    _initPulse();
  }

  @override
  void didUpdateWidget(covariant GradientAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showOnline != widget.showOnline) {
      _initPulse();
    }
  }

  void _initPulse() {
    if (widget.showOnline) {
      _pulseController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );
      _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
      _pulseController!.repeat(reverse: true);
    } else {
      _pulseController?.stop();
      _pulseController?.dispose();
      _pulseController = null;
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  String get _initial {
    final trimmed = widget.name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  double get _ringWidth {
    return switch (widget.size) {
      AvatarSize.small => 2.0,
      AvatarSize.medium => 2.5,
      AvatarSize.large => 3.0,
    };
  }

  double get _fontSize {
    return switch (widget.size) {
      AvatarSize.small => 14,
      AvatarSize.medium => 20,
      AvatarSize.large => 34,
    };
  }

  double get _dotSize {
    return switch (widget.size) {
      AvatarSize.small => 10,
      AvatarSize.medium => 14,
      AvatarSize.large => 18,
    };
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size.diameter;
    final gradient = widget.ringGradient ?? AppGradients.primary;

    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        children: [
          // Gradient ring
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            padding: EdgeInsets.all(_ringWidth),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bg2,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: widget.imageUrl != null
                    ? Image.network(
                        widget.imageUrl!,
                        width: d,
                        height: d,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackLetter(),
                      )
                    : _fallbackLetter(),
              ),
            ),
          ),

          // Online indicator
          if (widget.showOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildOnlineDot(),
            ),
        ],
      ),
    );
  }

  Widget _fallbackLetter() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: AppTextStyles.heading3.copyWith(
          fontSize: _fontSize,
          color: AppColors.text,
        ),
      ),
    );
  }

  Widget _buildOnlineDot() {
    final dot = _dotSize;
    final innerDot = dot - 4;

    Widget indicator = Container(
      width: dot,
      height: dot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bg2,
        border: Border.all(color: AppColors.bg2, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: innerDot,
        height: innerDot,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.green,
        ),
      ),
    );

    if (_pulse != null && _pulseController != null) {
      return AnimatedBuilder(
        animation: _pulse!,
        builder: (context, child) {
          return Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: _pulse!.value * 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          );
        },
        child: indicator,
      );
    }

    return indicator;
  }
}
