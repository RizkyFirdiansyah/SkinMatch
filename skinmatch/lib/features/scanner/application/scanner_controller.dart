import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/analysis_service.dart';
import '../data/camera_gateway.dart';
import '../data/gallery_gateway.dart';
import '../data/image_compressor.dart';
import '../data/scanner_models.dart';

/// Mengatur lifecycle kamera dan alur capture/kompresi/analisis.
///
/// Widget hanya bertugas merender [stage] dan memanggil aksi di sini, sehingga
/// seluruh alur bisa diuji tanpa perangkat fisik.
class ScannerController extends ChangeNotifier with WidgetsBindingObserver {
  ScannerController({
    required this._camera,
    required this._compressor,
    required this._gallery,
    required this._analysis,
    Future<bool> Function()? openSettings,
  }) : _openSettings = openSettings ?? openAppSettings;

  final CameraGateway _camera;
  final ImageCompressor _compressor;
  final GalleryGateway _gallery;
  final AnalysisService _analysis;
  final Future<bool> Function() _openSettings;

  ScannerStage _stage = ScannerStage.booting;
  ScannerFailure? _failure;
  bool _torchOn = false;
  bool _busy = false;
  bool _observing = false;
  bool _disposed = false;
  bool _suspendedByLifecycle = false;

  ScannerStage get stage => _stage;
  ScannerFailure? get failure => _failure;
  bool get torchOn => _torchOn;
  bool get isBusy => _busy;
  bool get showsPreview =>
      _stage == ScannerStage.ready ||
      _stage == ScannerStage.capturing ||
      _stage == ScannerStage.compressing ||
      _stage == ScannerStage.analyzing;

  bool get canCapture => _stage == ScannerStage.ready && !_busy;

  /// Preview dari gateway; aman dipanggil kapan saja.
  Widget buildPreview() => _camera.buildPreview();

