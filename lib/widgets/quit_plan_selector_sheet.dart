import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/models/quit_plan.dart';
import 'package:ember/models/user_profile.dart';
import 'package:ember/services/supabase_service.dart';

class QuitPlanSelectorSheet extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile>? onPlanUpdated;

  const QuitPlanSelectorSheet({
    super.key,
    required this.profile,
    this.onPlanUpdated,
  });

  static Future<UserProfile?> show(
    BuildContext context, {
    required UserProfile profile,
    ValueChanged<UserProfile>? onPlanUpdated,
  }) {
    return showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuitPlanSelectorSheet(
        profile: profile,
        onPlanUpdated: onPlanUpdated,
      ),
    );
  }

  @override
  State<QuitPlanSelectorSheet> createState() => _QuitPlanSelectorSheetState();
}

class _QuitPlanSelectorSheetState extends State<QuitPlanSelectorSheet> {
  late QuitStrategyType _selectedStrategy;
  late int _baselinePuffs;
  late TextEditingController _customGoalController;
  DateTime? _targetQuitDate;
  bool _saving = false;
  bool _showSchedulePreview = false;

  @override
  void initState() {
    super.initState();
    _selectedStrategy = QuitStrategyType.fromCode(widget.profile.quitStrategy);
    _baselinePuffs = widget.profile.baselinePuffsPerDay ?? 20;
    _customGoalController = TextEditingController(
      text: widget.profile.dailyPuffGoal?.toString() ?? '15',
    );
    _targetQuitDate = widget.profile.targetQuitDate ?? DateTime.now().add(const Duration(days: 45));
  }

  @override
  void dispose() {
    _customGoalController.dispose();
    super.dispose();
  }

  QuitPlan _buildCurrentDraftPlan() {
    return QuitPlan(
      strategyType: _selectedStrategy,
      planStartDate: widget.profile.planStartDate ?? DateTime.now(),
      targetQuitDate: _targetQuitDate,
      baselinePuffs: _baselinePuffs,
      customDailyGoal: int.tryParse(_customGoalController.text),
      weeklyReductionPercent: 10.0,
    );
  }

