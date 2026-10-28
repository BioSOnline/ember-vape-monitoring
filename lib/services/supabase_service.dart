import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/models/session.dart';
import 'package:ember/models/addiction_score.dart';
import 'package:ember/models/user_profile.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  Future<UserProfile?> getUserProfile() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return null;

    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 4));

      var profile = UserProfile.fromJson(response);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed_$userId', profile.hasCompletedOnboarding);

      // Merge locally cached quit plan if remote didn't have it
      if (profile.quitStrategy == null) {
        final localStrategy = prefs.getString('quit_strategy_$userId');
        final localStart = prefs.getString('plan_start_date_$userId');
        final localTarget = prefs.getString('target_quit_date_$userId');
        final localRate = prefs.getDouble('weekly_reduction_rate_$userId');

        if (localStrategy != null && localStrategy.isNotEmpty) {
          profile = profile.copyWith(
            quitStrategy: localStrategy,
            planStartDate: localStart != null ? DateTime.tryParse(localStart) : null,
            targetQuitDate: localTarget != null ? DateTime.tryParse(localTarget) : null,
            weeklyReductionRate: localRate,
          );
        }
      }
      return profile;
    } catch (e, stackTrace) {
      Logger.warning('Network fetch for user profile failed or timed out: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedCompleted = prefs.getBool('onboarding_completed_$userId') ?? false;
        if (cachedCompleted) {
          Logger.info('Using locally cached onboarding status for user: $userId');
          final localStrategy = prefs.getString('quit_strategy_$userId');
          final localStart = prefs.getString('plan_start_date_$userId');
          final localTarget = prefs.getString('target_quit_date_$userId');
          final localRate = prefs.getDouble('weekly_reduction_rate_$userId');
          final baseline = prefs.getInt('baseline_puffs_$userId') ?? 20;
          final goal = prefs.getInt('daily_goal_$userId');

          return UserProfile(
            id: userId,
            createdAt: DateTime.now(),
            baselinePuffsPerDay: baseline,
            yearsSmokedOrVaped: 1,
            dailyPuffGoal: goal,
            quitStrategy: localStrategy ?? 'gradual_reduction',
            planStartDate: localStart != null ? DateTime.tryParse(localStart) : DateTime.now(),
            targetQuitDate: localTarget != null ? DateTime.tryParse(localTarget) : null,
            weeklyReductionRate: localRate ?? 10.0,
          );
        }
      } catch (_) {}
      Logger.error('Failed to get user profile', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> upsertUserProfile(UserProfile profile) async {
    // Cache locally first for offline resilience
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed_${profile.id}', profile.hasCompletedOnboarding);
      if (profile.baselinePuffsPerDay != null) {
        await prefs.setInt('baseline_puffs_${profile.id}', profile.baselinePuffsPerDay!);
      }
      if (profile.dailyPuffGoal != null) {
        await prefs.setInt('daily_goal_${profile.id}', profile.dailyPuffGoal!);
      }
      if (profile.quitStrategy != null) {
        await prefs.setString('quit_strategy_${profile.id}', profile.quitStrategy!);
      }
      if (profile.planStartDate != null) {
        await prefs.setString('plan_start_date_${profile.id}', profile.planStartDate!.toIso8601String());
      }
      if (profile.targetQuitDate != null) {
        await prefs.setString('target_quit_date_${profile.id}', profile.targetQuitDate!.toIso8601String());
      }
      if (profile.weeklyReductionRate != null) {
        await prefs.setDouble('weekly_reduction_rate_${profile.id}', profile.weeklyReductionRate!);
      }
    } catch (_) {}

    try {
      await SupabaseConfig.client
          .from('users')
          .upsert(profile.toJson())
          .timeout(const Duration(seconds: 4));

      Logger.info('User profile updated');
      return true;
    } catch (e) {
      Logger.warning('Primary profile upsert failed, attempting fallback to base schema: $e');
      try {
        await SupabaseConfig.client
            .from('users')
            .upsert(profile.toBaseJson())
            .timeout(const Duration(seconds: 4));
        Logger.info('User profile updated via base schema fallback');
        return true;
      } catch (fallbackError, stackTrace) {
        Logger.error('Failed to upsert user profile', error: fallbackError, stackTrace: stackTrace);
        return false;
      }
    }
  }

  Future<Session?> createSession(Session session) async {
    try {
      final response = await SupabaseConfig.client
          .from('sessions')
          .insert(session.toJson())
          .select()
          .single()
          .timeout(const Duration(seconds: 4));

      Logger.info('Session created: ${session.id}');
      return Session.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to create session', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> updateSession(Session session) async {
    try {
      await SupabaseConfig.client
          .from('sessions')
          .update(session.toJson())
          .eq('id', session.id)
          .timeout(const Duration(seconds: 4));

      Logger.info('Session updated: ${session.id}');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to update session', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> insertPuffEvent(PuffEvent event) async {
    try {
      await SupabaseConfig.client
          .from('puff_events')
          .insert(event.toJson())
          .timeout(const Duration(seconds: 4));
      Logger.info('Puff event inserted: ${event.id}');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to insert puff event', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<List<PuffEvent>> getPuffEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return [];

      final response = await SupabaseConfig.client
          .from('puff_events')
          .select()
          .eq('user_id', userId)
          .gte('detected_at', startDate.toIso8601String())
          .lte('detected_at', endDate.toIso8601String())
          .order('detected_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      return (response as List).map((json) => PuffEvent.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get puff events', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<List<Session>> getSessions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return [];

      final response = await SupabaseConfig.client
          .from('sessions')
          .select()
          .eq('user_id', userId)
          .gte('started_at', startDate.toIso8601String())
          .lte('started_at', endDate.toIso8601String())
          .order('started_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      return (response as List).map((json) => Session.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get sessions', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<bool> insertAddictionScore(AddictionScore score) async {
    try {
      await SupabaseConfig.client
          .from('addiction_scores')
          .insert(score.toJson())
          .timeout(const Duration(seconds: 4));
      Logger.info('Addiction score inserted: ${score.level}');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to insert addiction score', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<AddictionScore?> getLatestAddictionScore() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return null;

      final response = await SupabaseConfig.client
          .from('addiction_scores')
          .select()
          .eq('user_id', userId)
          .order('scored_at', ascending: false)
          .limit(1)
          .single()
          .timeout(const Duration(seconds: 4));

      return AddictionScore.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get latest addiction score', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<int> getTodayPuffCount() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return 0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await SupabaseConfig.client
          .from('puff_events')
          .select('id')
          .eq('user_id', userId)
          .gte('detected_at', startOfDay.toIso8601String())
          .lt('detected_at', endOfDay.toIso8601String())
          .timeout(const Duration(seconds: 3));

      return (response as List).length;
    } catch (e) {
      Logger.warning('Failed to get today puff count: $e');
      return 0;
    }
  }
}
