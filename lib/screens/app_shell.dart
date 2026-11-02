import 'package:flutter/material.dart';
import '../theme/sky_theme.dart';
import 'home_screen.dart';
import 'plan_screen.dart';
import 'stats_screen.dart';

/// Serene Sky Sanctuary: 3-Tab Atmospheric App Shell.
///
/// Navigation architecture:
/// - Strictly 3 tabs:
///   1. Home (Icons.home_rounded)
///   2. Plan (Icons.layers_rounded)
///   3. Stats (Icons.bar_chart_rounded)
/// - Excludes Practice/Tasks tabs.
/// - Atmospheric full-screen gradient canvas driven by active SkyTheme palette.
/// - Translucent frosted sky-glass bottom navigation dock with active amber dot indicators.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentTabIndex = 0;

  void _navigateToTab(int index) {
    if (_currentTabIndex != index) {
      setState(() {
        _currentTabIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);

    final screens = [
      HomeScreen(
        onNavigateToPlan: () => _navigateToTab(1),
      ),
      const PlanScreen(),
      const StatsScreen(),
    ];

    return Scaffold(
      backgroundColor: palette.backgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: palette.backgroundColor,
          gradient: palette.backgroundGradient,
        ),
        child: Stack(
          children: [
            // 1. Tab content stack (leaves clearance for the frosted bottom navigation dock)
            Positioned.fill(
              bottom: 68,
              child: IndexedStack(
                index: _currentTabIndex,
                children: screens,
              ),
            ),

            // 2. Translucent Frosted Glass Bottom Navigation Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNav(context, palette),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, SkyPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.dockBg,
        border: Border(
          top: BorderSide(
            color: palette.glassBorderColor,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavDestination(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                palette: palette,
              ),
              _buildNavDestination(
                index: 1,
                icon: Icons.layers_rounded,
                label: 'Plan',
                palette: palette,
              ),
              _buildNavDestination(
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                palette: palette,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavDestination({
    required int index,
    required IconData icon,
    required String label,
    required SkyPalette palette,
  }) {
    final isSelected = _currentTabIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _navigateToTab(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.08 : 0.96,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  icon,
                  color: isSelected ? palette.navActiveIcon : palette.navInactiveIcon,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? palette.navActiveIcon : palette.navInactiveIcon,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              // Micro Indicator Pill / Amber Dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 14 : 0,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isSelected ? palette.amberGold : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
