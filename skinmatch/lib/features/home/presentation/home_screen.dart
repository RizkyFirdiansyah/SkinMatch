import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/skinmatch_models.dart';

final homeProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  return ref.watch(apiClientProvider).getProfile();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(homeProfileProvider);
    final history = ref.watch(scanHistoryProvider);
    final userName = profile.asData?.value['name']?.toString().trim() ?? '';
    final firstName = userName.isEmpty
        ? 'Pengguna'
        : userName.split(RegExp(r'\s+')).first;
    final ageRange = profile.asData?.value['age_range']?.toString();
    final skinType = profile.asData?.value['skin_type']?.toString();

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeProfileProvider);
            ref.invalidate(scanHistoryProvider);
            await Future.wait([
              ref.read(homeProfileProvider.future),
              ref.read(scanHistoryProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _HomeHeader(
                name: firstName,
                displayName: userName.isEmpty ? 'Pengguna' : userName,
                skinType: skinType,
                ageRange: ageRange,
              ),
              const SizedBox(height: 20),
              _ScanPrompt(onScan: () => context.go(AppRoutes.scan)),
              const SizedBox(height: 14),
              profile.when(
                data: (data) => _ProfileSummary(
                  skinType: data['skin_type']?.toString(),
                  ageRange: data['age_range']?.toString(),
                ),
                loading: () => const _LoadingCard(height: 84),
                error: (error, _) => _ErrorCard(
                  message: 'Profil kulit tidak dapat dimuat: $error',
                  onRetry: () => ref.invalidate(homeProfileProvider),
                ),
              ),
              const SizedBox(height: 12),
              history.when(
                data: (items) => _HistoryOverview(items: items),
                loading: () => const _LoadingCard(height: 88),
                error: (error, _) => _ErrorCard(
                  message: 'Ringkasan pindai tidak dapat dimuat: $error',
                  onRetry: () => ref.invalidate(scanHistoryProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.name,
    required this.displayName,
    required this.skinType,
    required this.ageRange,
  });

  final String name;
  final String displayName;
  final String? skinType;
  final String? ageRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      < 11 => 'Selamat pagi',
      < 15 => 'Selamat siang',
      < 18 => 'Selamat sore',
      _ => 'Selamat malam',
    };
    final initial = name.isEmpty ? 'U' : name[0].toUpperCase();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Halo, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headingLarge.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<_ProfileMenuAction>(
          tooltip: 'Menu profil',
          color: AppColors.cardSurface,
          elevation: 8,
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onSelected: (action) async {
            switch (action) {
              case _ProfileMenuAction.editProfile:
                context.go(AppRoutes.profile);
              case _ProfileMenuAction.logout:
                await _logout(context, ref);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<_ProfileMenuAction>(
              enabled: false,
              height: 66,
              child: SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (skinType != null && skinType!.isNotEmpty) skinType!,
                        if (ageRange != null && ageRange!.isNotEmpty)
                          '$ageRange tahun',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<_ProfileMenuAction>(
              value: _ProfileMenuAction.editProfile,
              child: _ProfileMenuLabel(
                icon: Icons.edit_outlined,
                label: 'Edit Profil',
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<_ProfileMenuAction>(
              value: _ProfileMenuAction.logout,
              child: _ProfileMenuLabel(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                isDestructive: true,
              ),
            ),
          ],
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.statusSafeBg,
            child: Text(
              initial,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).logout();
      ref.invalidate(scanHistoryProvider);
      ref.invalidate(homeProfileProvider);
      if (context.mounted) context.go(AppRoutes.auth);
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      final message = error.message;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message == null || message.isEmpty
                  ? 'Tidak dapat keluar dari akun. Coba lagi.'
                  : 'Tidak dapat keluar dari akun: $message',
            ),
          ),
        );
    }
  }
}

enum _ProfileMenuAction { editProfile, logout }

class _ProfileMenuLabel extends StatelessWidget {
  const _ProfileMenuLabel({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.statusDanger
        : AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: AppTypography.labelLarge.copyWith(color: color)),
      ],
    );
  }
}

class _ScanPrompt extends StatelessWidget {
  const _ScanPrompt({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cek komposisi skincare-mu sekarang',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pindai label komposisi dan lihat kecocokannya dengan kulitmu.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text('Pindai Komposisi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cardSurface,
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.skinType, required this.ageRange});

  final String? skinType;
  final String? ageRange;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (skinType != null && skinType!.isNotEmpty) skinType!,
      if (ageRange != null && ageRange!.isNotEmpty) '$ageRange tahun',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.face_retouching_natural_outlined,
            size: 22,
            color: AppColors.primarySage,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil kulitmu',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  details.isEmpty
                      ? 'Lengkapi profil kulitmu'
                      : details.join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.profile),
            child: const Text('Ubah'),
          ),
        ],
      ),
    );
  }
}

class _HistoryOverview extends StatelessWidget {
  const _HistoryOverview({required this.items});

  final List<ProductHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final averageMatch = items.isEmpty
        ? 0
        : (items.fold<int>(
                    0,
                    (total, item) => total + item.scanResult.matchScore,
                  ) /
                  items.length)
              .round();
    final recentItems = items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(value: '${items.length}', label: 'Dipindai'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: '$averageMatch%',
                label: 'Rata-rata cocok',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Terakhir dipindai',
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.history),
              child: const Text('Lihat semua'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (recentItems.isEmpty)
          _EmptyHistory(onScan: () => context.go(AppRoutes.scan))
        else
          ...recentItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentScanTile(
                item: item,
                onTap: () => context.push(
                  AppRoutes.analysisPath(item.scanResult.scanId),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.headingLarge.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.item, required this.onTap});

  final ProductHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = item.scanResult.matchScore;
    final scoreColor = score >= 80
        ? AppColors.statusSafe
        : score >= 60
        ? AppColors.statusWarningDark
        : AppColors.statusDanger;
    final scoreBackground = score >= 80
        ? AppColors.statusSafeBg
        : score >= 60
        ? AppColors.statusWarningBg
        : AppColors.statusDangerBg;

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.statusSafeBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  item.scanResult.brand.isEmpty
                      ? '?'
                      : item.scanResult.brand[0].toUpperCase(),
                  style: AppTypography.headingMedium.copyWith(
                    color: AppColors.primarySage,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.scanResult.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.scanResult.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.scanResult.timestamp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scoreBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$score%',
                  style: AppTypography.labelSmall.copyWith(color: scoreColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.document_scanner_outlined,
            size: 30,
            color: AppColors.primarySage,
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada hasil pindai',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mulai pindai komposisi produk untuk melihat ringkasan di sini.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onScan, child: const Text('Mulai pindai')),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusDangerBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusDanger,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Coba lagi',
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.statusDanger,
            ),
          ),
        ],
      ),
    );
  }
}
