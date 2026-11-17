import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skinmatch/features/auth/presentation/auth_screen.dart';
import 'package:skinmatch/features/auth/presentation/welcome_screen.dart';
import 'package:skinmatch/features/home/presentation/home_screen.dart';
import 'package:skinmatch/core/network/api_client.dart';
import 'package:skinmatch/shared/models/skinmatch_models.dart';

void main() {
  testWidgets('home shows profile and scan summary with history entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProfileProvider.overrideWith(
            (ref) async => {
              'name': 'Siti',
              'skin_type': 'Kombinasi',
              'age_range': '25-34',
            },
          ),
          scanHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Halo, Siti'), findsOneWidget);
    expect(find.text('Kombinasi  ·  25-34 tahun'), findsOneWidget);
    expect(find.text('Terakhir dipindai'), findsOneWidget);
    expect(find.text('Lihat semua'), findsOneWidget);
    expect(find.text('Belum ada hasil pindai'), findsOneWidget);

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    expect(find.text('Siti'), findsOneWidget);
    expect(find.text('Edit Profil'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Pengaturan'), findsNothing);
  });

  testWidgets('home calculates scan count and average match from history', (
    tester,
  ) async {
    final scans = [
      _historyItem(scanId: '1', productName: 'Serum A', score: 88),
      _historyItem(scanId: '2', productName: 'Serum B', score: 94),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProfileProvider.overrideWith(
            (ref) async => {'name': 'Siti', 'skin_type': 'Kering'},
          ),
          scanHistoryProvider.overrideWith((ref) async => scans),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('91%'), findsOneWidget);
    expect(find.text('Serum A'), findsOneWidget);
    expect(find.text('Serum B'), findsOneWidget);
  });

  testWidgets('welcome page opens and advances through the tutorial', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(
      find.text('Kenali skincare yang cocok untuk kulitmu'),
      findsOneWidget,
    );
    expect(find.text('INGREDIENTS'), findsOneWidget);
    expect(find.text('Niacinamide, Panthenol'), findsOneWidget);
    expect(find.text('Mulai Sekarang'), findsOneWidget);

    await tester.tap(find.text('Lihat Tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Isi profil kulitmu'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Pindai daftar bahan'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Baca hasilnya'), findsOneWidget);
    expect(find.text('Mulai Sekarang'), findsNWidgets(2));
  });

  testWidgets('login and registration forms request email addresses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );

    expect(find.text('Email *'), findsOneWidget);
    expect(find.textContaining('No. Handphone'), findsNothing);

    await tester.ensureVisible(find.text('Daftar Disini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar Disini'));
    await tester.pumpAndSettle();

    expect(find.text('Nama Lengkap *'), findsOneWidget);
    expect(find.text('Email *'), findsOneWidget);
    expect(find.textContaining('No. Handphone'), findsNothing);
  });
}

ProductHistoryItem _historyItem({
  required String scanId,
  required String productName,
  required int score,
}) {
  return ProductHistoryItem(
    historyId: scanId,
    scanResult: ScanAnalysisResult(
      scanId: scanId,
      userId: 'user-1',
      timestamp: '17/11/2026 08:00',
      brand: 'SkinMatch',
      productName: productName,
      matchScore: score,
      safetyStatus: ScanAnalysisResult.statusFromScore(score),
      allergyPotential: AllergyPotential.low,
      comedogenicScale: 'Belum tersedia',
      formulaPh: 'Belum tersedia',
      ingredients: const [],
      routineRecommendation: 'Aman',
    ),
    trialStatus: TrialStatus.unreviewed,
    aiFeedbackApplied: false,
  );
}
