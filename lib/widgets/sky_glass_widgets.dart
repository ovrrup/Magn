import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sky_theme.dart';

/// Reusable frosted glassmorphic card for Serene Sky Sanctuary.
class SkyGlassCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final VoidCallback? onTap;
  final AlignmentGeometry? alignment;
  final List<BoxShadow>? shadows;
  final double blurSigma;

  const SkyGlassCard({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.onTap,
    this.alignment,
    this.shadows,
    this.blurSigma = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final effectiveRadius = borderRadius ?? BorderRadius.circular(palette.glassRadius);
    final effectiveBg = backgroundColor ?? palette.glassSurfaceColor;
    final effectiveBorderColor = borderColor ?? palette.glassBorderColor;
    final effectiveBorderWidth = borderWidth ?? palette.glassBorderWidth;

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16.0),
      alignment: alignment,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorderColor,
          width: effectiveBorderWidth,
        ),
      ),
      child: child,
    );

    if (blurSigma > 0 && palette.type != SkyThemePalette.oledBlack) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: content,
      );
    }

    if (shadows != null && shadows!.isNotEmpty) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: shadows,
        ),
        child: content,
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          splashColor: Colors.white.withOpacity(0.12),
          highlightColor: Colors.white.withOpacity(0.06),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(
        padding: margin!,
        child: content,
      );
    }

    return content;
  }
}

/// Reusable small frosted pill for tags, multipliers, and badges.
class SkyGlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const SkyGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);

    Widget pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(palette.isDark ? 0.12 : 0.20),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(palette.isDark ? 0.25 : 0.40),
          width: 1.0,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      pill = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: pill,
      );
    }

    return pill;
  }
}

/// Primary Cloud White CTA Pill Button (approx 56px height, navy text).
class SkyPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final Color? backgroundColor;
  final Color? textColor;

  const SkyPillButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.height = 56.0,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final bg = backgroundColor ?? palette.pillButtonBg;
    final fg = textColor ?? palette.pillButtonText;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
