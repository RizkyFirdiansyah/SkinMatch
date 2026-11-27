import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'scanner_models.dart';

/// Meminta izin kamera dan mengembalikan status terbaru.
///
/// `permission_handler` dipakai (bukan hanya permintaan bawaan CameraX) karena
/// hanya jalur ini yang bisa membedakan "ditolak sekali" dari
/// "jangan tanya lagi" di Android, sehingga UI bisa menawarkan tombol
/// Buka Pengaturan.
typedef CameraPermissionRequester = Future<PermissionStatus> Function();

/// Abstraksi kamera agar UI dan controller bisa dites tanpa plugin asli.
abstract interface class CameraGateway {
  bool get isReady;

  /// Widget preview yang sudah di-fit (cover) ke kotak pemanggil.
  Widget buildPreview();

  Future<void> initialize();

  /// Membaca status izin kamera tanpa memunculkan dialog.
  ///
  /// Dipakai saat aplikasi kembali ke depan agar tidak memicu permintaan izin
  /// berulang (permintaan izin sendiri memicu siklus lifecycle
  /// inactive→resumed, yang bisa berujung loop tanpa henti).
  Future<PermissionStatus> checkPermission();

  Future<void> setTorch(bool enabled);

  Future<XFile> capture();

  Future<void> dispose();
}

/// Implementasi nyata memakai plugin `camera`.
class DeviceCameraGateway implements CameraGateway {
  DeviceCameraGateway({
    this.resolutionPreset = ResolutionPreset.veryHigh,
    CameraPermissionRequester? requestCameraPermission,
    Future<PermissionStatus> Function()? readCameraPermission,
  }) : _requestCameraPermission =
           requestCameraPermission ?? Permission.camera.request,
       _readCameraPermission = readCameraPermission ?? _statusOf;

  final ResolutionPreset resolutionPreset;

  final CameraPermissionRequester _requestCameraPermission;
  final Future<PermissionStatus> Function() _readCameraPermission;

  CameraController? _controller;

  static Future<PermissionStatus> _statusOf() => Permission.camera.status;

  @override
  Future<PermissionStatus> checkPermission() => _readCameraPermission();

  @override
  bool get isReady => _controller?.value.isInitialized ?? false;

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    // CameraPreview sudah menangani rotasi tekstur Android. Ukuran sensor
    // dilaporkan dalam orientasi landscape, sedangkan app dikunci portrait,
    // jadi rasio dibalik agar preview tidak stretched.
    final sensorAspectRatio = controller.value.aspectRatio;
    final portraitAspectRatio =
        sensorAspectRatio > 1 ? 1 / sensorAspectRatio : sensorAspectRatio;

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 1000 * portraitAspectRatio,
        height: 1000,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Future<void> initialize() async {
    // Reuse live camera after returning from result screen; reinitializing
    // needlessly adds permission, device discovery, and sensor startup delay.
    if (isReady) return;

    await dispose();

    // Minta izin lebih dulu lewat permission_handler supaya status "jangan
    // tanya lagi" bisa dibedakan. CameraX akan memakai izin yang sama tanpa
    // memunculkan dialog kedua.
    final status = await _requestCameraPermission();
    if (status.isPermanentlyDenied || status.isRestricted) {
      throw const ScannerFailure(ScannerErrorCode.permissionPermanentlyDenied);
    }
    if (!status.isGranted && !status.isLimited) {
      throw const ScannerFailure(ScannerErrorCode.permissionDenied);
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const ScannerFailure(ScannerErrorCode.cameraUnavailable);
      }

      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        resolutionPreset,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
    } on ScannerFailure {
      await dispose();
      rethrow;
    } on CameraException catch (error) {
      await dispose();
      throw _mapCameraException(error);
    }
  }

  @override
  Future<void> setTorch(bool enabled) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const ScannerFailure(ScannerErrorCode.torchUnavailable);
    }

    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
    } on CameraException catch (error) {
      throw ScannerFailure(
        ScannerErrorCode.torchUnavailable,
        error.description,
      );
    }
  }

  @override
  Future<XFile> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const ScannerFailure(ScannerErrorCode.captureFailed);
    }

    try {
      return await controller.takePicture();
    } on CameraException catch (error) {
      throw _mapCameraException(error);
    }
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    try {
      await controller.dispose();
    } catch (_) {
      // Kamera bisa saja sudah dilepas oleh OS (mis. app di background).
    }
  }

  ScannerFailure _mapCameraException(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'cameraPermission':
        return ScannerFailure(
          ScannerErrorCode.permissionDenied,
          error.description,
        );
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return ScannerFailure(
          ScannerErrorCode.permissionPermanentlyDenied,
          error.description,
        );
      case 'CameraNotFound':
      case 'cameraNotFound':
      case 'NoCameraAvailable':
        return ScannerFailure(
          ScannerErrorCode.cameraUnavailable,
          error.description,
        );
      default:
        return ScannerFailure(
          ScannerErrorCode.captureFailed,
          error.description,
        );
    }
  }
}
