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
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return null;

      final response = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      Logger.error('Failed to get user profile', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> upsertUserProfile(UserProfile profile) async {
    try {
      await SupabaseConfig.client.from('users').upsert(profile.toJson());
      Logger.info('User profile updated');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to upsert user profile', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<Session?> createSession(Session session) async {
    try {
      final response = await SupabaseConfig.client
          .from('sessions')
          .insert(session.toJson())
          .select()
          .single();

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
          .eq('id', session.id);

      Logger.info('Session updated: ${session.id}');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to update session', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> insertPuffEvent(PuffEvent event) async {
    try {
      await SupabaseConfig.client.from('puff_events').insert(event.toJson());
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
          .order('detected_at', ascending: false);

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
          .order('started_at', ascending: false);

      return (response as List).map((json) => Session.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get sessions', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<bool> insertAddictionScore(AddictionScore score) async {
    try {
      await SupabaseConfig.client.from('addiction_scores').insert(score.toJson());
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
          .single();

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
          .lt('detected_at', endOfDay.toIso8601String());

      return (response as List).length;
    } catch (e, stackTrace) {
      Logger.error('Failed to get today puff count', error: e, stackTrace: stackTrace);
      return 0;
    }
  }
}
