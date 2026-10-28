import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ember/core/theme/app_theme.dart';

/// A card displaying rotating mindful quotes and reminders that smoothly fade
/// in and out on the Dashboard to encourage mindfulness and smoke-free habits.
class MindfulReminderQuotesCard extends StatefulWidget {
  const MindfulReminderQuotesCard({super.key});

  @override
  State<MindfulReminderQuotesCard> createState() => _MindfulReminderQuotesCardState();
}

class _MindfulReminderQuotesCardState extends State<MindfulReminderQuotesCard>
    with SingleTickerProviderStateMixin {
  static const List<String> _quotes = [
    'Every craving is a temporary wave — pause, take a deep breath, and let it pass.',
    'Notice the urge without judgment. You have the power to choose what comes next.',
    'Your lungs begin healing and oxygen levels normalize just hours after your last puff.',
    'Small conscious choices made today build lifelong freedom.',
    'Discipline is choosing between what you want right now and what you want most.',
    'A craving typically peaks and subsides within 3 to 5 minutes. Ride it out.',
    'Celebrate every single puff you consciously chose not to take today.',
    'One deep, mindful breath can interrupt an automatic habit loop.',
    'Progress is not about perfection, but persistence and awareness.',
    'Clearer lungs, a calmer mind, and true self-control: one breath at a time.',
    'You are in control of your body — not the nicotine, not the smoke.',
    'When a trigger appears, replace the habit: drink water, stretch, or step outside.',
  ];

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  Timer? _rotationTimer;
  int _currentIndex = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    // Initially start visible
    _animController.value = 1.0;

    _startAutoRotation();
  }

  void _startAutoRotation() {
    _rotationTimer?.cancel();
    // Keep quote on screen for 6.5s before transitioning to the next
    _rotationTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _advanceToNextQuote();
    });
  }

  Future<void> _advanceToNextQuote() async {
    if (!mounted || _isTransitioning) return;
    _isTransitioning = true;

    // Fade out current quote
    await _animController.reverse();

    if (!mounted) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % _quotes.length;
    });

    // Fade in new quote
    await _animController.forward();
    _isTransitioning = false;
  }

  void _handleManualTap() {
    // Reset timer on manual interaction so it doesn't immediately skip again
    _startAutoRotation();
    _advanceToNextQuote();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.08)
        : AppTheme.primaryColor.withValues(alpha: 0.05);

    final borderColor = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.22)
        : AppTheme.primaryColor.withValues(alpha: 0.18);

    return InkWell(
      onTap: _handleManualTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.05 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Badge + Tap hint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.primaryColor,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'MINDFUL REMINDER',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_currentIndex + 1}/${_quotes.length} • Tap for next',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Animated Quote Body
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“',
                      style: TextStyle(
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                        fontSize: 22,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _quotes[_currentIndex],
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '”',
                      style: TextStyle(
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                        fontSize: 22,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
