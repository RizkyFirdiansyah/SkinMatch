import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skinmatch/features/auth/presentation/auth_screen.dart';
import 'package:skinmatch/features/auth/presentation/welcome_screen.dart';

void main() {
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
