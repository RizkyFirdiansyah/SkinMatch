import 'dart:io';

import 'package:flutter/foundation.dart';

/// Batas ukuran file yang diterima backend (`POST /api/scans`).
const int kMaxUploadBytes = 2 * 1024 * 1024;

/// Sisi pendek gambar setelah dikompresi.
///
/// Untuk foto 4:3, hasilnya sekitar 1920x1440 px — cukup tajam untuk OCR
/// tetapi tetap jauh di bawah batas 2 MB.
const int kDefaultImageShortSide = 1440;

/// Tahapan layar pemindai.
enum ScannerStage {
  booting,
  ready,
  capturing,
  compressing,
  analyzing,
  permissionDenied,
  permissionPermanentlyDenied,
  cameraUnavailable,
  failure,
}

/// Asal gambar yang sedang diproses.
enum ScanSource { camera, gallery }

/// Kode kegagalan yang bisa ditampilkan ke pengguna.
enum ScannerErrorCode {
  permissionDenied,
  permissionPermanentlyDenied,
  cameraUnavailable,
  torchUnavailable,
  captureFailed,
  compressionFailed,
  imageTooLarge,
  analysisFailed,
  unknown,
}

/// Kegagalan pada lapisan scanner, lengkap dengan pesan siap tampil.
@immutable
class ScannerFailure implements Exception {
  const ScannerFailure(this.code, [this.detail]);

  final ScannerErrorCode code;

  /// Detail teknis untuk log; jangan tampilkan langsung ke pengguna.
  final String? detail;

  String get userMessage {
    switch (code) {
      case ScannerErrorCode.permissionDenied:
        return 'Izin kamera diperlukan untuk memindai label.';
      case ScannerErrorCode.permissionPermanentlyDenied:
        return 'Izin kamera ditolak. Aktifkan lewat Pengaturan aplikasi.';
      case ScannerErrorCode.cameraUnavailable:
        return 'Kamera tidak tersedia di perangkat ini.';
      case ScannerErrorCode.torchUnavailable:
        return 'Flash tidak tersedia di perangkat ini.';
      case ScannerErrorCode.captureFailed:
        return 'Gagal mengambil foto. Silakan coba lagi.';
      case ScannerErrorCode.compressionFailed:
        return 'Gagal memproses gambar. Silakan coba lagi.';
      case ScannerErrorCode.imageTooLarge:
        return 'Ukuran gambar terlalu besar. Silakan ambil ulang foto.';
      case ScannerErrorCode.analysisFailed:
        return 'Gagal menganalisis gambar. Silakan coba lagi.';
      case ScannerErrorCode.unknown:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  @override
  String toString() => 'ScannerFailure(${code.name}, detail: $detail)';
}

/// Hasil capture/kompresi yang siap dianalisis.
@immutable
class CapturedScan {
  const CapturedScan({
    required this.file,
    required this.byteSize,
    required this.source,
  });

  final File file;
  final int byteSize;
  final ScanSource source;

  bool get isWithinUploadLimit => byteSize <= kMaxUploadBytes;
}

/// Hasil satu aksi scan: sukses (dengan `scanId`) atau gagal.
@immutable
class ScanOutcome {
  const ScanOutcome.success(String this.scanId) : failure = null;

  const ScanOutcome.failed(ScannerFailure this.failure) : scanId = null;

  final String? scanId;
  final ScannerFailure? failure;

  bool get isSuccess => scanId != null;
}
