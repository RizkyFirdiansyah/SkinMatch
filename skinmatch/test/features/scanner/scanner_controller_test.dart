import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skinmatch/features/scanner/application/scanner_controller.dart';
import 'package:skinmatch/features/scanner/data/scanner_models.dart';

import '../../helpers/scanner_fakes.dart';

class _Harness {
  _Harness({
    ScannerFailure? initializeFailure,
    bool cameraUnavailable = false,
    bool permanentlyDenied = false,
  }) {
    camera = FakeCameraGateway(
      initializeFailure: initializeFailure ??
          (permanentlyDenied
              ? const ScannerFailure(
                  ScannerErrorCode.permissionPermanentlyDenied,
                )
              : cameraUnavailable
                  ? const ScannerFailure(ScannerErrorCode.cameraUnavailable)
                  : null),
    );
    compressor = FakeImageCompressor();
    gallery = FakeGalleryGateway();
    analysis = FakeAnalysisService();
    settings = FakeSettingsLauncher();

    if (permanentlyDenied) {
      camera.permissionStatus = PermissionStatus.permanentlyDenied;
    }

    controller = ScannerController(
      camera: camera,
      compressor: compressor,
      gallery: gallery,
      analysis: analysis,
      openSettings: settings.call,
    );
  }

  late final FakeCameraGateway camera;
  late final FakeImageCompressor compressor;
  late final FakeGalleryGateway gallery;
  late final FakeAnalysisService analysis;
  late final FakeSettingsLauncher settings;
  late final ScannerController controller;

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _Harness build([ScannerFailure? initializeFailure]) {
    final harness = _Harness(initializeFailure: initializeFailure);
    addTearDown(harness.dispose);
    return harness;
  }

  test('start menginisialisasi kamera dan masuk ke stage ready', () async {
    final harness = build();

    await harness.controller.start();

    expect(harness.controller.stage, ScannerStage.ready);
    expect(harness.camera.initializeCalls, 1);
    expect(harness.controller.canCapture, isTrue);
  });

  test('izin kamera ditolak menampilkan stage permissionDenied', () async {
    final harness = build(
      const ScannerFailure(ScannerErrorCode.permissionDenied),
    );

    await harness.controller.start();

    expect(harness.controller.stage, ScannerStage.permissionDenied);
    expect(
      harness.controller.failure?.code,
      ScannerErrorCode.permissionDenied,
    );
  });

  test('izin ditolak permanen menampilkan stage permissionPermanentlyDenied',
      () async {
    final harness = _Harness(permanentlyDenied: true);
    addTearDown(harness.dispose);

    await harness.controller.start();

    expect(
      harness.controller.stage,
      ScannerStage.permissionPermanentlyDenied,
    );
  });

  test('kamera tidak tersedia menampilkan stage cameraUnavailable', () async {
    final harness = _Harness(cameraUnavailable: true);
    addTearDown(harness.dispose);

    await harness.controller.start();

    expect(harness.controller.stage, ScannerStage.cameraUnavailable);
  });

  test('capture sukses menjalankan kompresi lalu analisis', () async {
    final harness = build();
    await harness.controller.start();

    final outcome = await harness.controller.capture();

    expect(outcome?.isSuccess, isTrue);
    expect(outcome?.scanId, 'test-scan-001');
    expect(harness.camera.captureCalls, 1);
    expect(harness.compressor.prepareCalls, 1);
    expect(harness.analysis.submitCalls, 1);
    expect(harness.analysis.lastScan?.source, ScanSource.camera);
    expect(harness.controller.stage, ScannerStage.ready);
  });

  test('capture diabaikan jika kamera belum siap', () async {
    final harness = build();

    final outcome = await harness.controller.capture();

    expect(outcome?.isSuccess, isFalse);
    expect(harness.camera.captureCalls, 0);
  });

  test('tap capture dua kali hanya menghasilkan satu pengambilan foto',
      () async {
    final harness = build();
    await harness.controller.start();

    final first = harness.controller.capture();
    final second = harness.controller.capture();
    final results = await Future.wait([first, second]);

    expect(results.first?.isSuccess, isTrue);
    expect(results.last, isNull);
    expect(harness.camera.captureCalls, 1);
  });

  test('galeri yang dibatalkan tidak memicu analisis', () async {
    final harness = build();
    await harness.controller.start();
    harness.gallery.nextPath = null;

    final outcome = await harness.controller.pickFromGallery();

    expect(outcome, isNull);
    expect(harness.gallery.pickCalls, 1);
    expect(harness.analysis.submitCalls, 0);
    expect(harness.controller.stage, ScannerStage.ready);
  });

  test('gambar dari galeri diproses dan dianalisis', () async {
    final harness = build();
    await harness.controller.start();
    harness.gallery.nextPath = 'gallery.jpg';

    final outcome = await harness.controller.pickFromGallery();

    expect(outcome?.isSuccess, isTrue);
    expect(harness.analysis.lastScan?.source, ScanSource.gallery);
    expect(harness.controller.stage, ScannerStage.ready);
  });

