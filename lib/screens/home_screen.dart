import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';
import '../widgets/pedestal_node.dart';
import '../widgets/sky_glass_widgets.dart';
import 'active_focus_screen.dart';
import 'settings_sheet.dart';

/// Tab 1: Home Screen (Serene Sky Sanctuary).
///
/// Features:
/// - Top Header: ONLY Settings tune icon on left; Streak and Tokens counter pills on right.
/// - Peek-Edge Hero Carousel: 132px height, PageView.builder, viewportFraction 0.82,
///   itemCount 10000, initialIndex 4000, 4 cycling cards with Matrix4 scale peaking.
/// - Central User-Planned Stepping-Stone Path:
///   * Calm empty state when no sessions planned.
///   * 2.5D cylindrical pedestal nodes stacked vertically (newest on TOP) with dashed separators.
///   * Interactive SessionDetailDialog with reward rules clearly explained.
/// - Docked Cloud White Primary CTA Pill Button:
///   * "Plan a Session" (if empty) vs "Start • [Topic]" (if planned).
class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToPlan;

  const HomeScreen({
    super.key,
    required this.onNavigateToPlan,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _carouselPageController;
  int _currentCarouselPage = 4000;

  @override
  void initState() {
    super.initState();
    _carouselPageController = PageController(
      viewportFraction: 0.82,
      initialPage: 4000,
    );
  }

  @override
  void dispose() {
    _carouselPageController.dispose();
    super.dispose();
  }

  void _launchActiveFocus(AppController controller, {PlannedSession? plannedSession}) {
    controller.startFocusSession(plannedSession: plannedSession);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const ActiveFocusScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final controller = AppControllerScope.of(context);
    final planned = controller.plannedSessions.where((s) => !s.isCompleted).toList();
    final nextSession = controller.nextPlannedSession;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 8),

          // 1. Top Header (Settings icon ONLY on left, Streak & Tokens on right)
          _buildHeader(context, controller, palette),

          const SizedBox(height: 12),

          // 2. Peek-Edge Hero Carousel (132px height, 4 cycling cards)
          _buildHeroCarousel(controller, palette),

          const SizedBox(height: 12),

          // 3. Central Stepping-Stone Path (Expanded & Scrollable)
          Expanded(
            child: _buildSteppingStonePath(context, controller, planned, palette),
          ),

          // 4. Docked Primary Cloud White Pill Button (above bottom navigation)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SkyPillButton(
              height: 56,
              icon: nextSession != null ? Icons.play_arrow_rounded : Icons.add_rounded,
              label: nextSession != null
                  ? 'Start • ${nextSession.topic}'
                  : 'Plan a Session',
              onPressed: () {
                if (nextSession != null) {
                  _launchActiveFocus(controller, plannedSession: nextSession);
                } else {
                  widget.onNavigateToPlan();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppController controller, SkyPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Frosted Settings tune icon ONLY
          SkyGlassCard(
            padding: EdgeInsets.zero,
            width: 42,
            height: 42,
            borderRadius: BorderRadius.circular(21),
            onTap: () => SettingsSheet.show(context),
            child: Center(
              child: Icon(
                Icons.tune_rounded,
                color: palette.primaryText,
                size: 20,
              ),
            ),
          ),

          // Right: Streak and Tokens Counter Pills
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Streak Pill
              SkyGlassPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: palette.amberGold,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${controller.currentStreak}',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Wallet Tokens Pill
              SkyGlassPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: palette.amberGold,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${controller.walletTokenBalance}',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Peek-Edge Hero Carousel: 132px height, PageView.builder with Matrix4 scaling.
  Widget _buildHeroCarousel(AppController controller, SkyPalette palette) {
    return SizedBox(
      height: 132,
      child: PageView.builder(
        controller: _carouselPageController,
        itemCount: 10000,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (idx) {
          setState(() {
            _currentCarouselPage = idx;
          });
        },
        itemBuilder: (context, index) {
          final cardIndex = index % 4;

          return AnimatedBuilder(
            animation: _carouselPageController,
            builder: (context, child) {
              double scale = 1.0;
              if (_carouselPageController.position.haveDimensions) {
                final page = _carouselPageController.page ?? _currentCarouselPage.toDouble();
                final diff = (page - index).abs();
                scale = (1.0 - (diff * 0.14)).clamp(0.86, 1.0);
              } else {
                scale = index == _currentCarouselPage ? 1.0 : 0.88;
              }

              return Transform.scale(
                scale: scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _buildCarouselCard(cardIndex, controller, palette),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCarouselCard(int cardIndex, AppController controller, SkyPalette palette) {
    switch (cardIndex) {
      case 0:
        // Card 1: Next Planned Topic
        final next = controller.nextPlannedSession;
        return SkyGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'NEXT PLANNED TOPIC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.secondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.flag_rounded, color: palette.amberGold, size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                next?.topic ?? 'No Sessions Planned',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                next != null
                    ? '${next.plannedDurationMinutes}m • ${next.preferredWindow?.toDisplayString() ?? "Anytime"} • +${next.estimatedBaseTokens} Tokens'
                    : 'Tap "Plan a Session" below to anchor your focus.',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  color: palette.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

      case 1:
        // Card 2: Best Session
        final best = controller.bestSession;
        return SkyGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'BEST COMPLETED SESSION',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.secondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.workspace_premium_rounded, color: palette.amberGold, size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                best != null
                    ? '${best.elapsedMinutes}m Focus • ${best.topic}'
                    : 'Awaiting Ignition',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                best != null
                    ? '+${best.totalTokensEarned} Tokens Earned (${best.windowMultiplier}x Window)'
                    : 'Complete focus sessions to record your peak state.',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  color: palette.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

      case 2:
        // Card 3: Top Focus Topic
        final top = controller.topFocusTopic;
        final topMinutes = top != null ? (top.value ~/ 60) : 0;
        final topHours = (topMinutes / 60.0).toStringAsFixed(1);

        return SkyGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'TOP FOCUS TOPIC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.secondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.track_changes_rounded, color: palette.mintAura, size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                top?.key ?? 'No Topic Data',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                top != null
                    ? '$topHours hours invested across focus history.'
                    : 'Targeted focus topics will aggregate here.',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  color: palette.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

      case 3:
      default:
        // Card 4: Flow Readiness %
        final profile = controller.flowProfile;
        return SkyGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'FLOW READINESS (ESTIMATE)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.secondaryText,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.bolt_rounded, color: palette.amberGold, size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${profile.flowReadinessPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: palette.amberGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• ${profile.readinessLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                profile.hasSufficientData
                    ? 'Evaluated from historical cadence & session regularity.'
                    : 'Calibrating estimate until 5 sessions are completed.',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  color: palette.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
    }
  }

  /// Central Stepping-Stone Path (empty state or vertical 2.5D white pedestals).
  Widget _buildSteppingStonePath(
    BuildContext context,
    AppController controller,
    List<PlannedSession> planned,
    SkyPalette palette,
  ) {
    if (planned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(palette.isDark ? 0.08 : 0.15),
                  border: Border.all(
                    color: Colors.white.withOpacity(palette.isDark ? 0.20 : 0.35),
                  ),
                ),
                child: Icon(
                  Icons.spa_rounded,
                  color: palette.mintAura,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sanctuary Horizon Clear',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No sessions are currently planned.\nAnchor your next focus intention to place your first stepping-stone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 13,
                  color: palette.secondaryText,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sessions are planned: newly planned sessions stack ABOVE existing ones!
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: planned.length,
      itemBuilder: (context, index) {
        final session = planned[index];

        return Column(
          children: [
            // Pedestal Node
            PedestalNode(
              session: session,
              badgeIcon: Icons.layers_rounded,
              onTap: () {
                SessionDetailDialog.show(
                  context: context,
                  session: session,
                  onStartSession: () => _launchActiveFocus(controller, plannedSession: session),
                  onDeleteSession: () => controller.deletePlannedSession(session.id),
                );
              },
            ),

            // Subtle Dashed Horizontal Separator (if not last)
            if (index < planned.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                child: SizedBox(
                  width: 140,
                  height: 1,
                  child: CustomPaint(
                    painter: _DashedLinePainter(
                      color: Colors.white.withOpacity(palette.isDark ? 0.20 : 0.35),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(math.min(startX + dashWidth, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}
