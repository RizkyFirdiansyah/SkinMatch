import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skinmatch/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('login and registration forms request email addresses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthScreen()),
      ),
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
