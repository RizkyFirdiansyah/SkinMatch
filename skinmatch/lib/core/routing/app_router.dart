import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/profile/presentation/skin_profile_screen.dart';
import '../../features/analysis/presentation/result_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/scanner/presentation/camera_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/history/presentation/history_screen.dart';

// ── Route Paths ──────────────────────────────────────────────────────────────
abstract class AppRoutes {
  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String forgotPassword = '/forgot-password';
  static const String profile = '/profile';
  static const String profileSetup = '/profile-setup';
  static const String shell = '/';
  static const String home = '/home';
  static const String scan = '/scan';
  static const String analysis = '/analysis/:id';
  static const String history = '/history';

  static String analysisPath(String id) => '/analysis/$id';
}

// ── Router Provider ──────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.welcome,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Auth — standalone (Masuk / Daftar Akun Baru)
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),

      // Lupa Kata Sandi — standalone
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Profile setup — standalone
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const SkinProfileScreen(isSetup: true),
      ),

      // Main Shell — with Bottom Navigation Bar
      ShellRoute(
        // Jika file MainShell belum ada/error, sementara ubah ke:
        // builder: (context, state, child) => Scaffold(body: child),
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) =>
                _fadeTransition(state, const SkinProfileScreen()),
          ),
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                _fadeTransition(state, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.scan,
            pageBuilder: (context, state) =>
                _fadeTransition(state, const CameraScreen()),
          ),
          GoRoute(
            path: AppRoutes.history,
            pageBuilder: (context, state) =>
                _fadeTransition(state, const HistoryScreen()),
          ),
        ],
      ),

      // Analysis Result — full screen (no nav)
      GoRoute(
        path: AppRoutes.analysis,
        pageBuilder: (context, state) {
          final scanId = state.pathParameters['id'] ?? '';
          return _fadeTransition(state, ResultScreen(scanId: scanId));
        },
      ),
    ],

    // Redirect root to home
    redirect: (context, state) async {
      final path = state.uri.path;
      if (path == AppRoutes.shell) return AppRoutes.home;

      final api = ref.read(apiClientProvider);
      final hasSession = await api.hasSession();
      final isPublicRoute =
          path == AppRoutes.welcome ||
          path == AppRoutes.auth ||
          path == AppRoutes.forgotPassword;

      if (!hasSession) return isPublicRoute ? null : AppRoutes.auth;
      if (path == AppRoutes.auth || path == AppRoutes.welcome) {
        try {
          final profile = await api.getProfile();
          return profile['profile_completed'] == true
              ? AppRoutes.home
              : AppRoutes.profileSetup;
        } on ApiException catch (error) {
          if (error.statusCode == 401) {
            await api.logout();
          }
          return null;
        }
      }
      return null;
    },

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route tidak ditemukan: ${state.uri}')),
    ),
  );
});

// ── Transition Helper ─────────────────────────────────────────────────────────
CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