  Future<void> _pickTargetQuitDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetQuitDate ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'SELECT YOUR TARGET QUIT DATE',
      confirmText: 'SET QUIT DATE',
    );

    if (picked != null) {
      setState(() => _targetQuitDate = picked);
    }
  }

  Future<void> _savePlan() async {
    setState(() => _saving = true);

    try {
      final updated = widget.profile.copyWith(
        quitStrategy: _selectedStrategy.code,
        planStartDate: widget.profile.planStartDate ?? DateTime.now(),
        targetQuitDate: _selectedStrategy == QuitStrategyType.targetQuitDate ? _targetQuitDate : null,
        baselinePuffsPerDay: _baselinePuffs,
        dailyPuffGoal: _selectedStrategy == QuitStrategyType.customGoal
            ? int.tryParse(_customGoalController.text)
            : _buildCurrentDraftPlan().calculateCurrentDailyCeiling(),
        weeklyReductionRate: 10.0,
      );

      final ok = await SupabaseService().upsertUserProfile(updated);

      if (mounted) {
        if (ok) {
          widget.onPlanUpdated?.call(updated);
          Navigator.of(context).pop(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${_selectedStrategy.title} activated!')),
                ],
              ),
              backgroundColor: AppTheme.lowRiskColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update quit plan. Please try again.'),
              backgroundColor: AppTheme.highRiskColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draftPlan = _buildCurrentDraftPlan();
    final todayCeiling = draftPlan.calculateCurrentDailyCeiling();
    final targetInterval = draftPlan.calculateTargetIntervalMinutes();
    final nextMonday = draftPlan.daysUntilNextMonday();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personalized Quit Plan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tapering schedule with Monday auto-adjustments',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan Impact Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.12),
                          AppTheme.primaryGradientEnd.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _PreviewMetric(
                              label: 'Today\'s Ceiling',
                              value: '$todayCeiling puffs',
                              icon: Icons.shield_outlined,
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                            _PreviewMetric(
                              label: 'Min Session Gap',
                              value: targetInterval >= 9999 ? 'Abstinent' : '$targetInterval min',
                              icon: Icons.timer_outlined,
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                            _PreviewMetric(
                              label: 'Next Step-Down',
                              value: draftPlan.isMondayAdjustmentDay()
                                  ? 'Active Today'
                                  : '$nextMonday days',
                              icon: Icons.event_repeat,
                            ),
                          ],
                        ),
                        if (_selectedStrategy == QuitStrategyType.gradualReduction) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.lowRiskColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: AppTheme.lowRiskColor, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Steps down by 10% every Monday until smoke-free',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : AppTheme.lowRiskColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Select Strategy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Strategy Radio Cards
                  _StrategyTile(
                    title: 'Gradual 10% Weekly Step-Down',
                    subtitle: 'Reduces daily puffs by 10% each Monday while widening session gaps to comfortably ease nicotine withdrawal.',
                    badgeText: 'Recommended',
                    badgeColor: AppTheme.lowRiskColor,
                    icon: Icons.trending_down_rounded,
                    isSelected: _selectedStrategy == QuitStrategyType.gradualReduction,
                    onTap: () => setState(() => _selectedStrategy = QuitStrategyType.gradualReduction),
                  ),
                  const SizedBox(height: 10),

                  _StrategyTile(
                    title: 'Target Quit Date',
                    subtitle: 'Set a future smoke-free target date. Daily limits automatically taper down every Monday to hit zero.',
                    badgeText: 'Structured',
                    badgeColor: Colors.blue,
                    icon: Icons.calendar_month_rounded,
                    isSelected: _selectedStrategy == QuitStrategyType.targetQuitDate,
                    onTap: () => setState(() => _selectedStrategy = QuitStrategyType.targetQuitDate),
                    extraWidget: _selectedStrategy == QuitStrategyType.targetQuitDate
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: OutlinedButton.icon(
                              onPressed: _pickTargetQuitDate,
                              icon: const Icon(Icons.date_range, size: 16),
                              label: Text(
                                _targetQuitDate != null
                                    ? 'Target: ${DateFormat('MMM d, yyyy').format(_targetQuitDate!)} (${_targetQuitDate!.difference(DateTime.now()).inDays} days)'
                                    : 'Select Target Quit Date',
                              ),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),

                  _StrategyTile(
                    title: 'Cold Turkey (Immediate)',
                    subtitle: 'Aim for 0 puffs starting today. EMBER\'s 4-7-8 breathing and craving delay tools become your active shield.',
                    badgeText: 'High Challenge',
                    badgeColor: AppTheme.highRiskColor,
                    icon: Icons.ac_unit_rounded,
                    isSelected: _selectedStrategy == QuitStrategyType.coldTurkey,
                    onTap: () => setState(() => _selectedStrategy = QuitStrategyType.coldTurkey),
                  ),
                  const SizedBox(height: 10),

                  _StrategyTile(
                    title: 'Custom Fixed Goal',
                    subtitle: 'Set your own static daily limit without automatic weekly reduction.',
                    badgeText: 'Manual',
                    badgeColor: Colors.grey,
                    icon: Icons.tune_rounded,
                    isSelected: _selectedStrategy == QuitStrategyType.customGoal,
                    onTap: () => setState(() => _selectedStrategy = QuitStrategyType.customGoal),
                    extraWidget: _selectedStrategy == QuitStrategyType.customGoal
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: SizedBox(
                              width: 140,
                              child: TextField(
                                controller: _customGoalController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Daily Max Puffs',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          )
                        : null,
                  ),

                  const SizedBox(height: 20),

                  // Baseline Puffs Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Baseline Usage',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Used to scale your step-down pace',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _baselinePuffs > 5
                                  ? () => setState(() => _baselinePuffs -= 5)
                                  : null,
                            ),
                            Text(
                              '$_baselinePuffs/day',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => _baselinePuffs += 5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Schedule Preview Toggle
                  InkWell(
                    onTap: () => setState(() => _showSchedulePreview = !_showSchedulePreview),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _showSchedulePreview ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showSchedulePreview ? 'Hide Weekly Schedule' : 'Preview Weekly Step-Down Schedule',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showSchedulePreview) ...[
                    const SizedBox(height: 8),
                    _SchedulePreviewTable(plan: draftPlan),
                  ],

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _savePlan,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _saving ? 'Activating Plan...' : 'Activate Quit Plan',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PreviewMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _StrategyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? extraWidget;

  const _StrategyTile({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.extraWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey[600], size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppTheme.primaryColor : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[600],
                height: 1.3,
              ),
            ),
            ?extraWidget,
          ],
        ),
      ),
    );
  }
}

class _SchedulePreviewTable extends StatelessWidget {
  final QuitPlan plan;

  const _SchedulePreviewTable({required this.plan});

  @override
  Widget build(BuildContext context) {
    final schedule = plan.generateWeeklySchedule(maxWeeks: 8);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(flex: 2, child: Text('Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 3, child: Text('Monday Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 2, child: Text('Max Puffs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 2, child: Text('Min Gap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
          const Divider(height: 12),
          ...schedule.map((m) {
            final isCurrent = m.isCurrentWeek;
            final isDone = m.dailyCeiling == 0;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Wk ${m.weekNumber}${isCurrent ? ' •' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? AppTheme.primaryColor : null,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      DateFormat('MMM d').format(m.weekStartDate),
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700]),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      isDone ? '0 (Quit!)' : '${m.dailyCeiling}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDone ? AppTheme.lowRiskColor : null,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      m.targetIntervalMinutes >= 9999 ? 'Done' : '${m.targetIntervalMinutes}m',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
