import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skinmatch/main.dart';

void main() {
  setUpAll(() {
    // Test tidak boleh mengunduh font dari jaringan.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('aplikasi terbuka di layar login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkinMatchApp()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Email / No. Handphone *'), findsOneWidget);
  });
}
