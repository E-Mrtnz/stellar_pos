import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:stellar_pos/core/auth/auth_service.dart';
import 'package:stellar_pos/presentation/auth/auth_screen.dart';
import 'package:stellar_pos/presentation/dashboard/main_dashboard_layout.dart';

/// Prevents the POS from loading store access or cloud data until Firebase
/// Authentication has restored a real user session.
class AuthGate extends StatelessWidget {
  final AuthService authService;

  const AuthGate({super.key, AuthService? authService})
      : authService = authService ?? AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingView();
        }

        if (snapshot.hasError) {
          return _AuthErrorView(message: snapshot.error.toString());
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen();
        }

        return const MainDashboardLayout();
      },
    );
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _AuthErrorView extends StatelessWidget {
  final String message;

  const _AuthErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudo restaurar la sesión de Firebase.\n$message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
