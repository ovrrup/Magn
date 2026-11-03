import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
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

/// Frosted Session Detail Dialog showing:
/// - Planned Duration
/// - Topic/Goal
/// - Preferred Time Window
/// - Calculated Token Reward
/// - Clear explanation of reward rules.
class SessionDetailDialog extends StatelessWidget {
  final PlannedSession session;
  final VoidCallback onStartSession;
  final VoidCallback? onDeleteSession;

  const SessionDetailDialog({
    super.key,
    required this.session,
    required this.onStartSession,
    this.onDeleteSession,
  });

  static Future<void> show({
    required BuildContext context,
    required PlannedSession session,
    required VoidCallback onStartSession,
    VoidCallback? onDeleteSession,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => SessionDetailDialog(
        session: session,
        onStartSession: onStartSession,
        onDeleteSession: onDeleteSession,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final windowRelation = session.preferredWindow?.checkRelation(DateTime.now());

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SkyGlassCard(
        padding: const EdgeInsets.all(22),
        borderRadius: BorderRadius.circular(28),
        backgroundColor: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
        borderColor: Colors.white.withOpacity(0.40),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.amberGold.withOpacity(0.25),
                      border: Border.all(color: palette.amberGold, width: 1.5),
                    ),
                    child: Icon(Icons.layers_rounded, color: palette.amberGold, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Session Blueprint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Topic / Goal
              Text(
                'TOPIC / GOAL',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.secondaryText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.topic,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
              ),

              const SizedBox(height: 14),

              // Duration & Preferred Window Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      label: 'PLANNED DURATION',
                      value: '${session.plannedDurationMinutes}m Focus',
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoCard(
                      label: 'PREFERRED WINDOW',
                      value: session.preferredWindow?.toDisplayString() ?? 'Flexible Window',
                      palette: palette,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Estimated Base Reward & Current Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED REWARD',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: palette.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${session.estimatedBaseTokens} Tokens',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: palette.amberGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (windowRelation != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: windowRelation == WindowRelation.inside
                                ? palette.mintAura.withOpacity(0.25)
                                : Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: windowRelation == WindowRelation.inside
                                  ? palette.mintAura
                                  : Colors.white.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            windowRelation.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.primaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reward Rules Explanation
              Text(
                'TOKEN REWARD RULES',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.secondaryText,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              _buildRuleRow('Inside preferred window:', '1.25x bonus tokens', palette.mintAura, palette),
              _buildRuleRow('Before preferred window:', '1.0x standard tokens', Colors.white, palette),
              _buildRuleRow('After preferred window:', '0.75x tokens', palette.amberGold, palette),
              _buildRuleRow('Flow Zone (after 5+ sessions):', '+1.5x on minutes > Flow Threshold', palette.amberGold, palette),

              const SizedBox(height: 20),

              // Start Now Button
              SkyPillButton(
                label: 'Start Now',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  onStartSession();
                },
              ),

              if (onDeleteSession != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    icon: Icon(Icons.delete_outline_rounded, size: 16, color: palette.deadlineAlertCoral),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDeleteSession!();
                    },
                    label: Text(
                      'Delete',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 13,
                        color: palette.deadlineAlertCoral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required SkyPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: palette.secondaryText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String left, String right, Color accent, SkyPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  color: palette.secondaryText,
                ),
                children: [
                  TextSpan(text: '$left '),
                  TextSpan(
                    text: right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
