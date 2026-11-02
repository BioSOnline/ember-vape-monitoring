import 'package:flutter/material.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/models/user_profile.dart';
import 'package:ember/models/quit_plan.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/services/auth_service.dart';
import 'package:ember/screens/dashboard_screen.dart';
import 'package:ember/screens/detection_screen.dart';
import 'package:ember/screens/profile_screen.dart';
import 'package:ember/screens/video_upload_screen.dart';
import 'package:ember/screens/relief_screen.dart';
import 'package:ember/widgets/manual_entry_dialog.dart';
import 'package:ember/widgets/theme_toggle_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabaseService = SupabaseService();
  final _authService = AuthService();
  int _todayPuffCount = 0;
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
  }

  Future<void> _loadTodayStats() async {
    setState(() => _loading = true);
    final count = await _supabaseService.getTodayPuffCount();
    final profile = await _supabaseService.getUserProfile();
    setState(() {
      _todayPuffCount = count;
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _openManualEntry() async {
    final updated = await ManualEntryDialog.show(context);
    if (updated == true) {
      _loadTodayStats();
    }
  }

  Future<void> _openDetection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DetectionScreen()),
    );
    _loadTodayStats();
  }

  Future<void> _openVideoUpload() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VideoUploadScreen()),
    );
    _loadTodayStats();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    ).then((_) => _loadTodayStats());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: 18,
                        ),
                  ),
                  Text(
                    'Behavioral Companion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Cute Animated Day/Night Toggle Widget
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: CuteThemeToggleWidget(),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 24),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: 'User Profile',
            onPressed: _openProfile,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onSelected: (value) async {
              if (value == 'profile') {
                _openProfile();
              } else if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await _authService.signOut();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text('My Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodayStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Activity Card with Ember Gradient Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: isDark
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                            Theme.of(context).colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.12),
                            AppTheme.primaryGradientEnd.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.primaryColor.withValues(alpha: 0.3)
                        : AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TODAY\'S USAGE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Live Tracking',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _loading
                        ? const CircularProgressIndicator()
                        : Column(
                            children: [
                              Text(
                                '$_todayPuffCount',
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 56,
                                      height: 1,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Puffs Recorded Today',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: isDark ? Colors.white70 : Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (_profile != null) ...[
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final plan = _profile!.quitPlan;
                                    final ceiling = _profile!.effectiveDailyGoal;
                                    final isColdTurkey = plan.strategyType == QuitStrategyType.coldTurkey;
                                    final isMonday = plan.isMondayAdjustmentDay();

                                    return Column(
                                      children: [
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (isColdTurkey && _todayPuffCount > 0
                                                        ? AppTheme.highRiskColor
                                                        : AppTheme.primaryColor)
                                                    .withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isColdTurkey
                                                    ? 'Target: 0 Puffs (Cold Turkey)'
                                                    : 'Ceiling: $ceiling puffs · ${plan.strategyType.title}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isColdTurkey && _todayPuffCount > 0
                                                      ? AppTheme.highRiskColor
                                                      : AppTheme.primaryColor,
                                                ),
                                              ),
                                            ),
                                            if (isMonday && plan.strategyType == QuitStrategyType.gradualReduction) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.lowRiskColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.bolt, size: 12, color: AppTheme.lowRiskColor),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      'Monday Step-Down',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.lowRiskColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (ceiling > 0 && !isColdTurkey) ...[
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: SizedBox(
                                              width: 180,
                                              height: 6,
                                              child: LinearProgressIndicator(
                                                value: (_todayPuffCount / ceiling).clamp(0.0, 1.0),
                                                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                                color: _todayPuffCount <= ceiling
                                                    ? AppTheme.lowRiskColor
                                                    : AppTheme.highRiskColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Privacy Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppConstants.privacyDisclaimer,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 14),

              // Lively Action Cards Grid / List
              _LivelyActionTile(
                icon: Icons.camera_alt,
                gradient: const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8F00)]),
                title: 'Start Detection',
                subtitle: 'Live camera puff detection & real-time session',
                onTap: _openDetection,
              ),
              const SizedBox(height: 12),

              _LivelyActionTile(
                icon: Icons.video_library,
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
                title: 'Upload Video',
                subtitle: 'Analyze recorded video file for puff events',
                onTap: _openVideoUpload,
              ),
              const SizedBox(height: 12),

              _LivelyActionTile(
                icon: Icons.insights_outlined,
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
                title: 'View Dashboard',
                subtitle: 'Analytics, 7-day trends, and risk assessment',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),

              _LivelyActionTile(
                icon: Icons.edit_note_outlined,
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
                title: 'Manual Entry',
                subtitle: 'Log a puff manually with custom time',
                onTap: _openManualEntry,
              ),
              const SizedBox(height: 12),

              _LivelyActionTile(
                icon: Icons.spa_outlined,
                gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF472B6)]),
                title: 'Craving Relief',
                subtitle: 'Breathing exercises, timers, and coping tools',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReliefScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivelyActionTile extends StatelessWidget {
  final IconData icon;
  final LinearGradient gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LivelyActionTile({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
