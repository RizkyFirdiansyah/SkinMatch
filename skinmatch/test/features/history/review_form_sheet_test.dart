import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skinmatch/features/history/widgets/review_form_sheet.dart';
import 'package:skinmatch/shared/models/skinmatch_models.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('review form mengirim verdict, rating, dan komentar', (
    tester,
  ) async {
    int? submittedRating;
    bool? submittedCocok;
    String? submittedComment;
    final item = ProductHistoryItem(
      historyId: 'scan-1',
      scanResult: const ScanAnalysisResult(
        scanId: 'scan-1',
        userId: 'user-1',
        timestamp: '24/11/2026 04:00',
        brand: 'SkinMatch',
        productName: 'Produk Uji',
        verdict: SuitabilityVerdict.cocok,
        comedogenicScale: 'Belum tersedia',
        formulaPh: 'Belum tersedia',
        ingredients: [],
        routineRecommendation: 'Hasil analisis',
      ),
      trialStatus: TrialStatus.unreviewed,
      aiFeedbackApplied: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => ReviewFormSheet(
                    item: item,
                    initialCocok: true,
                    initialRating: null,
                    initialComment: '',
                    onSubmit: (rating, cocok, comment) async {
                      submittedRating = rating;
                      submittedCocok = cocok;
                      submittedComment = comment;
                      return true;
                    },
                  ),
                );
              },
              child: const Text('Buka review'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masalah'));
    await tester.tap(find.byTooltip('4 bintang'));
    await tester.enterText(find.byType(TextField), 'Kulit terasa kemerahan.');
    await tester.ensureVisible(find.text('Kirim Ulasan'));
    await tester.tap(find.text('Kirim Ulasan'));
    await tester.pumpAndSettle();

    expect(submittedRating, 4);
    expect(submittedCocok, isFalse);
    expect(submittedComment, 'Kulit terasa kemerahan.');
  });

  testWidgets('hapus ulasan memerlukan konfirmasi', (tester) async {
    var reviewDeleted = false;
    final item = ProductHistoryItem(
      historyId: 'scan-2',
      scanResult: const ScanAnalysisResult(
        scanId: 'scan-2',
        userId: 'user-1',
        timestamp: '24/11/2026 04:00',
        brand: 'SkinMatch',
        productName: 'Produk Uji',
        verdict: SuitabilityVerdict.cocok,
        comedogenicScale: 'Belum tersedia',
        formulaPh: 'Belum tersedia',
        ingredients: [],
        routineRecommendation: 'Hasil analisis',
      ),
      trialStatus: TrialStatus.completedSuccess,
      aiFeedbackApplied: false,
      review: const ProductReview(
        rating: 4,
        userNotes: 'Kulit terasa nyaman.',
        confirmedMatch: true,
        reviewedAt: '24/11/2026 04:00',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => ReviewFormSheet(
                    item: item,
                    initialCocok: true,
                    initialRating: 4,
                    initialComment: 'Kulit terasa nyaman.',
                    onSubmit: (_, _, _) async => true,
                    onDelete: () async {
                      reviewDeleted = true;
                      return true;
                    },
                  ),
                );
              },
              child: const Text('Buka review'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka review'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hapus Ulasan'));
    await tester.tap(find.text('Hapus Ulasan'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus ulasan ini?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(reviewDeleted, isTrue);
    expect(find.text('Hapus ulasan ini?'), findsNothing);
  });
}
