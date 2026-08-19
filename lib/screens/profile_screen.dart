import 'package:flutter/material.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/models/user_profile.dart';
import 'package:ember/services/auth_service.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/widgets/theme_toggle_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _supabaseService = SupabaseService();

  final _baselinePuffsController = TextEditingController();
  final _yearsSmokedController = TextEditingController();
  final _dailyGoalController = TextEditingController();

  String? _productType;
  String? _preferredStrategy;
  String? _primaryTrigger;

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  final List<String> _productOptions = [
    'Vape / Pod System',
    'E-Cigarette',
    'Combustible Cigarette',
    'Nicotine Pouch / Oral',
  ];

  final List<String> _strategyOptions = [
    'Deep Breathing Exercises',
    'Drink Glass of Water',
    '5-Minute Delay Rule',
    'Physical Movement / Walk',
    'Distraction / Gaming',
  ];

  final List<String> _triggerOptions = [
    'Work / Daily Stress',
    'After Meals',
    'Morning Routine',
    'Socializing / Drinking',
    'Boredom / Inactivity',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _baselinePuffsController.dispose();
    _yearsSmokedController.dispose();
    _dailyGoalController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final profile = await _supabaseService.getUserProfile();

    if (profile != null) {
      _profile = profile;
      _baselinePuffsController.text = profile.baselinePuffsPerDay?.toString() ?? '';
      _yearsSmokedController.text = profile.yearsSmokedOrVaped?.toString() ?? '';
      _dailyGoalController.text = profile.dailyPuffGoal?.toString() ?? '';
      _productType = profile.productType;
      _preferredStrategy = profile.preferredStrategy;
      _primaryTrigger = profile.primaryTrigger;
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _authService.userId;
    if (userId == null) return;

    setState(() => _saving = true);

    try {
      final updatedProfile = UserProfile(
        id: userId,
        createdAt: _profile?.createdAt ?? DateTime.now(),
        baselinePuffsPerDay: int.tryParse(_baselinePuffsController.text),
        yearsSmokedOrVaped: int.tryParse(_yearsSmokedController.text),
        dailyPuffGoal: int.tryParse(_dailyGoalController.text),
        productType: _productType,
        preferredStrategy: _preferredStrategy,
        primaryTrigger: _primaryTrigger,
      );

      final success = await _supabaseService.upsertUserProfile(updatedProfile);

      if (mounted) {
        if (success) {
          _profile = updatedProfile;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: AppTheme.lowRiskColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile.'),
              backgroundColor: AppTheme.highRiskColor,
            ),
          );
        }
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final email = user?.email ?? 'User';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final completion = _profile?.profileCompletionPercentage ?? 0.5;
    final completionPct = (completion * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CuteThemeToggleWidget(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              email,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Account ID: ${user?.id.substring(0, 8) ?? 'N/A'}...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Profile Completeness',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  '$completionPct%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: completionPct == 100
                                        ? AppTheme.lowRiskColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: completion,
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                color: completionPct == 100
                                    ? AppTheme.lowRiskColor
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            if (completionPct < 100) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Fill in missing details below to unlock personalized recommendations.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Usage & Goal Baseline',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _baselinePuffsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Baseline Puffs Per Day',
                        prefixIcon: Icon(Icons.local_fire_department),
                        border: OutlineInputBorder(),
                        helperText: 'Your estimated daily usage before using EMBER',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Please enter baseline usage';
                        if (int.tryParse(val) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _yearsSmokedController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years Vaping / Smoking',
                        prefixIcon: Icon(Icons.history),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Please enter years';
                        if (int.tryParse(val) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _dailyGoalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Daily Puff Reduction Goal',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                        helperText: 'Target daily max puffs (optional)',
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Additional Profile Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _productOptions.contains(_productType) ? _productType : null,
                      decoration: const InputDecoration(
                        labelText: 'Product / Device Type',
                        prefixIcon: Icon(Icons.devices),
                        border: OutlineInputBorder(),
                      ),
                      items: _productOptions
                          .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                          .toList(),
                      onChanged: (val) => setState(() => _productType = val),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _strategyOptions.contains(_preferredStrategy) ? _preferredStrategy : null,
                      decoration: const InputDecoration(
                        labelText: 'Preferred Coping Strategy',
                        prefixIcon: Icon(Icons.health_and_safety),
                        border: OutlineInputBorder(),
                      ),
                      items: _strategyOptions
                          .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                          .toList(),
                      onChanged: (val) => setState(() => _preferredStrategy = val),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _triggerOptions.contains(_primaryTrigger) ? _primaryTrigger : null,
                      decoration: const InputDecoration(
                        labelText: 'Primary Craving Trigger',
                        prefixIcon: Icon(Icons.psychology),
                        border: OutlineInputBorder(),
                      ),
                      items: _triggerOptions
                          .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                          .toList(),
                      onChanged: (val) => setState(() => _primaryTrigger = val),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Save Profile Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await _authService.signOut();
                        navigator.pop();
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Logout Account', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
