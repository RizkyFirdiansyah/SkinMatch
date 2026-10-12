import 'package:flutter/material.dart';

import '../theme/auth_style.dart';

/// Latar layar dengan bercak hijau lembut.
/// Juga memasang tema khusus auth untuk semua yang ada di dalamnya.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AuthTheme.light,
      child: Scaffold(
        backgroundColor: AuthColors.background,
        body: Stack(
          children: [
            Positioned(
              top: -90,
              left: -90,
              child: _blob(280, AuthColors.blobTop),
            ),
            Positioned(
              bottom: -120,
              right: -100,
              child: _blob(320, AuthColors.blobBottom),
            ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }

  static Widget _blob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}