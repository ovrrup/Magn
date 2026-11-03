import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/sky_theme.dart';

/// 2.5D Stepping-Stone Pedestal Node widget.
///
/// Features layered elliptical 2.5D geometry:
/// - Soft Mint radial aura glow
/// - Outer ripple oval (136x56px, 1px white border @ 0.45 opacity)
/// - Base 3D cylinder shadow ellipse (104x42px, shifted 8px downward)
/// - Solid Cloud White top ellipse (104x42px)
/// - Floating circular pin badge (48px diameter, 2px white border, sky-blue fill) floating 18px above pedestal
/// - Displays planned session topic, duration badge, and preferred window.
class PedestalNode extends StatelessWidget {
  final PlannedSession? session;
  final String? customTopic;
  final String? customDuration;
  final IconData badgeIcon;
  final VoidCallback? onTap;

  const PedestalNode({
    super.key,
    this.session,
    this.customTopic,
    this.customDuration,
    this.badgeIcon = Icons.layers_rounded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final displayTopic = session?.topic ?? customTopic ?? 'Focus Session';
    final displayDuration = session != null
        ? '${session!.plannedDurationMinutes}m Focus'
        : (customDuration ?? '25m Focus');
    final displayWindow = session?.preferredWindow?.toDisplayString();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 2.5D Pedestal Stack
          SizedBox(
            width: 150,
            height: 130, // 48px badge + 18px gap + 64px pedestal
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Soft Mint Radial Aura
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 148,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          palette.mintAura.withOpacity(palette.isDark ? 0.35 : 0.45),
                          palette.mintAura.withOpacity(0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // 2. Layered 2.5D Ellipses (Outer Ripple + 3D Cylinder Wall + Top White Ellipse)
                Positioned(
                  bottom: 6,
                  child: CustomPaint(
                    size: const Size(136, 60),
                    painter: _PedestalPainter(
                      iceBlueShadow: palette.iceBlueShadow,
                      mintAura: palette.mintAura,
                      isDark: palette.isDark,
                    ),
                  ),
                ),

                // 3. Floating Circular Pin Badge (48px diameter, 18px above pedestal)
                Positioned(
                  top: 4,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3888E6),
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                        BoxShadow(
                          color: palette.mintAura.withOpacity(0.30),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        badgeIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Topic Title
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              displayTopic,
              textAlign: TextAlign.center,
              style: AppTypography.display(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.primaryText,
                letterSpacing: 0.1,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 4),

          // Duration & Window Badges Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(palette.isDark ? 0.12 : 0.22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  displayDuration,
                  style: AppTypography.numeric(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.primaryText,
                  ),
                ),
              ),
              if (displayWindow != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: palette.amberGold.withOpacity(palette.isDark ? 0.20 : 0.25),
                    border: Border.all(
                      color: palette.amberGold.withOpacity(0.60),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    displayWindow,
                    style: AppTypography.numeric(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.primaryText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PedestalPainter extends CustomPainter {
  final Color iceBlueShadow;
  final Color mintAura;
  final bool isDark;

  _PedestalPainter({
    required this.iceBlueShadow,
    required this.mintAura,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Outer Ripple Oval (136x56px, 1px white border @ 0.45 opacity)
    final rippleRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 2),
      width: 136,
      height: 56,
    );

    final rippleFillPaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.06 : 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawOval(rippleRect, rippleFillPaint);

    final rippleStrokePaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(rippleRect, rippleStrokePaint);

    // 2. Base 3D Cylinder Shadow Ellipse (104x42px, shifted 8px down)
    final baseRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 6 + 8),
      width: 104,
      height: 42,
    );

    final topRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 6),
      width: 104,
      height: 42,
    );

    // Cylinder body
    final cylinderPath = Path()
      ..moveTo(topRect.left, topRect.center.dy)
      ..arcTo(topRect, 3.14159, -3.14159, false)
      ..lineTo(baseRect.right, baseRect.center.dy)
      ..arcTo(baseRect, 0, 3.14159, false)
      ..close();

    final cylinderWallPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : iceBlueShadow
      ..style = PaintingStyle.fill;
    canvas.drawPath(cylinderPath, cylinderWallPaint);

    final baseStrokePaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFBACCE4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(baseRect, baseStrokePaint);

    // 3. Top Pristine Cloud White Ellipse (104x42px)
    final topFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawOval(topRect, topFillPaint);

    final topStrokePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(topRect, topStrokePaint);
  }

  @override
  bool shouldRepaint(covariant _PedestalPainter oldDelegate) {
    return oldDelegate.iceBlueShadow != iceBlueShadow ||
        oldDelegate.mintAura != mintAura ||
        oldDelegate.isDark != isDark;
  }
}
