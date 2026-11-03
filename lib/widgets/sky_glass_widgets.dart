import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sky_theme.dart';

/// Deterministic matte grain painter that renders 2,800 sub-pixel 1.2x1.2px
/// stipple grain specks using fixed-seed Random(42).
class MatteGrainPainter extends CustomPainter {
  final bool isOled;

  const MatteGrainPainter({this.isOled = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rand = math.Random(42);
    const count = 2800;

    final whitePaint = Paint()
      ..color = Colors.white.withOpacity(isOled ? 0.03 : 0.045)
      ..style = PaintingStyle.fill;

    final navyPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.045)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final paint = (isOled || i % 2 == 0) ? whitePaint : navyPaint;
      canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant MatteGrainPainter oldDelegate) =>
      oldDelegate.isOled != isOled;
}

/// Tactile matte granular background canvas with 3 ambient subsurface light blooms.
class MatteGranularBackground extends StatelessWidget {
  final Widget child;

  const MatteGranularBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);

    if (palette.isOled) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: MatteGrainPainter(isOled: true),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: palette.backgroundColor,
        gradient: palette.backgroundGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Warm Cream/Amber bloom (340px) near top-right
          Positioned(
            top: -60,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD8A8).withOpacity(palette.isDark ? 0.08 : 0.16),
                      const Color(0xFFFFD8A8).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Ice Cyan bloom (380px) behind center stepping-stones
          Positioned(
            top: screenHeight * 0.28,
            left: screenWidth * 0.10,
            child: IgnorePointer(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFBAE6FD).withOpacity(palette.isDark ? 0.12 : 0.22),
                      const Color(0xFFBAE6FD).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Deep Indigo depth bloom (300px) near bottom-left
          Positioned(
            bottom: 40,
            left: -50,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF1E3A8A).withOpacity(palette.isDark ? 0.35 : 0.25),
                      const Color(0xFF1E3A8A).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Deterministic full-screen stipple grain overlay
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: MatteGrainPainter(isOled: palette.isOled),
                ),
              ),
            ),
          ),

          // 5. Foregound Content
          child,
        ],
      ),
    );
  }
}

/// Reusable true optical glassmorphic card for Serene Sky Sanctuary.
///
/// Hierarchy:
/// RepaintBoundary -> ClipRRect -> BackdropFilter(blur 24) -> Container(gradient fill, specular rim, shadow)
class SkyGlassCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
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
    this.gradient,
    this.borderColor,
    this.borderWidth,
    this.onTap,
    this.alignment,
    this.shadows,
    this.blurSigma = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final isOled = palette.isOled;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(palette.glassRadius);
    final effectiveBorderWidth = borderWidth ?? 1.2;
    final effectiveBorderColor = borderColor ??
        (isOled
            ? const Color(0xFF1E293B)
            : Colors.white.withOpacity(palette.isDark ? 0.22 : 0.42));

    final defaultGradient = isOled
        ? null
        : (palette.isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.24),
                  Colors.white.withOpacity(0.08),
                ],
              ));

    final effectiveColor = isOled
        ? (backgroundColor ?? const Color(0xFF090D14))
        : (backgroundColor ?? (gradient == null && defaultGradient == null ? palette.glassSurfaceColor : null));

    final effectiveGradient = gradient ?? (backgroundColor != null ? null : defaultGradient);

    final defaultShadows = [
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(palette.isDark ? 0.28 : 0.12),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16.0),
      alignment: alignment,
      decoration: BoxDecoration(
        color: effectiveColor,
        gradient: effectiveGradient,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorderColor,
          width: effectiveBorderWidth,
        ),
      ),
      child: child,
    );

    if (blurSigma > 0 && !isOled) {
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

    content = RepaintBoundary(child: content);

    final effectiveShadows = shadows ?? (isOled ? null : defaultShadows);
    if (effectiveShadows != null && effectiveShadows.isNotEmpty) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: effectiveShadows,
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

/// Dedicated optical frosted glass modal container for bottom sheets and dialogs.
///
/// Hierarchy:
/// RepaintBoundary -> ClipRRect (borderRadius 32px) -> BackdropFilter(blur 32) ->
/// Container(matte-glass gradient, 1.5px luminous border, ambient shadow)
class SkyGlassModal extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? maxHeight;
  final bool isBottomSheet;

  const SkyGlassModal({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.borderRadius,
    this.width,
    this.maxHeight,
    this.isBottomSheet = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final isOled = palette.isOled;

    final effectiveRadius = borderRadius ??
        (isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(32))
            : BorderRadius.circular(32));

    final modalGradient = isOled
        ? null
        : (palette.isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F172A).withOpacity(0.72),
                  const Color(0xFF060B19).withOpacity(0.82),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2B6CB0).withOpacity(0.55),
                  const Color(0xFF1E3A8A).withOpacity(0.65),
                ],
              ));

    Widget content = Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: isOled ? Colors.black : null,
        gradient: modalGradient,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: isOled
              ? const Color(0xFF1E293B)
              : Colors.white.withOpacity(0.38),
          width: 1.5,
        ),
        boxShadow: isOled
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF090D16).withOpacity(0.40),
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
      ),
      child: child,
    );

    if (!isOled) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: content,
      );
    }

    return RepaintBoundary(child: content);
  }
}

/// Helper decoration for recessed glass wells (text fields, chips, time windows).
class SkyGlassWell {
  static BoxDecoration decoration(SkyPalette palette, {double borderRadius = 18.0, Color? customFill}) {
    if (palette.isOled) {
      return BoxDecoration(
        color: customFill ?? const Color(0xFF090D14),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.0,
        ),
      );
    }
    return BoxDecoration(
      color: customFill ?? Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.25),
        width: 1.0,
      ),
    );
  }
}

/// Reusable small frosted pill with optical blur for tags, multipliers, and badges.
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
    final isOled = palette.isOled;

    Widget pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isOled
                ? const Color(0xFF090D14)
                : Colors.white.withOpacity(palette.isDark ? 0.12 : 0.16)),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: borderColor ??
              (isOled
                  ? const Color(0xFF1E293B)
                  : Colors.white.withOpacity(palette.isDark ? 0.25 : 0.35)),
          width: 1.0,
        ),
      ),
      child: child,
    );

    if (!isOled) {
      pill = ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: pill,
        ),
      );
    } else {
      pill = ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: pill,
      );
    }

    pill = RepaintBoundary(child: pill);

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
                style: AppTypography.button(
                  fontSize: 16,
                  color: fg,
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
