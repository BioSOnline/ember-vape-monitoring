import 'package:flutter/material.dart';
import 'package:ember/services/auth_service.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:ember/screens/login_screen.dart';
import 'package:ember/screens/onboarding_screen.dart';
import 'package:ember/screens/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;
        final isAuthenticated = session?.user != null;

        if (!isAuthenticated) {
          return const LoginScreen();
        }

        return FutureBuilder(
          future: SupabaseService().getUserProfile(),
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
