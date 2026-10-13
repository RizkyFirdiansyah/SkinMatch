import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/profile/presentation/skin_profile_screen.dart';
import '../../features/analysis/presentation/result_screen.dart';
import '../../shared/widgets/main_shell.dart';

// ── Route Paths ──────────────────────────────────────────────────────────────
abstract class AppRoutes {
  static const String auth = '/auth';
  static const String forgotPassword = '/forgot-password';
  static const String profile = '/profile';
  static const String shell = '/';
  static const String scan = '/scan';
  static const String analysis = '/analysis/:id';
  static const String history = '/history';

  static String analysisPath(String id) => '/analysis/$id';
}

// ── Router Provider ──────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.auth,
    debugLogDiagnostics: true,
    routes: [
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

      // Profile Setup — standalone
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const SkinProfileScreen(),
      ),

      // Main Shell — with Bottom Navigation Bar
      ShellRoute(
        // Jika file MainShell belum ada/error, sementara ubah ke:
        // builder: (context, state, child) => Scaffold(body: child),
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.scan,
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Halaman Scan (Camera)')),
            ),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Halaman History'))),
          ),
        ],
      ),

      // Analysis Result — full screen (no nav)
      GoRoute(
        path: AppRoutes.analysis,
        builder: (context, state) {
          final scanId = state.pathParameters['id'] ?? '';
          return ResultScreen(scanId: scanId);
        },
      ),
    ],

    // Redirect root to scan
    redirect: (context, state) {
      if (state.uri.path == '/') return AppRoutes.scan;
      return null;
    },

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route tidak ditemukan: ${state.uri}')),
    ),
  );
});
