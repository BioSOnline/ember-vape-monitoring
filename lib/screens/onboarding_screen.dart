import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/services/auth_service.dart';
import 'package:ember/models/user_profile.dart';
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

      final profile = UserProfile(
        id: userId,
        createdAt: DateTime.now(),
        baselinePuffsPerDay: int.parse(_baselinePuffsController.text),
        yearsSmokedOrVaped: int.parse(_yearsSmokedController.text),
        dailyPuffGoal: _dailyGoalController.text.isEmpty
            ? null
            : int.parse(_dailyGoalController.text),
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
          'Set Your Daily Goal',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _dailyGoalController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Daily puff goal (optional)',
            prefixIcon: Icon(Icons.track_changes),
            helperText: 'Target number of puffs per day. Leave empty to skip.',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return null;
            final number = int.tryParse(value);
            if (number == null || number < 0) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.secondaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: Start with a modest reduction goal. Small, consistent changes build sustainable long-term habits!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
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
