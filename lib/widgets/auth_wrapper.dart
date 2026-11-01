import 'package:flutter/material.dart';
import 'package:ember/models/user_profile.dart';
import 'package:ember/services/auth_service.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/screens/login_screen.dart';
import 'package:ember/screens/onboarding_screen.dart';
import 'package:ember/screens/home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  final _supabaseService = SupabaseService();
  Future<UserProfile?>? _profileFuture;
  String? _lastCheckedUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;
        final user = session?.user;

        if (user == null) {
          _lastCheckedUserId = null;
          _profileFuture = null;
          return const LoginScreen();
        }

        if (_lastCheckedUserId != user.id) {
          _lastCheckedUserId = user.id;
          _profileFuture = _supabaseService.getUserProfile();
        }

        return FutureBuilder<UserProfile?>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null || !profile.hasCompletedOnboarding) {
              return const OnboardingScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
