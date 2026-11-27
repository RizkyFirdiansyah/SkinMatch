import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import 'scanner_models.dart';

/// Titik integrasi ke backend `POST /api/scans`.
///
/// Saat ini masih dummy agar alur kamera bisa diselesaikan lebih dulu.
/// Nanti implementasi API cukup mengembalikan `scan_id` dari response.
abstract interface class AnalysisService {
  Future<String> submit(CapturedScan scan);
}

class ApiAnalysisService implements AnalysisService {
  const ApiAnalysisService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<String> submit(CapturedScan scan) async {
    try {
      final result = await _apiClient.uploadScan(XFile(scan.file.path));
      final scanId = result['scan_id'];
      if (scanId is int && scanId > 0) return scanId.toString();
      throw const ScannerFailure(
        ScannerErrorCode.analysisFailed,
        'Server tidak mengembalikan ID pindai yang valid.',
      );
    } on ApiException catch (error) {
      throw ScannerFailure(ScannerErrorCode.analysisFailed, error.message);
    }
  }
}