  Future<void> start() async {
    if (_disposed || _busy) return;

    _attachObserver();
    _suspendedByLifecycle = false;
    _busy = true;
    _setStage(ScannerStage.booting);

    try {
      await _camera.initialize();
      _torchOn = false;
      _failure = null;
      _setStage(ScannerStage.ready);
    } on ScannerFailure catch (error) {
      _applyFailure(error);
    } catch (error) {
      _applyFailure(ScannerFailure(ScannerErrorCode.unknown, '$error'));
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<ScanOutcome?> capture() => _process(ScanSource.camera);

  Future<ScanOutcome?> pickFromGallery() => _process(ScanSource.gallery);

  Future<ScannerFailure?> toggleTorch() async {
    if (_disposed || _busy || _stage != ScannerStage.ready) return null;

    final next = !_torchOn;
    try {
      await _camera.setTorch(next);
      _torchOn = next;
      _failure = null;
      _notify();
      return null;
    } on ScannerFailure catch (error) {
      _failure = error;
      _notify();
      return error;
    } catch (error) {
      final failure = ScannerFailure(
        ScannerErrorCode.torchUnavailable,
        '$error',
      );
      _failure = failure;
      _notify();
      return failure;
    }
  }

  Future<void> openSettings() => _openSettings();

  /// Melepas kamera sebelum layar lain dibuka (mis. halaman hasil).
  Future<void> pauseCamera() async {
    if (_disposed) return;
    _suspendedByLifecycle = false;
    await _camera.dispose();
    _torchOn = false;
    _setStage(ScannerStage.booting);
  }

  Future<ScanOutcome?> _process(ScanSource source) async {
    if (_disposed || _busy) return null;
    if (source == ScanSource.camera && !_camera.isReady) {
      // Kamera bisa hilang tanpa perubahan stage; coba buka ulang agar tombol
      // pindai tidak gagal terus-menerus.
      if (_stage == ScannerStage.ready) unawaited(start());
      return const ScanOutcome.failed(
        ScannerFailure(ScannerErrorCode.captureFailed),
      );
    }

    final previousStage = _stage;
    _busy = true;
    File? rawFile;
    CapturedScan? prepared;

    try {
      _failure = null;

      if (source == ScanSource.camera) {
        _setStage(ScannerStage.capturing);
        final shot = await _camera.capture();
        rawFile = File(shot.path);
      } else {
        // Sembunyikan kontrol selama system photo picker terbuka.
        _setStage(ScannerStage.booting);
        final picked = await _gallery.pickImage();
        if (picked == null) {
          _setStage(previousStage);
          return null;
        }
        rawFile = File(picked.path);
      }

      _setStage(ScannerStage.compressing);
      prepared = await _compressor.prepare(rawFile, source);

      _setStage(ScannerStage.analyzing);
      final scanId = await _analysis.submit(prepared);

      _setStage(_camera.isReady ? ScannerStage.ready : previousStage);
      return ScanOutcome.success(scanId);
    } on ScannerFailure catch (error) {
      _applyFailure(error);
      return ScanOutcome.failed(error);
    } catch (error) {
      final failure = ScannerFailure(ScannerErrorCode.unknown, '$error');
      _applyFailure(failure);
      return ScanOutcome.failed(failure);
    } finally {
      // Hapus file capture kamera bila kompresor membuat file baru.
      if (source == ScanSource.camera &&
          rawFile != null &&
          (prepared == null || prepared.file.path != rawFile.path)) {
        await _deleteQuietly(rawFile);
      }
      _busy = false;
      _notify();

      // OS bisa melepas kamera saat proses analisis berjalan (aplikasi sempat
      // di background). Bila stage kembali ke ready tanpa preview, buka ulang
      // supaya pengguna tidak melihat layar hitam.
      if (source == ScanSource.camera &&
          _stage == ScannerStage.ready &&
          !_camera.isReady) {
        unawaited(start());
      }
    }
  }

  void _applyFailure(ScannerFailure failure) {
    _failure = failure;

    switch (failure.code) {
      case ScannerErrorCode.permissionDenied:
        _setStage(ScannerStage.permissionDenied);
      case ScannerErrorCode.permissionPermanentlyDenied:
        _setStage(ScannerStage.permissionPermanentlyDenied);
      case ScannerErrorCode.cameraUnavailable:
        _setStage(ScannerStage.cameraUnavailable);
      default:
        _setStage(_camera.isReady ? ScannerStage.ready : ScannerStage.failure);
    }
  }

  void _attachObserver() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _busy) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_suspendForLifecycle());
      case AppLifecycleState.resumed:
        unawaited(_resumeFromLifecycle());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _suspendForLifecycle() async {
    if (_disposed || _busy || _stage != ScannerStage.ready) return;
    _torchOn = false;
    _suspendedByLifecycle = true;
    // Ubah stage lebih dulu agar event lifecycle berikutnya (paused setelah
    // inactive) tidak memicu dispose kedua.
    _setStage(ScannerStage.booting);
    await _camera.dispose();
  }

  Future<void> _resumeFromLifecycle() async {
    if (_disposed || _busy) return;

    if (_suspendedByLifecycle) {
      _suspendedByLifecycle = false;
      if (_stage == ScannerStage.booting) {
        await start();
      }
      return;
    }

    // Kamera bisa saja dilepas OS saat aplikasi di background, misalnya saat
    // halaman hasil dibuka. Buka ulang bila preview sudah tidak siap.
    if (_stage == ScannerStage.ready && !_camera.isReady) {
      await start();
      return;
    }

    // Pengguna mungkin baru mengaktifkan izin lewat Pengaturan aplikasi.
    // Status izin dibaca tanpa memunculkan dialog: meminta izin di sini akan
    // memicu siklus lifecycle inactive→resumed yang memanggil method ini lagi
    // (loop tanpa henti saat izin ditolak permanen).
    if (_stage == ScannerStage.permissionPermanentlyDenied) {
      final status = await _camera.checkPermission();
      if (_disposed) return;
      if (status.isGranted || status.isLimited) {
        await start();
      }
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // File cache boleh gagal dihapus; tidak perlu mengganggu pengguna.
    }
  }

  void _setStage(ScannerStage stage) {
    if (_stage == stage) return;
    _stage = stage;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    unawaited(_camera.dispose());
    super.dispose();
  }
}
