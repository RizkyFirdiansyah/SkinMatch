import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/features/history/widgets/history_list_item.dart';
import 'package:skinmatch/shared/models/skinmatch_models.dart';

void main() {
  testWidgets('memilih bintang mengirim rating dan menyorot bintang terpilih', (
    tester,
  ) async {
    var selectedRating = 0;
    var analysisOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: HistoryListItem(
              item: ProductHistoryItem(
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
              ),
              onTap: () => analysisOpened = true,
              onMarkGood: () {},
              onMarkBad: () {},
              selectedRating: selectedRating == 0 ? null : selectedRating,
              onEditReview: () {},
              onRatingSelected: (rating) {
                setState(() => selectedRating = rating);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Beri nilai 3 bintang'));
    await tester.pump();

    expect(selectedRating, 3);
    expect(analysisOpened, isFalse);
    final selectedStar = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('Beri nilai 3 bintang'),
        matching: find.byIcon(Icons.star),
      ),
    );
    expect(selectedStar.color, const Color(0xFFF59E0B));

    await tester.tap(find.text('Produk Uji'));
    expect(analysisOpened, isTrue);
  });
}
