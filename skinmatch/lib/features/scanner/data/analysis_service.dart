import 'scanner_models.dart';

/// Titik integrasi ke backend `POST /api/scans`.
///
/// Saat ini masih dummy agar alur kamera bisa diselesaikan lebih dulu.
/// Nanti implementasi API cukup mengembalikan `scan_id` dari response.
abstract interface class AnalysisService {
  Future<String> submit(CapturedScan scan);
}

class DummyAnalysisService implements AnalysisService {
  const DummyAnalysisService({
    this.delay = const Duration(milliseconds: 900),
    this.scanId = 'demo-scan-001',
  });

  final Duration delay;
  final String scanId;

  @override
  Future<String> submit(CapturedScan scan) async {
    await Future<void>.delayed(delay);
    return scanId;
  }
}
