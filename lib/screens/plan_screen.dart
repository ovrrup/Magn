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
          const SizedBox(height: 8),

          // 1. Top Header & Segmented Glass Toggle
          _buildHeaderAndToggle(palette),

          const SizedBox(height: 12),

          // 2. Main Content (Approaching Deadline + Partitioned Normal List)
          Expanded(
            child: _selectedView == 0
                ? _buildSessionsView(controller, palette, now)
                : _buildGoalsView(controller, palette, now),
          ),

          // 3. Docked Dual Half-Size Pill Buttons (52px height, 12px gap)
          _buildBottomActionButtons(context, controller, palette),
        ],
      ),
    );
  }

  Widget _buildHeaderAndToggle(SkyPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan & Horizons',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.primaryText,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),

          // Segmented Glass Toggle: [Sessions] vs [Goals]
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(palette.isDark ? 0.08 : 0.15),
              borderRadius: BorderRadius.circular(20),
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
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(palette.isDark ? 0.28 : 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.50), width: 1.0)
              : null,
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? palette.primaryText : palette.secondaryText,
            ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.layers_clear_rounded, color: palette.secondaryText, size: 40),
              const SizedBox(height: 12),
              Text(
                'No Planned Sessions',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "+ Plan Session" below to anchor your upcoming focus intervals.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'sans-serif', fontSize: 13, color: palette.secondaryText),
              ),
            ],
          ),
        ),
      );
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_outlined, color: palette.secondaryText, size: 40),
              const SizedBox(height: 12),
              Text(
                'No Active Goals',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "+ New Goal" below to define target objectives and milestones.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'sans-serif', fontSize: 13, color: palette.secondaryText),
              ),
            ],
          ),
        ),
      );
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
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Plan Focus Session',
                            style: TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.primaryText,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Topic Input
                      Text('TOPIC / FOCUS INTENTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.secondaryText)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: topicController,
                        style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, color: palette.primaryText),
                        decoration: InputDecoration(
                          hintText: 'e.g. Architecture Blueprint Refactor',
                          hintStyle: TextStyle(color: palette.secondaryText.withOpacity(0.6)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),

                      // Linked Goal Dropdown (if goals exist)
                      if (controller.goals.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('LINK TO EXISTING GOAL (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.secondaryText)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButton<String?>(
                            value: selectedGoalId,
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
                            style: TextStyle(fontFamily: 'sans-serif', color: palette.primaryText),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('No linked goal')),
                              ...controller.goals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.title))),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                selectedGoalId = val;
                                if (val != null && topicController.text.isEmpty) {
                                  final g = controller.goals.firstWhere((x) => x.id == val);
                                  topicController.text = g.title;
                                }
                              });
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Duration Selector
                      Text('PLANNED DURATION (MINUTES)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.secondaryText)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [15, 25, 45, 60, 90].map((d) {
                          final isSelected = duration == d;
                          return ChoiceChip(
                            label: Text('${d}m'),
                            selected: isSelected,
                            onSelected: (_) => setModalState(() => duration = d),
                            selectedColor: palette.amberGold,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : palette.primaryText,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.12),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // Preferred Window Picker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('PREFERRED TIME WINDOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.secondaryText)),
                          Switch(
                            value: hasWindow,
                            onChanged: (val) => setModalState(() => hasWindow = val),
                            activeColor: palette.amberGold,
                          ),
                        ],
                      ),
                      if (hasWindow) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.schedule_rounded, size: 16),
                                label: Text(startTime.format(ctx)),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.12),
                                  foregroundColor: palette.primaryText,
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(context: ctx, initialTime: startTime);
                                  if (picked != null) setModalState(() => startTime = picked);
                                },
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to', style: TextStyle(color: Colors.white))),
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.schedule_rounded, size: 16),
                                label: Text(endTime.format(ctx)),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.12),
                                  foregroundColor: palette.primaryText,
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(context: ctx, initialTime: endTime);
                                  if (picked != null) setModalState(() => endTime = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Save Button
                      SkyPillButton(
                        label: 'Save Planned Session',
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
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFF3888E6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Focus Goal',
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: palette.primaryText,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text('GOAL TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.secondaryText)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: titleController,
                      style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, color: palette.primaryText),
                      decoration: InputDecoration(
                        hintText: 'e.g. Complete System Engine Specification',
                        hintStyle: TextStyle(color: palette.secondaryText.withOpacity(0.6)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Deadline Picker
                    Text('TARGET DEADLINE (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.secondaryText)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text(
                              selectedDeadline != null
                                  ? '${selectedDeadline!.year}-${selectedDeadline!.month.toString().padLeft(2, '0')}-${selectedDeadline!.day.toString().padLeft(2, '0')}'
                                  : 'Select Deadline Date',
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                              foregroundColor: palette.primaryText,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDeadline ?? DateTime.now().add(const Duration(days: 3)),
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setModalState(() => selectedDeadline = picked);
                            },
                          ),
                        ),
                        if (selectedDeadline != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white),
                            onPressed: () => setModalState(() => selectedDeadline = null),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SkyPillButton(
                      label: 'Create Goal',
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
