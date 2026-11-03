import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../state/app_controller.dart';
import '../theme/sky_theme.dart';
import '../widgets/sky_glass_widgets.dart';

/// Tab 2: Plan Screen (Serene Sky Sanctuary).
///
/// Features:
/// - Segmented glass toggle switching between [Sessions] and [Goals].
/// - Approaching Deadline Section: Highlighted section with Deadline Alert Coral (0xFFFF6B6B)
///   for items due today, overdue, or within 24 hours. Completely hidden if empty; partitioned without duplicates.
/// - Docked Dual Half-Size Pill Buttons (52px height, 12px gap):
///   * [+ Plan Session]: Duration, preferred window picker (start/end), Topic/Goal free text & dropdown.
///   * [+ New Goal]: Required title, optional deadline picker, validation.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  /// Displays the modal sheet to plan a new focus session.
  static void showPlanSessionModal(
    BuildContext context,
    AppController controller,
    SkyPalette palette,
  ) {
    _PlanScreenState.showPlanSessionModal(context, controller, palette);
  }

  /// Displays the modal sheet to create a new goal.
  static void showNewGoalModal(
    BuildContext context,
    AppController controller,
    SkyPalette palette,
  ) {
    _PlanScreenState.showNewGoalModal(context, controller, palette);
  }

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _selectedView = 0; // 0: Sessions, 1: Goals

  @override
  Widget build(BuildContext context) {
    final palette = SkyThemeScope.paletteOf(context);
    final controller = AppControllerScope.of(context);
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // 1. Frosted 2-Pill Segmented Toggle
          _buildSegmentedToggle(palette),

          const SizedBox(height: 14),

          // 2. Main Content (Approaching Deadline + Partitioned Normal List)
          Expanded(
            child: _selectedView == 0
                ? _buildSessionsView(controller, palette, now)
                : _buildGoalsView(controller, palette, now),
          ),

          // 3. Docked Dual Half-Size Pill Buttons (54px height, 12px gap)
          _buildBottomActionButtons(context, controller, palette),
        ],
      ),
    );
  }

  Widget _buildSegmentedToggle(SkyPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(palette.isDark ? 0.08 : 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(palette.isDark ? 0.18 : 0.30),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSegmentButton(
                label: 'Sessions',
                index: 0,
                palette: palette,
              ),
            ),
            Expanded(
              child: _buildSegmentButton(
                label: 'Goals',
                index: 1,
                palette: palette,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required int index,
    required SkyPalette palette,
  }) {
    final isSelected = _selectedView == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedView = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF0F172A)
                : palette.secondaryText,
          ),
        ),
      ),
    );
  }

  // --- Sessions View Partitioning ---

  Widget _buildSessionsView(AppController controller, SkyPalette palette, DateTime now) {
    final uncompleted = controller.plannedSessions.where((s) => !s.isCompleted).toList();

    // Partition without duplication
    final approaching = uncompleted.where((s) => s.isApproachingDeadline(now)).toList();
    final normal = uncompleted.where((s) => !s.isApproachingDeadline(now)).toList();

    if (uncompleted.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Approaching Deadline Section (Completely hidden if empty!)
        if (approaching.isNotEmpty) ...[
          _buildApproachingHeader('NEAR DEADLINE', palette),
          const SizedBox(height: 8),
          ...approaching.map((session) => _buildSessionCard(session, controller, palette, isApproaching: true)),
          const SizedBox(height: 16),
        ],

        // 2. Normal Sessions Section
        if (normal.isNotEmpty) ...[
          if (approaching.isNotEmpty) _buildSectionHeader('OTHER PLANNED SESSIONS', palette),
          const SizedBox(height: 8),
          ...normal.map((session) => _buildSessionCard(session, controller, palette, isApproaching: false)),
        ],
      ],
    );
  }

  Widget _buildSessionCard(
    PlannedSession session,
    AppController controller,
    SkyPalette palette, {
    required bool isApproaching,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: SkyGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(20),
        borderColor: isApproaching ? palette.deadlineAlertCoral : null,
        borderWidth: isApproaching ? 1.5 : null,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isApproaching
                    ? palette.deadlineAlertCoral.withOpacity(0.20)
                    : Colors.white.withOpacity(0.12),
                border: Border.all(
                  color: isApproaching ? palette.deadlineAlertCoral : Colors.white.withOpacity(0.35),
                  width: 1.0,
                ),
              ),
              child: Icon(
                isApproaching ? Icons.alarm_on_rounded : Icons.layers_rounded,
                color: isApproaching ? palette.deadlineAlertCoral : palette.amberGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          session.topic,
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isApproaching) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: palette.deadlineAlertCoral.withOpacity(0.25),
                          ),
                          child: Text(
                            'Active Window',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: palette.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${session.plannedDurationMinutes}m Focus • ${session.preferredWindow?.toDisplayString() ?? "Flexible Window"}',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 11,
                      color: palette.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: palette.secondaryText.withOpacity(0.8), size: 20),
              onPressed: () => controller.deletePlannedSession(session.id),
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  // --- Goals View Partitioning ---

  Widget _buildGoalsView(AppController controller, SkyPalette palette, DateTime now) {
    final uncompleted = controller.goals.where((g) => !g.isCompleted).toList();

    final approaching = uncompleted.where((g) => g.isApproachingDeadline(now)).toList();
    final normal = uncompleted.where((g) => !g.isApproachingDeadline(now)).toList();

    if (uncompleted.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Approaching Deadline Section (Completely hidden if empty!)
        if (approaching.isNotEmpty) ...[
          _buildApproachingHeader('NEAR DEADLINE', palette),
          const SizedBox(height: 8),
          ...approaching.map((goal) => _buildGoalCard(goal, controller, palette, isApproaching: true)),
          const SizedBox(height: 16),
        ],

        // 2. Normal Goals Section
        if (normal.isNotEmpty) ...[
          if (approaching.isNotEmpty) _buildSectionHeader('ONGOING GOALS', palette),
          const SizedBox(height: 8),
          ...normal.map((goal) => _buildGoalCard(goal, controller, palette, isApproaching: false)),
        ],
      ],
    );
  }

  Widget _buildGoalCard(
    Goal goal,
    AppController controller,
    SkyPalette palette, {
    required bool isApproaching,
  }) {
    final deadlineStr = goal.deadlineDate != null
        ? 'Deadline: ${goal.deadlineDate!.year}-${goal.deadlineDate!.month.toString().padLeft(2, '0')}-${goal.deadlineDate!.day.toString().padLeft(2, '0')}'
        : 'Open Horizon';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: SkyGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(20),
        borderColor: isApproaching ? palette.deadlineAlertCoral : null,
        borderWidth: isApproaching ? 1.5 : null,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => controller.toggleGoalCompletion(goal.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(
                    color: isApproaching ? palette.deadlineAlertCoral : Colors.white.withOpacity(0.40),
                    width: 1.5,
                  ),
                ),
                child: goal.isCompleted
                    ? Icon(Icons.check_rounded, color: palette.mintAura, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          goal.title,
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isApproaching) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: palette.deadlineAlertCoral.withOpacity(0.25),
                          ),
                          child: Text(
                            'Urgent',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: palette.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    deadlineStr,
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 11,
                      color: isApproaching ? palette.deadlineAlertCoral : palette.secondaryText,
                      fontWeight: isApproaching ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: palette.secondaryText.withOpacity(0.8), size: 20),
              onPressed: () => controller.deleteGoal(goal.id),
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproachingHeader(String title, SkyPalette palette) {
    return Row(
      children: [
        Icon(Icons.priority_high_rounded, color: palette.deadlineAlertCoral, size: 16),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette.deadlineAlertCoral,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, SkyPalette palette) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: palette.secondaryText,
        letterSpacing: 0.8,
      ),
    );
  }

  // --- Docked Dual Action Buttons ---

  Widget _buildBottomActionButtons(BuildContext context, AppController controller, SkyPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(
        children: [
          // Left: + Plan Session (54px height)
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.pillButtonBg,
                  foregroundColor: palette.pillButtonText,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                ),
                onPressed: () => showPlanSessionModal(context, controller, palette),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+ Plan Session',
                    style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right: + New Goal (54px height)
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.pillButtonBg,
                  foregroundColor: palette.pillButtonText,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                ),
                onPressed: () => showNewGoalModal(context, controller, palette),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+ New Goal',
                    style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Session Planning Modal ---

  static void showPlanSessionModal(BuildContext context, AppController controller, SkyPalette palette) {
    int duration = 25;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
    bool hasWindow = true;
    String? selectedGoalId;
    final topicController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Centered 36x4px top drag handle pill
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'New Session',
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Unified Frosted Input Group: TextField
                      SizedBox(
                        height: 54,
                        child: TextField(
                          controller: topicController,
                          style: const TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 15,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Focus topic...',
                            hintStyle: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.60),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      // Selectable Goal Pill Chips (only if goals exist)
                      if (controller.goals.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setModalState(() => selectedGoalId = null),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: selectedGoalId == null
                                        ? const Color(0xFFFFFFFF)
                                        : Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'No goal',
                                    style: TextStyle(
                                      fontFamily: 'sans-serif',
                                      fontSize: 13,
                                      fontWeight: selectedGoalId == null ? FontWeight.w700 : FontWeight.w500,
                                      color: selectedGoalId == null
                                          ? const Color(0xFF0F172A)
                                          : Colors.white.withOpacity(0.90),
                                    ),
                                  ),
                                ),
                              ),
                              ...controller.goals.map((g) {
                                final isSelected = selectedGoalId == g.id;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedGoalId = g.id;
                                      if (topicController.text.trim().isEmpty) {
                                        topicController.text = g.title;
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFFFFFF)
                                          : Colors.white.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      g.title,
                                      style: TextStyle(
                                        fontFamily: 'sans-serif',
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF0F172A)
                                            : Colors.white.withOpacity(0.90),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Duration Selector (5 equal-width pills, height 44px, borderRadius 14px, 8px gap)
                      Row(
                        children: [15, 25, 45, 60, 90].map((d) {
                          final isSelected = duration == d;
                          final isLast = d == 90;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: isLast ? 0 : 8),
                              child: GestureDetector(
                                onTap: () => setModalState(() => duration = d),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFFFFF)
                                        : Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${d}m',
                                      style: TextStyle(
                                        fontFamily: 'sans-serif',
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF0F172A)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      // Preferred Time Window: Unified Frosted Card (borderRadius 18px, padding 14px)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Time Window',
                                    style: TextStyle(
                                      fontFamily: 'sans-serif',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: hasWindow,
                                  onChanged: (val) => setModalState(() => hasWindow = val),
                                  activeColor: const Color(0xFFFFFFFF),
                                  activeTrackColor: const Color(0xFFFFB547),
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withOpacity(0.20),
                                ),
                              ],
                            ),
                            if (hasWindow) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final picked = await showTimePicker(context: ctx, initialTime: startTime);
                                        if (picked != null) setModalState(() => startTime = picked);
                                      },
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            startTime.format(ctx),
                                            style: const TextStyle(
                                              fontFamily: 'sans-serif',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final picked = await showTimePicker(context: ctx, initialTime: endTime);
                                        if (picked != null) setModalState(() => endTime = picked);
                                      },
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            endTime.format(ctx),
                                            style: const TextStyle(
                                              fontFamily: 'sans-serif',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Full-width Cloud White Pill Button: "Save Session" (height 54px, deep navy bold text)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFFFFF),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            final topic = topicController.text.trim();
                            if (topic.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Please enter a session topic.')),
                              );
                              return;
                            }

                            controller.addPlannedSession(
                              topic: topic,
                              plannedDurationMinutes: duration,
                              preferredWindow: hasWindow
                                  ? TimeWindow(
                                      startHour: startTime.hour,
                                      startMinute: startTime.minute,
                                      endHour: endTime.hour,
                                      endMinute: endTime.minute,
                                    )
                                  : null,
                              linkedGoalId: selectedGoalId,
                            );
                            Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'Save Session',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Goal Creation Modal ---

  static void showNewGoalModal(BuildContext context, AppController controller, SkyPalette palette) {
    DateTime? selectedDeadline;
    final titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Centered 36x4px top drag handle pill
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'New Goal',
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Clean Frosted TextField (height 54px, borderRadius 18px, hintText "Goal title...")
                      SizedBox(
                        height: 54,
                        child: TextField(
                          controller: titleController,
                          style: const TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 15,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Goal title...',
                            hintStyle: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.60),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 52px Frosted Row: Icons.event_rounded (size 18, white) and text "Target Date" on left, tappable pill on right
                      Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Target Date',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDeadline ?? DateTime.now().add(const Duration(days: 3)),
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) setModalState(() => selectedDeadline = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selectedDeadline != null
                                      ? Colors.white.withOpacity(0.25)
                                      : Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      selectedDeadline != null
                                          ? '${selectedDeadline!.year}-${selectedDeadline!.month.toString().padLeft(2, '0')}-${selectedDeadline!.day.toString().padLeft(2, '0')}'
                                          : 'Optional',
                                      style: TextStyle(
                                        fontFamily: 'sans-serif',
                                        fontSize: 13,
                                        fontWeight: selectedDeadline != null ? FontWeight.w600 : FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (selectedDeadline != null) ...[
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => setModalState(() => selectedDeadline = null),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Bottom Cloud White Pill Button: "Save Goal" (height 54px)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFFFFF),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Please enter a goal title.')),
                              );
                              return;
                            }

                            controller.addGoal(
                              title: title,
                              deadlineDate: selectedDeadline,
                            );
                            Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'Save Goal',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
