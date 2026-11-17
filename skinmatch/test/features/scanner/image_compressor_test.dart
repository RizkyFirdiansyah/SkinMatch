import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/features/scanner/data/image_compressor.dart';
import 'package:skinmatch/features/scanner/data/scanner_models.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skinmatch_compressor_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File createFile(String name, int size) {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    file.writeAsBytesSync(List<int>.filled(size, 0));
    return file;
  }

  NativeImageCompressor buildCompressor({
    CompressOnce? compressOnce,
    List<int> qualities = const [85, 75, 65, 55, 50],
  }) {
    return NativeImageCompressor(
      qualities: qualities,
      temporaryDirectory: () async => tempDir,
      compressOnce: compressOnce,
    );
  }

  test('mengembalikan file asli jika ukurannya sudah di bawah batas', () async {
    final source = createFile('small.jpg', 1024);
    final compressor = buildCompressor(
      compressOnce: (path, {required quality}) async {
        fail('kompresi tidak seharusnya dipanggil');
      },
    );

    final result = await compressor.prepare(source, ScanSource.gallery);

    expect(result.file.path, source.path);
    expect(result.byteSize, 1024);
    expect(result.isWithinUploadLimit, isTrue);
  });

  test('file tepat 2 MB tetap dianggap valid tanpa kompresi', () async {
    final source = createFile('exact.jpg', kMaxUploadBytes);
    final compressor = buildCompressor(
      compressOnce: (path, {required quality}) async {
        fail('kompresi tidak seharusnya dipanggil');
      },
    );

    final result = await compressor.prepare(source, ScanSource.gallery);

    expect(result.file.path, source.path);
    expect(result.isWithinUploadLimit, isTrue);
  });

  test('menurunkan kualitas bertahap sampai file masuk batas', () async {
    final source = createFile('big.jpg', kMaxUploadBytes + 1);
    final sizes = <int>[kMaxUploadBytes + 10, kMaxUploadBytes - 1];
    var calls = 0;

    final compressor = buildCompressor(
      compressOnce: (path, {required quality}) async {
        final size = sizes[calls++];
        return Uint8List(size);
      },
    );

    final result = await compressor.prepare(source, ScanSource.camera);

    expect(calls, 2);
    expect(result.byteSize, kMaxUploadBytes - 1);
    expect(result.file.path, isNot(source.path));
    expect(result.file.existsSync(), isTrue);
    expect(result.file.lengthSync(), kMaxUploadBytes - 1);
    expect(result.source, ScanSource.camera);
  });

  test('melempar imageTooLarge jika semua kualitas masih melebihi batas',
      () async {
    final source = createFile('huge.jpg', kMaxUploadBytes + 1);
    var calls = 0;

    final compressor = buildCompressor(
      qualities: const [85, 50],
      compressOnce: (path, {required quality}) async {
        calls++;
        return Uint8List(kMaxUploadBytes + 1);
      },
    );

    await expectLater(
      compressor.prepare(source, ScanSource.camera),
      throwsA(
        isA<ScannerFailure>().having(
          (failure) => failure.code,
          'code',
          ScannerErrorCode.imageTooLarge,
        ),
      ),
    );
    expect(calls, 2);
  });

  test('membungkus error kompresi menjadi ScannerFailure', () async {
    final source = createFile('broken.jpg', kMaxUploadBytes + 1);
    final compressor = buildCompressor(
      compressOnce: (path, {required quality}) async {
        throw StateError('native encoder gagal');
      },
    );

    await expectLater(
      compressor.prepare(source, ScanSource.camera),
      throwsA(
        isA<ScannerFailure>().having(
          (failure) => failure.code,
          'code',
          ScannerErrorCode.compressionFailed,
        ),
      ),
    );
  });

  test('melempar compressionFailed jika file sumber tidak ada', () async {
    final compressor = buildCompressor();

    await expectLater(
      compressor.prepare(
        File('${tempDir.path}${Platform.pathSeparator}missing.jpg'),
        ScanSource.gallery,
      ),
      throwsA(
        isA<ScannerFailure>().having(
          (failure) => failure.code,
          'code',
          ScannerErrorCode.compressionFailed,
        ),
      ),
    );
  });
}