  test('galeri tetap bisa dipakai saat izin kamera ditolak', () async {
    final harness = build(
      const ScannerFailure(ScannerErrorCode.permissionDenied),
    );
    await harness.controller.start();
    harness.gallery.nextPath = 'gallery.jpg';

    final outcome = await harness.controller.pickFromGallery();

    expect(outcome?.isSuccess, isTrue);
    expect(harness.controller.stage, ScannerStage.permissionDenied);
  });

  test('toggleTorch sukses mengubah state torch', () async {
    final harness = build();
    await harness.controller.start();

    final failure = await harness.controller.toggleTorch();

    expect(failure, isNull);
    expect(harness.controller.torchOn, isTrue);
    expect(harness.camera.torchEnabled, isTrue);
  });

  test('toggleTorch gagal tidak mengubah state dan mengembalikan failure',
      () async {
    final harness = build();
    await harness.controller.start();
    harness.camera.torchFailure = const ScannerFailure(
      ScannerErrorCode.torchUnavailable,
    );

    final failure = await harness.controller.toggleTorch();

    expect(failure?.code, ScannerErrorCode.torchUnavailable);
    expect(harness.controller.torchOn, isFalse);
    expect(harness.controller.stage, ScannerStage.ready);
  });

  test('kegagalan kompresi tetap mempertahankan preview kamera', () async {
    final harness = build();
    await harness.controller.start();
    harness.compressor.failure = const ScannerFailure(
      ScannerErrorCode.imageTooLarge,
    );

    final outcome = await harness.controller.capture();

    expect(outcome?.failure?.code, ScannerErrorCode.imageTooLarge);
    expect(harness.analysis.submitCalls, 0);
    expect(harness.controller.stage, ScannerStage.ready);
  });

  test('pauseCamera melepas kamera dan mereset torch', () async {
    final harness = build();
    await harness.controller.start();
    await harness.controller.toggleTorch();

    await harness.controller.pauseCamera();

    expect(harness.controller.stage, ScannerStage.booting);
    expect(harness.controller.torchOn, isFalse);
    expect(harness.camera.disposeCalls, greaterThanOrEqualTo(1));
  });

  test('lifecycle pause melepas kamera dan resume menginisialisasi ulang',
      () async {
    final harness = build();
    await harness.controller.start();

    harness.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();

    expect(harness.controller.stage, ScannerStage.booting);

    harness.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(harness.controller.stage, ScannerStage.ready);
    expect(harness.camera.initializeCalls, 2);
  });

  test('resume setelah izin diaktifkan mencoba membuka kamera lagi', () async {
    final harness = _Harness(permanentlyDenied: true);
    addTearDown(harness.dispose);

    await harness.controller.start();
    expect(
      harness.controller.stage,
      ScannerStage.permissionPermanentlyDenied,
    );

    // Pengguna mengaktifkan izin lewat Pengaturan lalu kembali ke aplikasi.
    harness.camera.initializeFailure = null;
    harness.camera.permissionStatus = PermissionStatus.granted;
    harness.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(harness.controller.stage, ScannerStage.ready);
    expect(harness.camera.initializeCalls, 2);
  });

  test(
    'resume saat izin tetap ditolak tidak memicu inisialisasi berulang',
    () async {
      final harness = _Harness(permanentlyDenied: true);
      addTearDown(harness.dispose);

      await harness.controller.start();
      expect(
        harness.controller.stage,
        ScannerStage.permissionPermanentlyDenied,
      );
      expect(harness.camera.initializeCalls, 1);

      // Regresi: sebelumnya resume meminta izin lagi, yang memicu siklus
      // lifecycle inactive→resumed dan berujung loop tanpa henti.
      for (var i = 0; i < 5; i++) {
        harness.controller.didChangeAppLifecycleState(
          AppLifecycleState.resumed,
        );
        await pumpEventQueue();
      }

      expect(harness.controller.stage, ScannerStage.permissionPermanentlyDenied);
      expect(harness.camera.initializeCalls, 1);
      expect(harness.camera.checkPermissionCalls, 5);
    },
  );

  test('resume membuka ulang kamera bila preview sudah tidak siap', () async {
    final harness = build();
    await harness.controller.start();

    // OS melepas kamera tanpa sempat mengubah stage (mis. saat app di-pause
    // ketika proses analisis sedang berjalan).
    harness.camera.simulateCameraLost();
    harness.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(harness.controller.stage, ScannerStage.ready);
    expect(harness.camera.initializeCalls, 2);
  });

  test('capture membuka ulang kamera bila kamera hilang saat analisis',
      () async {
    final harness = build();
    await harness.controller.start();

    final gate = Completer<void>();
    harness.analysis.gate = gate;
    final pending = harness.controller.capture();
    await pumpEventQueue();

    // OS melepas kamera ketika aplikasi di background selama analisis.
    harness.camera.simulateCameraLost();
    gate.complete();
    await pending;
    await pumpEventQueue();

    expect(harness.controller.stage, ScannerStage.ready);
    expect(harness.camera.initializeCalls, 2);
  });

  test('dispose melepas kamera', () async {
    final harness = _Harness();
    final controller = harness.controller;
    await controller.start();

    controller.dispose();
    await pumpEventQueue();

    expect(harness.camera.disposeCalls, greaterThanOrEqualTo(1));
  });

  test('openSettings memanggil launcher yang di-inject', () async {
    final harness = build();

    await harness.controller.openSettings();

    expect(harness.settings.calls, 1);
  });
}
