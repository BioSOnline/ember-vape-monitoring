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
            // Header
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.lowRiskColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.lowRiskColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.spa, color: AppTheme.lowRiskColor, size: 28),
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
                          'Try these science-backed techniques to ride the wave. Most cravings pass in 3-5 minutes.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Relief Tools',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const _BreathingExerciseCard(),
            const SizedBox(height: 12),
            const _DelayTimerCard(),
            const SizedBox(height: 24),

            // Coping Strategies
            Text(
              'Coping Strategies',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const _CopingStrategiesList(),
            const SizedBox(height: 24),

            // Removed extra fluff sections
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Breathing Exercise ─────────────────────────────────────────────────────

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
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _phaseTimer?.cancel();
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
      _stopExercise();
      return;
    }

    // Breathe In
    setState(() => _phase = 'Breathe In');
    _controller.duration = Duration(seconds: _breatheInDuration);
    _controller.forward(from: 0);

    _phaseTimer = Timer(Duration(seconds: _breatheInDuration), () {
      if (!mounted) return;
      // Hold
      setState(() => _phase = 'Hold');
      _phaseTimer = Timer(Duration(seconds: _holdDuration), () {
        if (!mounted) return;
        // Breathe Out
        setState(() => _phase = 'Breathe Out');
        _controller.duration = Duration(seconds: _breatheOutDuration);
        _controller.reverse();

        _phaseTimer = Timer(Duration(seconds: _breatheOutDuration), () {
          if (!mounted) return;
          setState(() => _cycleCount++);
          _runCycle();
        });
      });
    });
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
      if (_cycleCount >= _totalCycles) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Great job! You completed the breathing exercise 🎉',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            backgroundColor: AppTheme.lowRiskColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.air, color: AppTheme.secondaryColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  '4-4-6 Box Breathing',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (_isActive)
                  Text(
                    '${_cycleCount + 1}/$_totalCycles',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Breathe in for 4s, hold for 4s, breathe out for 6s. This activates your parasympathetic nervous system and reduces craving intensity.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            if (_isActive) ...[
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.secondaryColor.withValues(alpha: 0.3),
                            AppTheme.secondaryColor.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.6),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _phase,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _stopExercise,
                child: Text(
                  'Stop',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startExercise,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    'Start Breathing Exercise',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 5-Minute Delay Timer ───────────────────────────────────────────────────

class _DelayTimerCard extends StatefulWidget {
  const _DelayTimerCard();

  @override
  State<_DelayTimerCard> createState() => _DelayTimerCardState();
}

class _DelayTimerCardState extends State<_DelayTimerCard> {
  bool _isRunning = false;
  int _secondsLeft = 300; // 5 minutes
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _secondsLeft = 300;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _timer?.cancel();
          _isRunning = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '5 minutes done! The craving has likely passed. You did it! 💪',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
              backgroundColor: AppTheme.lowRiskColor,
            ),
          );
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsLeft = 300;
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
    final progress = 1.0 - (_secondsLeft / 300.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: AppTheme.moderateRiskColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  '5-Minute Delay Rule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'When a craving hits, tell yourself "I\'ll wait just 5 minutes." Most cravings peak and fade within this window.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            if (_isRunning) ...[
              Text(
                _formattedTime,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.moderateRiskColor,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: AppTheme.moderateRiskColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay strong — distract yourself with an activity below!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _stopTimer,
                child: Text(
                  'Cancel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startTimer,
                  icon: const Icon(Icons.hourglass_top_rounded),
                  label: Text(
                    'Start 5-Minute Timer',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppTheme.moderateRiskColor),
                    foregroundColor: AppTheme.moderateRiskColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Coping Strategies ──────────────────────────────────────────────────────

class _CopingStrategiesList extends StatelessWidget {
  const _CopingStrategiesList();

  static const _strategies = [
    _Strategy(
      icon: Icons.water_drop_outlined,
      title: 'Drink a Glass of Water',
      description: 'Hydration reduces oral fixation cravings and flushes nicotine faster.',
      color: Color(0xFF0EA5E9),
    ),
    _Strategy(
      icon: Icons.directions_walk_rounded,
      title: 'Take a 5-Minute Walk',
      description: 'Light movement releases endorphins that counter withdrawal symptoms.',
      color: AppTheme.lowRiskColor,
    ),
    _Strategy(
      icon: Icons.ice_skating,
      title: 'Chew Gum or Snack on Carrots',
      description: 'Keeps your mouth busy and satisfies the hand-to-mouth habit loop.',
      color: AppTheme.moderateRiskColor,
    ),
    _Strategy(
      icon: Icons.call,
      title: 'Call or Text a Friend',
      description: 'Social connection is a powerful distraction and boosts mood naturally.',
      color: Color(0xFF8B5CF6),
    ),
    _Strategy(
      icon: Icons.wash,
      title: 'Splash Cold Water on Your Face',
      description: 'Activates the dive reflex, instantly slowing heart rate and calming anxiety.',
      color: Color(0xFF06B6D4),
    ),
    _Strategy(
      icon: Icons.self_improvement,
      title: 'Body Scan Meditation',
      description: 'Close your eyes. Scan from head to toe. Notice tension and consciously release it.',
      color: Color(0xFFEC4899),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: _strategies.map((strategy) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: strategy.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(strategy.icon, color: strategy.color, size: 22),
              ),
              title: Text(
                strategy.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              subtitle: Text(
                strategy.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Strategy {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _Strategy({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

