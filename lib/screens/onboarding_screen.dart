import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/services/auth_service.dart';
import 'package:ember/models/user_profile.dart';
import 'package:ember/models/quit_plan.dart';
import 'package:ember/screens/home_screen.dart';
import 'package:ember/widgets/theme_toggle_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baselinePuffsController = TextEditingController();
  final _yearsSmokedController = TextEditingController();
  final _dailyGoalController = TextEditingController();
  final _supabaseService = SupabaseService();
  final _authService = AuthService();

  QuitStrategyType _selectedStrategy = QuitStrategyType.gradualReduction;
  bool _isLoading = false;
  int _currentStep = 0;

  @override
  void dispose() {
    _baselinePuffsController.dispose();
    _yearsSmokedController.dispose();
    _dailyGoalController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _authService.userId;
      if (userId == null) throw Exception('User not authenticated');

      final baseline = int.parse(_baselinePuffsController.text);
      final profile = UserProfile(
        id: userId,
        createdAt: DateTime.now(),
        baselinePuffsPerDay: baseline,
        yearsSmokedOrVaped: int.parse(_yearsSmokedController.text),
        dailyPuffGoal: _selectedStrategy == QuitStrategyType.coldTurkey
            ? 0
            : (_dailyGoalController.text.isNotEmpty
                ? int.parse(_dailyGoalController.text)
                : baseline),
        quitStrategy: _selectedStrategy.code,
        planStartDate: DateTime.now(),
        weeklyReductionRate: 10.0,
      );

      final success = await _supabaseService.upsertUserProfile(profile);

      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        throw Exception('Failed to save profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.highRiskColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16, top: 8),
            child: CuteThemeToggleWidget(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 3,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Welcome to EMBER',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),

                Text(
                  'Let\'s set up your profile to personalize your experience',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
                const SizedBox(height: 28),

                Expanded(
                  child: SingleChildScrollView(
                    child: _buildStepContent(),
                  ),
                ),

                Row(
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: () {
                          setState(() => _currentStep--);
                        },
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStep == 2 ? 'Get Started' : 'Next',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smoking_rooms, size: 48, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 24),

        Text(
          'Current Usage Baseline',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _baselinePuffsController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Puffs / Cigarettes per day',
            prefixIcon: Icon(Icons.local_fire_department),
            helperText: 'Approximate daily average over the last week',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your current usage';
            }
            final number = int.tryParse(value);
            if (number == null || number < 0) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.calendar_today, size: 48, color: AppTheme.secondaryColor),
        ),
        const SizedBox(height: 24),

        Text(
          'Your History',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _yearsSmokedController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Years smoking / vaping',
            prefixIcon: Icon(Icons.history),
            helperText: 'How long have you been smoking or vaping?',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter years smoked/vaped';
            }
            final number = int.tryParse(value);
            if (number == null || number < 0 || number > 100) {
              return 'Please enter a valid number (0-100)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.lowRiskColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flag_rounded, size: 48, color: AppTheme.lowRiskColor),
        ),
        const SizedBox(height: 24),

        Text(
          'Choose Your Quit Strategy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select how EMBER adapts your daily limits over time',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),

        _buildStrategyOption(
          type: QuitStrategyType.gradualReduction,
          title: 'Gradual 10% Weekly Step-Down',
          subtitle: 'Automatically lowers daily ceiling by 10% every Monday. Most sustainable method to avoid nicotine withdrawal shocks.',
          badge: 'Recommended',
          badgeColor: AppTheme.lowRiskColor,
          icon: Icons.trending_down_rounded,
        ),
        const SizedBox(height: 10),

        _buildStrategyOption(
          type: QuitStrategyType.coldTurkey,
          title: 'Cold Turkey (Immediate Stop)',
          subtitle: 'Aim for 0 puffs immediately. Unlocks high-intensity craving SOS and mindful breathing tools.',
          badge: 'Intensive',
          badgeColor: AppTheme.highRiskColor,
          icon: Icons.ac_unit_rounded,
        ),
        const SizedBox(height: 10),

        _buildStrategyOption(
          type: QuitStrategyType.customGoal,
          title: 'Custom Fixed Goal',
          subtitle: 'Set a manual fixed ceiling of your choice.',
          badge: 'Manual',
          badgeColor: Colors.grey,
          icon: Icons.tune_rounded,
        ),

        if (_selectedStrategy == QuitStrategyType.customGoal) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _dailyGoalController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Custom daily max puffs',
              prefixIcon: Icon(Icons.track_changes),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (_selectedStrategy == QuitStrategyType.customGoal && (value == null || value.isEmpty)) {
                return 'Please enter your custom goal';
              }
              return null;
            },
          ),
        ],

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.secondaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip: You can modify your strategy and target dates anytime from your Profile or Dashboard.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyOption({
    required QuitStrategyType type,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
  }) {
    final isSelected = _selectedStrategy == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedStrategy = type),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey[600], size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? AppTheme.primaryColor : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNext() {
    if (_currentStep < 2) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep++);
      }
    } else {
      _handleSubmit();
    }
  }
}
