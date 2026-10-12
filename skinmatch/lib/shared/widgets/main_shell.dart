import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/routing/app_router.dart';

/// Shell wrapper yang menyediakan Bottom Navigation Bar
/// untuk layar-layar utama: Scanner & History
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _NavItem(
      label: 'Riwayat',
      icon: LucideIcons.clock,
      route: AppRoutes.history,
    ),
    _NavItem(
      label: 'Pindai',
      icon: LucideIcons.scan_line,
      route: AppRoutes.scan,
    ),
    _NavItem(label: 'Profil', icon: LucideIcons.user, route: AppRoutes.profile),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.history)) return 0;
    if (location.startsWith(AppRoutes.profile)) return 2;
    return 1; // default: scan
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          border: const Border(top: BorderSide(color: AppColors.borderMuted)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;
                final isCenterScan = i == 1;

                if (isCenterScan) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => context.go(tab.route),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primarySage,
                              shape: BoxShape.circle,
                              boxShadow: AppColors.buttonGlow,
                            ),
                            child: Icon(
                              tab.icon,
                              color: AppColors.textOnDark,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.route),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          color: isActive
                              ? AppColors.primarySage
                              : AppColors.textTertiary,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: AppTypography.labelSmall.copyWith(
                            color: isActive
                                ? AppColors.primarySage
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;
}
