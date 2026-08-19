import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? get currentUser => SupabaseConfig.currentUser;
  bool get isAuthenticated => SupabaseConfig.isAuthenticated;
  String? get userId => SupabaseConfig.currentUserId;

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        Logger.info('User signed up: ${response.user!.id}');
        return response;
      }

      Logger.warning('Signup returned no user');
      return null;
    } catch (e, stackTrace) {
      Logger.error('Failed to sign up', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        Logger.info('User signed in: ${response.user!.id}');
        return response;
      }

      Logger.warning('Sign in returned no user');
      return null;
    } catch (e, stackTrace) {
      Logger.error('Failed to sign in', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseConfig.auth.signOut();
    } catch (e, stackTrace) {
      Logger.error('Failed to sign out', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Stream<AuthState> get authStateChanges => SupabaseConfig.auth.onAuthStateChange;

  Future<void> resetPassword(String email) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
    } catch (e, stackTrace) {
      Logger.error('Failed to send password reset email', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
