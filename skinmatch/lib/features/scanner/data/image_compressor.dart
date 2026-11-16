import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import 'scanner_models.dart';

/// Fungsi kompresi sekali jalan; dapat di-inject pada unit test.
typedef CompressOnce = Future<Uint8List?> Function(
  String sourcePath, {
  required int quality,
});

typedef TemporaryDirectoryResolver = Future<Directory> Function();

/// Menyiapkan gambar agar aman diunggah (ukuran & dimensi).
abstract interface class ImageCompressor {
  Future<CapturedScan> prepare(File source, ScanSource scanSource);
}

/// Kompresor berbasis native code (`flutter_image_compress`).
///
/// Catatan soal `minWidth`/`minHeight`: pada plugin ini nilainya berlaku
/// sebagai batas minimum sisi, bukan maksimum. Dengan memberi nilai yang sama
/// untuk keduanya, sisi pendek gambar akan turun ke [minDimension] dan sisi
/// panjang menyesuaikan rasio aslinya.
class NativeImageCompressor implements ImageCompressor {
  NativeImageCompressor({
    this.maxBytes = kMaxUploadBytes,
    this.minDimension = kDefaultImageShortSide,
    this.qualities = const [85, 75, 65, 55, 50],
    this._compressOnce,
    TemporaryDirectoryResolver? temporaryDirectory,
  })  : assert(qualities.isNotEmpty, 'Daftar kualitas tidak boleh kosong'),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final int maxBytes;
  final int minDimension;
  final List<int> qualities;

  final CompressOnce? _compressOnce;
  final TemporaryDirectoryResolver _temporaryDirectory;

  @override
  Future<CapturedScan> prepare(File source, ScanSource scanSource) async {
    if (!await source.exists()) {
      throw const ScannerFailure(
        ScannerErrorCode.compressionFailed,
        'File sumber tidak ditemukan',
      );
    }

    final originalSize = await source.length();
    if (originalSize <= maxBytes) {
      return CapturedScan(
        file: source,
        byteSize: originalSize,
        source: scanSource,
      );
    }

    final directory = await _temporaryDirectory();
    final targetPath = '${directory.path}${Platform.pathSeparator}'
        'scan_${DateTime.now().microsecondsSinceEpoch}.jpg';

    for (var index = 0; index < qualities.length; index++) {
      final quality = qualities[index];
      final isLastAttempt = index == qualities.length - 1;

      Uint8List? compressed;
      try {
        compressed = await _runCompression(source.path, quality);
      } catch (error) {
        throw ScannerFailure(
          ScannerErrorCode.compressionFailed,
          '$error',
        );
      }

      // Plugin mengembalikan null jika file tidak bisa dibaca.
      if (compressed == null) continue;

      if (compressed.length > maxBytes) {
        if (!isLastAttempt) continue;
        throw const ScannerFailure(ScannerErrorCode.imageTooLarge);
      }

      final output = File(targetPath);
      try {
        await output.writeAsBytes(compressed, flush: true);
      } catch (error) {
        throw ScannerFailure(
          ScannerErrorCode.compressionFailed,
          '$error',
        );
      }

      return CapturedScan(
        file: output,
        byteSize: compressed.length,
        source: scanSource,
      );
    }

    throw const ScannerFailure(ScannerErrorCode.imageTooLarge);
  }

  Future<Uint8List?> _runCompression(String path, int quality) {
    final override = _compressOnce;
    if (override != null) {
      return override(path, quality: quality);
    }

    return FlutterImageCompress.compressWithFile(
      path,
      minWidth: minDimension,
      minHeight: minDimension,
      quality: quality,
      format: CompressFormat.jpeg,
    );
  }
}
