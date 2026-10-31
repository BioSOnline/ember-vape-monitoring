import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/models/addiction_score.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/models/session.dart';
import 'package:ember/models/user_profile.dart';
import 'package:ember/models/quit_plan.dart';
import 'package:ember/services/ml_service.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/widgets/mindful_reminder_quotes_card.dart';
import 'package:ember/widgets/theme_toggle_widget.dart';
import 'package:ember/widgets/quit_plan_selector_sheet.dart';
import 'package:ember/screens/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = SupabaseService();

  int _selectedTimeframeDays = 7;
  int _todayCount = 0;
  UserProfile? _profile;
  AddictionScore? _score;
  int? _nextCraving;
  List<PuffEvent> _rangeEvents = [];
  List<Session> _recentSessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final rangeStart = now.subtract(Duration(days: _selectedTimeframeDays));

      final todayF = _service.getTodayPuffCount();
      final profileF = _service.getUserProfile();
      final scoreF = _service.getLatestAddictionScore();
      final eventsF = _service.getPuffEvents(startDate: rangeStart, endDate: now);
      final sessionsF = _service.getSessions(startDate: rangeStart, endDate: now);

      final todayCount = await todayF;
      final profile = await profileF;
      final score = await scoreF;
      final rangeEvents = await eventsF;
      final sessions = await sessionsF;

      int? nextCraving;
      if (rangeEvents.length >= 2 && sessions.isNotEmpty) {
        nextCraving = await MLService().predictNextCravingMinutes(
          puffEvents: rangeEvents,
          sessions: sessions,
        );
      }

      setState(() {
        _todayCount = todayCount;
        _profile = profile;
        _score = score;
        _rangeEvents = rangeEvents;
        _recentSessions = sessions.take(5).toList();
        _nextCraving = nextCraving;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Map of days index relative to timeframe
  List<MapEntry<int, int>> get _dailyCounts {
    final daysCount = _selectedTimeframeDays;
    final map = <int, int>{};
    for (int i = 0; i < daysCount; i++) {
      map[i] = 0;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final event in _rangeEvents) {
      final d = event.detectedAt;
      final eventDay = DateTime(d.year, d.month, d.day);
      final daysAgo = today.difference(eventDay).inDays;
      if (daysAgo >= 0 && daysAgo < daysCount) {
        final key = (daysCount - 1) - daysAgo;
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  Color get _goalColor {
    final goal = _profile?.effectiveDailyGoal ?? _profile?.dailyPuffGoal;
    if (goal == null || goal == 0) {
      if (_profile?.quitPlan.strategyType == QuitStrategyType.coldTurkey && _todayCount > 0) {
        return AppTheme.highRiskColor;
      }
      return AppTheme.primaryColor;
    }
    final ratio = _todayCount / goal;
    if (ratio < 0.7) return AppTheme.lowRiskColor;
    if (ratio < 1.0) return AppTheme.moderateRiskColor;
    return AppTheme.highRiskColor;
  }

  int get _rangeTotal => _rangeEvents.length;
  double get _dailyAvg => _rangeTotal / _selectedTimeframeDays;

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _load();
  }

  void _showPuffHistorySheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag grabber
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Puff Log History',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${_rangeEvents.length} recorded events in past $_selectedTimeframeDays days',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _rangeEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.smoke_free_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No puff events recorded in this window.',
                              style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _rangeEvents.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final event = _rangeEvents[index];
                          final formattedTime = DateFormat('EEE, MMM d • h:mm:ss a').format(event.detectedAt);
                          
                          final isManual = event.inputMode == 'manual';
                          final isVideo = event.inputMode == 'video';
                          final modeColor = isManual
                              ? const Color(0xFF8B5CF6)
                              : isVideo
                                  ? const Color(0xFF3B82F6)
                                  : AppTheme.primaryColor;
                          final modeIcon = isManual
                              ? Icons.edit_note_rounded
                              : isVideo
                                  ? Icons.video_file_outlined
                                  : Icons.camera_alt_rounded;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: modeColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(modeIcon, color: modeColor, size: 20),
                            ),
                            title: Text(
                              formattedTime,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: modeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    event.inputMode.toUpperCase(),
                                    style: TextStyle(
                                      color: modeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: event.confidenceScore != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${(event.confidenceScore! * 100).toInt()}% conf',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Dashboard'),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: CuteThemeToggleWidget(),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _openProfile,
            tooltip: 'User Profile',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.history_outlined),
            onPressed: _showPuffHistorySheet,
            tooltip: 'Puff Log History',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeframe Filter Switcher
                        _TimeframeSelector(
                          selectedDays: _selectedTimeframeDays,
                          onChanged: (days) {
                            setState(() => _selectedTimeframeDays = days);
                            _load();
                          },
                        ),
                        const SizedBox(height: 16),

                        // Rotating Mindful Reminders & Quotes
                        const MindfulReminderQuotesCard(),
                        const SizedBox(height: 16),

                        _SummaryRow(
                          rangeTotal: _rangeTotal,
                          dailyAvg: _dailyAvg,
                          sessionCount: _recentSessions.length,
                          timeframeDays: _selectedTimeframeDays,
                        ),
                        const SizedBox(height: 16),
                        
                        _DailyGoalCard(
                          todayCount: _todayCount,
                          profile: _profile,
                          goalColor: _goalColor,
                          onCustomizePlan: () async {
                            if (_profile != null) {
                              final updated = await QuitPlanSelectorSheet.show(
                                context,
                                profile: _profile!,
                                onPlanUpdated: (newProfile) {
                                  setState(() => _profile = newProfile);
                                },
                              );
                              if (updated != null) {
                                _load();
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _AddictionScoreCard(score: _score),
                        const SizedBox(height: 16),
                        
                        _WeeklyTrendCard(
                          dailyCounts: _dailyCounts,
                          rangeTotal: _rangeTotal,
                          timeframeDays: _selectedTimeframeDays,
                        ),
                        
                        if (_nextCraving != null) ...[
                          const SizedBox(height: 16),
                          _CravingCard(minutes: _nextCraving!),
                        ],
                        
                        const SizedBox(height: 16),
                        _RecentSessionsCard(sessions: _recentSessions),
                        const SizedBox(height: 80), // Fab space
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ─── Timeframe Selector ───────────────────────────────────────────────────────

class _TimeframeSelector extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onChanged;

  const _TimeframeSelector({
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [7, 14, 30];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: options.map((days) {
        final isSelected = selectedDays == days;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => onChanged(days),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? AppTheme.darkSurfaceHigh : AppTheme.lightSurfaceHigh),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? AppTheme.darkSurfaceHighest : AppTheme.lightSurfaceHighest),
                ),
              ),
              child: Text(
                '$days Days',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int rangeTotal;
  final double dailyAvg;
  final int sessionCount;
  final int timeframeDays;

  const _SummaryRow({
    required this.rangeTotal,
    required this.dailyAvg,
    required this.sessionCount,
    required this.timeframeDays,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatChip(label: '$timeframeDays Days Total', value: '$rangeTotal', icon: Icons.calendar_view_week)),
        const SizedBox(width: 12),
        Expanded(child: _StatChip(label: 'Daily Avg', value: dailyAvg.toStringAsFixed(1), icon: Icons.show_chart)),
        const SizedBox(width: 12),
        Expanded(child: _StatChip(label: 'Sessions', value: '$sessionCount', icon: Icons.timer_outlined)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Daily Goal & Quit Plan Card ─────────────────────────────────────────────

class _DailyGoalCard extends StatelessWidget {
  final int todayCount;
  final UserProfile? profile;
  final Color goalColor;
  final VoidCallback? onCustomizePlan;

  const _DailyGoalCard({
    required this.todayCount,
    this.profile,
    required this.goalColor,
    this.onCustomizePlan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = profile?.quitPlan;
    final effectiveGoal = profile?.effectiveDailyGoal ?? profile?.dailyPuffGoal;
    final isColdTurkey = plan?.strategyType == QuitStrategyType.coldTurkey;
    final isMonday = plan?.isMondayAdjustmentDay() ?? (DateTime.now().weekday == DateTime.monday);

    final progress = effectiveGoal != null && effectiveGoal > 0
        ? (todayCount / effectiveGoal).clamp(0.0, 1.0)
        : (isColdTurkey ? (todayCount > 0 ? 1.0 : 0.0) : null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Plan Strategy Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.track_changes, size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 5),
                      Text(
                        plan != null
                            ? '${plan.strategyType.title} · Wk ${plan.currentWeekNumber()}'
                            : 'Daily Target Goal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (onCustomizePlan != null)
                  InkWell(
                    onTap: onCustomizePlan,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, size: 13, color: AppTheme.primaryColor),
                          SizedBox(width: 4),
                          Text(
                            'Edit Plan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Monday Adjustment Alert Banner
            if (isMonday && plan != null && plan.strategyType == QuitStrategyType.gradualReduction) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.lowRiskColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.lowRiskColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration, color: AppTheme.lowRiskColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Monday Step-Down Applied: Ceiling lowered to $effectiveGoal puffs this week. Keep strong!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 7,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          color: goalColor,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$todayCount',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: goalColor,
                                  fontSize: 26,
                                  height: 1,
                                ),
                          ),
                          Text(
                            'puffs',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isColdTurkey ? 'Cold Turkey Target: 0' : "Today's Ceiling",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                      ),
                      const SizedBox(height: 3),
                      if (effectiveGoal != null && effectiveGoal > 0) ...[
                        Text(
                          '$todayCount of $effectiveGoal allowed puffs',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              todayCount <= effectiveGoal ? Icons.trending_down : Icons.warning_amber_rounded,
                              size: 14,
                              color: goalColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              todayCount <= effectiveGoal
                                  ? '${effectiveGoal - todayCount} remaining today'
                                  : '${todayCount - effectiveGoal} over ceiling',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: goalColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ] else if (isColdTurkey) ...[
                        Text(
                          todayCount == 0
                              ? '100% Smoke-Free today! Amazing work.'
                              : '$todayCount slip(s) logged. Use Craving Relief to recover.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: todayCount == 0 ? AppTheme.lowRiskColor : AppTheme.highRiskColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ] else ...[
                        Text(
                          '$todayCount puffs logged today',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No active quit plan',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (plan != null && !isColdTurkey) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 5),
                      Text(
                        'Min Session Gap: ${plan.calculateTargetIntervalMinutes()}m',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.event_repeat, size: 14, color: AppTheme.secondaryColor),
                      const SizedBox(width: 5),
                      Text(
                        isMonday
                            ? 'Adjusted today!'
                            : 'Next step: Mon (${plan.daysUntilNextMonday()}d)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Addiction Score Card ─────────────────────────────────────────────────────

class _AddictionScoreCard extends StatelessWidget {
  final AddictionScore? score;

  const _AddictionScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Addiction Risk Assessment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Icon(Icons.psychology_outlined, size: 20, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),
            if (score == null) ...[
              Row(
                children: [
                  Icon(Icons.hourglass_empty, size: 18, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Decision Tree classifier requires at least 3 days of usage data.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LevelBadge(level: score!.level, color: Color(score!.levelColor)),
                  const SizedBox(width: 16),
                  Text(
                    score!.scoreValue.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Color(score!.levelColor),
                          height: 1,
                        ),
                  ),
                  Text(
                    ' / 100',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: score!.scoreValue / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  color: Color(score!.levelColor),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                score!.levelDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.insights_outlined, size: 15, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Primary Driver: ${score!.topFeature}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  final Color color;

  const _LevelBadge({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Weekly Trend Card ────────────────────────────────────────────────────────

class _WeeklyTrendCard extends StatelessWidget {
  final List<MapEntry<int, int>> dailyCounts;
  final int rangeTotal;
  final int timeframeDays;

  const _WeeklyTrendCard({
    required this.dailyCounts,
    required this.rangeTotal,
    required this.timeframeDays,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxCount = dailyCounts.map((e) => e.value).fold(0, (a, b) => a > b ? a : b);
    final maxY = (maxCount + 2).toDouble().clamp(5.0, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$timeframeDays-Day Usage Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '$rangeTotal total puffs logged',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text('Today', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: rangeTotal == 0
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'No puff events recorded for this timeframe',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[400],
                                ),
                          ),
                        ],
                      ),
                    )
                  : BarChart(
                      key: ValueKey('bar_chart_${timeframeDays}_${Theme.of(context).brightness}'),
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AppTheme.primaryColor.withValues(alpha: 0.9),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final dayIndex = group.x;
                              final daysAgo = (timeframeDays - 1) - dayIndex;
                              final date = DateTime.now().subtract(Duration(days: daysAgo));
                              final dateStr = DateFormat('EEE, MMM d').format(date);
                              final count = rod.toY.toInt();
                              return BarTooltipItem(
                                '$dateStr\n$count puff${count == 1 ? '' : 's'}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final dayIndex = value.toInt();
                                if (dayIndex < 0 || dayIndex >= timeframeDays) {
                                  return const SizedBox.shrink();
                                }

                                final daysAgo = (timeframeDays - 1) - dayIndex;
                                final isToday = dayIndex == (timeframeDays - 1);

                                // Avoid label clutter by spacing ticks evenly ending on today
                                final bool showLabel;
                                if (timeframeDays <= 7) {
                                  showLabel = true;
                                } else if (timeframeDays <= 14) {
                                  // 14 days: show every 2 days (7 labels total)
                                  showLabel = daysAgo % 2 == 0;
                                } else {
                                  // 30 days: show every 5 days (6 labels total)
                                  showLabel = daysAgo % 5 == 0;
                                }

                                if (!showLabel) {
                                  return const SizedBox.shrink();
                                }

                                final day = DateTime.now().subtract(Duration(days: daysAgo));

                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    timeframeDays <= 7
                                        ? DateFormat('E').format(day)
                                        : '${day.day}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isToday ? AppTheme.primaryColor : Colors.grey[500],
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 10,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: dailyCounts.map((entry) {
                          final isToday = entry.key == (timeframeDays - 1);
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                width: timeframeDays > 14
                                    ? 6
                                    : (timeframeDays > 7 ? 12 : 18),
                                color: isToday
                                    ? AppTheme.primaryColor
                                    : AppTheme.primaryColor.withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Craving Prediction Card ──────────────────────────────────────────────────

class _CravingCard extends StatelessWidget {
  final int minutes;

  const _CravingCard({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    if (minutes < 15) {
      color = AppTheme.highRiskColor;
      label = 'High Risk';
      icon = Icons.warning_amber_rounded;
    } else if (minutes < 45) {
      color = AppTheme.moderateRiskColor;
      label = 'Upcoming';
      icon = Icons.schedule;
    } else {
      color = AppTheme.lowRiskColor;
      label = 'Low Risk';
      icon = Icons.check_circle_outline;
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Predicted Craving Window',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'In approximately $timeStr',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Linear Regression pattern estimate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Sessions Card ─────────────────────────────────────────────────────

class _RecentSessionsCard extends StatelessWidget {
  final List<Session> sessions;

  const _RecentSessionsCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Active & Past Sessions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Icon(Icons.history, size: 18, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined, size: 18, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      'No sessions recorded yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              )
            else
              ...sessions.map((s) => _SessionTile(session: s)),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final duration = session.durationMinutes;
    final timeStr = DateFormat('MMM d, h:mm a').format(session.startedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: session.isActive
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              session.isActive ? Icons.radio_button_checked : Icons.check_circle_outline,
              color: session.isActive ? AppTheme.primaryColor : Colors.grey[400],
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  session.isActive
                      ? 'Active session in progress'
                      : [
                          '${session.puffCount} puff${session.puffCount == 1 ? '' : 's'}',
                          if (duration != null) '${duration.toStringAsFixed(0)} min',
                          if (session.avgIntervalSec != null) '${(session.avgIntervalSec!).toInt()}s avg int',
                        ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          if (session.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else
            Text(
              '${session.puffCount}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
            ),
        ],
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
