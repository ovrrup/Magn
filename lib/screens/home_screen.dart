import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';
import '../widgets/pedestal_node.dart';
import '../widgets/sky_glass_widgets.dart';
import 'active_focus_screen.dart';
import 'plan_screen.dart';
import 'settings_sheet.dart';

/// Tab 1: Home Screen (Serene Sky Sanctuary).
///
/// Strictly adheres to:
/// - (1) When plannedSessions is empty, renders ONLY const SizedBox.shrink() in the center area.
///   (Strictly NO sprout icon, NO "Sanctuary Horizon Clear", NO instructional sentences or empty-state paragraphs).
/// - (2) Inside top carousel cards, NEVER renders instructional sentences. Each card displays ONLY
///   an 11px uppercase label, a 26px bold primary value, and a short 13px metadata pill.
/// - (3) Never glued onto the bottom nav bar: enforces an exact 14px bottom margin gap.
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
          // 1. Top Row (padding horizontal 20px, top 12px)
          _buildTopRow(context, controller, palette),

          // 2. Looping Peek-Edge Hero Carousel (height 112px, top margin 16px)
          _buildHeroCarousel(controller, palette),

          // 3. Center Stepping-Stone Path (Expanded)
          Expanded(
            child: _buildSteppingStonePath(context, controller, planned, palette),
          ),

          // 4. Docked Primary Pill Button (height 54px, horizontal margin 20px, bottom margin 14px above nav bar)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFFFF), // Cloud White #FFFFFF
                  foregroundColor: const Color(0xFF0F172A), // Deep navy #0F172A
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
                onPressed: () {
                  if (nextSession != null) {
                    _launchActiveFocus(controller, plannedSession: nextSession);
                  } else {
                    PlanScreen.showPlanSessionModal(context, controller, palette);
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (nextSession != null) ...[
                      const Icon(Icons.play_arrow_rounded, size: 22, color: Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        nextSession != null
                            ? 'Start • ${nextSession.topicTitle}'
                            : 'Plan a Session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, AppController controller, SkyPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: 42x42px circular frosted Settings button (Icons.tune_rounded, size 20)
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

          // Right: Two compact frosted pills (8px gap, height 38px, horizontal padding 14px)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Streak Pill
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  color: Colors.white.withOpacity(palette.isDark ? 0.12 : 0.18),
                  border: Border.all(
                    color: Colors.white.withOpacity(palette.isDark ? 0.20 : 0.32),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: palette.amberGold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
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

              // Tokens Pill
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  color: Colors.white.withOpacity(palette.isDark ? 0.12 : 0.18),
                  border: Border.all(
                    color: Colors.white.withOpacity(palette.isDark ? 0.20 : 0.32),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: palette.amberGold,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
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

  /// Looping Peek-Edge Hero Carousel (height 112px, top margin 16px)
  Widget _buildHeroCarousel(AppController controller, SkyPalette palette) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      height: 112,
      child: PageView.builder(
        controller: _carouselPageController,
        physics: const BouncingScrollPhysics(),
        itemCount: 10000,
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
                scale = index == _currentCarouselPage ? 1.0 : 0.86;
              }

              return Transform.scale(
                scale: scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
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
    String label;
    String value;
    String subtitle;

    switch (cardIndex) {
      case 0:
        // Card 0: NEXT PLANNED
        label = 'NEXT PLANNED';
        final next = controller.nextPlannedSession;
        value = next?.topicTitle ?? 'No Plan';
        subtitle = next != null
            ? '${next.preferredWindow?.toDisplayString() ?? "Flexible Window"} • +${next.estimatedBaseTokens} Tokens'
            : 'Tap button below';
        break;

      case 1:
        // Card 1: BEST SESSION
        label = 'BEST SESSION';
        final best = controller.bestSession;
        value = best != null ? '${best.elapsedMinutes}m • +${best.totalTokensEarned}' : '0m';
        subtitle = best?.topicTitle ?? 'None';
        break;

      case 2:
        // Card 2: TOP FOCUS TOPIC
        label = 'TOP FOCUS TOPIC';
        final top = controller.topFocusTopic;
        final topMinutes = top != null ? (top.value ~/ 60) : 0;
        value = top?.key ?? 'None';
        subtitle = top != null
            ? '${(topMinutes / 60.0).toStringAsFixed(1)}h logged (${topMinutes}m)'
            : '0m logged';
        break;

      case 3:
      default:
        // Card 3: FLOW READINESS
        label = 'FLOW READINESS';
        value = '${controller.flowReadinessPercent.round()}%';
        subtitle = 'Based on ${controller.completedSessions.length} sessions';
        break;
    }

    return SkyGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 11px uppercase label
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.secondaryText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),

          // 26px bold primary value
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: palette.primaryText,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),

          // Short 13px metadata pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(palette.isDark ? 0.08 : 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(palette.isDark ? 0.15 : 0.25),
                width: 0.5,
              ),
            ),
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Center Stepping-Stone Path (Expanded):
  /// STRICT CONSTRAINT: if plannedSessions is empty, return const SizedBox.shrink()
  /// (Strictly NO icons, NO "Sanctuary Horizon Clear", NO instructional sentences or paragraphs).
  Widget _buildSteppingStonePath(
    BuildContext context,
    AppController controller,
    List<PlannedSession> planned,
    SkyPalette palette,
  ) {
    if (planned.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sessions are planned: newly added sessions stack UPWARD above existing ones (reverse: true)
    return Center(
      child: SingleChildScrollView(
        reverse: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(planned.length, (index) {
            final session = planned[index];
            final sessionNumber = planned.length - index;

            return Column(
              mainAxisSize: MainAxisSize.min,
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

                // Subtle 1px dashed horizontal divider line labeled with session number
                if (index < planned.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 1,
                          child: CustomPaint(
                            painter: _DashedLinePainter(
                              color: Colors.white.withOpacity(palette.isDark ? 0.20 : 0.35),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(palette.isDark ? 0.08 : 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(palette.isDark ? 0.18 : 0.28),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              'Session #$sessionNumber',
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: palette.secondaryText,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 1,
                          child: CustomPaint(
                            painter: _DashedLinePainter(
                              color: Colors.white.withOpacity(palette.isDark ? 0.20 : 0.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
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
