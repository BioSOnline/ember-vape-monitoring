import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/widgets/theme_toggle_widget.dart';

class ReliefScreen extends StatefulWidget {
  const ReliefScreen({super.key});

  @override
  State<ReliefScreen> createState() => _ReliefScreenState();
}

class _ReliefScreenState extends State<ReliefScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Craving Relief',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CuteThemeToggleWidget(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Motivational Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lowRiskColor.withValues(alpha: 0.15),
                    AppTheme.secondaryColor.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.lowRiskColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.lowRiskColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.lowRiskColor.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.spa_rounded, color: AppTheme.lowRiskColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feeling a craving?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cravings are like ocean waves — they crest, peak, and fade within 3 to 5 minutes. Ride the wave with these tools.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Relief Section
            Text(
              'Quick Relief Tools',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const _BreathingExerciseCard(),
            const SizedBox(height: 16),
            const _DelayTimerCard(),
            const SizedBox(height: 28),

            // Interactive Coping Strategies
            const _CopingStrategiesList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Box Breathing Exercise Card (4-4-6 Cycle)
// ---------------------------------------------------------------------------

class _BreathingExerciseCard extends StatefulWidget {
  const _BreathingExerciseCard();

  @override
  State<_BreathingExerciseCard> createState() => _BreathingExerciseCardState();
}

class _BreathingExerciseCardState extends State<_BreathingExerciseCard>
    with SingleTickerProviderStateMixin {
  bool _isActive = false;
  String _phase = 'Breathe In';
  int _cycleCount = 0;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _phaseTimer;

  static const _breatheInDuration = 4;
  static const _holdDuration = 4;
  static const _breatheOutDuration = 6;
  static const _totalCycles = 4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startExercise() {
    setState(() {
      _isActive = true;
      _cycleCount = 0;
    });
    _runCycle();
  }

  void _runCycle() {
    if (_cycleCount >= _totalCycles) {
      _finishExercise();
      return;
    }

    // Phase 1: Breathe In
    if (!mounted) return;
    setState(() => _phase = 'Breathe In');
    _controller.duration = const Duration(seconds: _breatheInDuration);
    _controller.forward(from: 0);

    _phaseTimer = Timer(const Duration(seconds: _breatheInDuration), () {
      if (!mounted) return;
      // Phase 2: Hold
      setState(() => _phase = 'Hold Breath');
      _phaseTimer = Timer(const Duration(seconds: _holdDuration), () {
        if (!mounted) return;
        // Phase 3: Breathe Out
        setState(() => _phase = 'Breathe Out Slowly');
        _controller.duration = const Duration(seconds: _breatheOutDuration);
        _controller.reverse();

        _phaseTimer = Timer(const Duration(seconds: _breatheOutDuration), () {
          if (!mounted) return;
          setState(() => _cycleCount++);
          _runCycle();
        });
      });
    });
  }

  void _finishExercise() {
    _phaseTimer?.cancel();
    _controller.stop();
    _controller.reset();
    if (mounted) {
      setState(() {
        _isActive = false;
        _phase = 'Breathe In';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Great job! You completed 4 box breathing cycles 🎉',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.lowRiskColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _stopExercise() {
    _phaseTimer?.cancel();
    _controller.stop();
    _controller.reset();
    if (mounted) {
      setState(() {
        _isActive = false;
        _phase = 'Breathe In';
        _cycleCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.air_rounded, color: AppTheme.secondaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '4-4-6 Box Breathing',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Calms the nervous system & dissolves urge',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Cycle ${_cycleCount + 1}/$_totalCycles',
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isActive) ...[
              // Animated breath visualization
              SizedBox(
                height: 180,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 160 * _scaleAnimation.value,
                            height: 160 * _scaleAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.secondaryColor.withValues(alpha: 0.10),
                            ),
                          ),
                          // Primary breathing orb
                          Container(
                            width: 125 * _scaleAnimation.value,
                            height: 125 * _scaleAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.secondaryColor.withValues(alpha: 0.35),
                                  AppTheme.secondaryColor.withValues(alpha: 0.12),
                                ],
                              ),
                              border: Border.all(
                                color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  _phase,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: AppTheme.secondaryColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Cycles Progress Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalCycles, (index) {
                  final isDone = index < _cycleCount;
                  final isCurrent = index == _cycleCount;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isCurrent ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent
                          ? AppTheme.secondaryColor
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _stopExercise,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('End Exercise'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Text(
                'Inhale for 4 seconds, gently hold for 4, and exhale for 6. Just 4 cycles slow your heart rate and trigger your parasympathetic relaxation response.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startExercise,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Begin Box Breathing',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Customizable Craving Delay Timer Card
// ---------------------------------------------------------------------------

class _DelayTimerCard extends StatefulWidget {
  const _DelayTimerCard();

  @override
  State<_DelayTimerCard> createState() => _DelayTimerCardState();
}

class _DelayTimerCardState extends State<_DelayTimerCard> {
  int _selectedMinutes = 5;
  int _secondsLeft = 300;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;

  final List<int> _presetOptions = [3, 5, 10];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectPreset(int minutes) {
    if (_isRunning) return;
    setState(() {
      _selectedMinutes = minutes;
      _secondsLeft = minutes * 60;
    });
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _secondsLeft = _selectedMinutes * 60;
    });
    _resumeTimer();
  }

  void _resumeTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _isRunning = false;
          _isPaused = false;
          _secondsLeft = _selectedMinutes * 60;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedMinutes}m Delay Finished! The urge has likely peaked and passed. You did it! 💪',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: AppTheme.lowRiskColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  void _unpauseTimer() {
    setState(() {
      _isPaused = false;
    });
    _resumeTimer();
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _secondsLeft = _selectedMinutes * 60;
    });
  }

  String get _formattedTime {
    final min = _secondsLeft ~/ 60;
    final sec = _secondsLeft % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalSec = _selectedMinutes * 60;
    final progress = totalSec > 0 ? 1.0 - (_secondsLeft / totalSec) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.moderateRiskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_outlined, color: AppTheme.moderateRiskColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Urge Delay Challenge',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Delay giving in by just a few minutes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isRunning) ...[
              // Active countdown display
              Text(
                _formattedTime,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.moderateRiskColor,
                      letterSpacing: 1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: AppTheme.moderateRiskColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isPaused
                    ? 'Timer paused — breathe deeply and take a sip of water.'
                    : 'Stay strong — distract yourself with one of the actions below!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isPaused ? _unpauseTimer : _pauseTimer,
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                      label: Text(_isPaused ? 'Resume' : 'Pause'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _stopTimer,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Tell yourself: "I won\'t give up completely, I\'ll just wait for this timer." Delaying disrupts the automatic habit trigger.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 16),
              // Preset Duration Pills
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _presetOptions.map((m) {
                    final isSelected = _selectedMinutes == m;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('$m Minutes'),
                        selected: isSelected,
                        onSelected: (_) => _selectPreset(m),
                        selectedColor: AppTheme.moderateRiskColor.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSelected ? AppTheme.moderateRiskColor : Colors.transparent,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.moderateRiskColor : cs.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startTimer,
                  icon: const Icon(Icons.hourglass_top_rounded),
                  label: Text(
                    'Start $_selectedMinutes-Minute Challenge',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.moderateRiskColor, width: 1.5),
                    foregroundColor: AppTheme.moderateRiskColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Interactive Coping Strategies Checklist
// ---------------------------------------------------------------------------

class _CopingStrategiesList extends StatefulWidget {
  const _CopingStrategiesList();

  @override
  State<_CopingStrategiesList> createState() => _CopingStrategiesListState();
}

class _CopingStrategiesListState extends State<_CopingStrategiesList> {
  final Set<String> _completedIds = {};

  static const _strategies = [
    _Strategy(
      id: 'water',
      icon: Icons.water_drop_outlined,
      title: 'Drink a Cold Glass of Water',
      description: 'Satisfies oral fixation, hydrates oral tissues, and clears nicotine faster.',
      color: Color(0xFF0EA5E9),
    ),
    _Strategy(
      id: 'walk',
      icon: Icons.directions_walk_rounded,
      title: 'Take a 5-Minute Walk',
      description: 'Light movement releases natural dopamine & endorphins to combat withdrawal.',
      color: AppTheme.lowRiskColor,
    ),
    _Strategy(
      id: 'chew',
      icon: Icons.emoji_food_beverage_outlined,
      title: 'Chew Gum or Crunchy Snack',
      description: 'Keeps teeth, jaw, and tongue busy to short-circuit the hand-to-mouth loop.',
      color: AppTheme.moderateRiskColor,
    ),
    _Strategy(
      id: 'call',
      icon: Icons.call_outlined,
      title: 'Call or Text a Friend',
      description: 'Social connection redirects emotional stress and boosts mood naturally.',
      color: Color(0xFF8B5CF6),
    ),
    _Strategy(
      id: 'splash',
      icon: Icons.wash_outlined,
      title: 'Splash Cold Water on Your Face',
      description: 'Triggers the mammalian dive reflex to drop elevated heart rate rapidly.',
      color: Color(0xFF06B6D4),
    ),
    _Strategy(
      id: 'meditate',
      icon: Icons.self_improvement_rounded,
      title: 'Body Scan Tension Release',
      description: 'Close your eyes. Unclench your jaw, drop your shoulders, and exhale fully.',
      color: Color(0xFFEC4899),
    ),
  ];

  void _toggleStrategy(String id, String title) {
    setState(() {
      if (_completedIds.contains(id)) {
        _completedIds.remove(id);
      } else {
        _completedIds.add(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nice! You tried "$title" ✨',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: AppTheme.lowRiskColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Coping Strategies',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _completedIds.isNotEmpty
                    ? AppTheme.lowRiskColor.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_completedIds.length}/${_strategies.length} Completed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _completedIds.isNotEmpty ? AppTheme.lowRiskColor : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tap any action you try during a craving to track your coping toolkit.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ..._strategies.map((strategy) {
          final isDone = _completedIds.contains(strategy.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              elevation: isDone ? 1 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDone ? AppTheme.lowRiskColor.withValues(alpha: 0.6) : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _toggleStrategy(strategy.id, strategy.title),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: strategy.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(strategy.icon, color: strategy.color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strategy.title,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    color: isDone ? cs.onSurfaceVariant : null,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strategy.description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? AppTheme.lowRiskColor : Colors.transparent,
                          border: Border.all(
                            color: isDone ? AppTheme.lowRiskColor : cs.outlineVariant,
                            width: 2,
                          ),
                        ),
                        child: isDone
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Strategy {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _Strategy({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
