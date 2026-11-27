import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skinmatch/features/scanner/data/analysis_service.dart';
import 'package:skinmatch/features/scanner/data/camera_gateway.dart';
import 'package:skinmatch/features/scanner/data/gallery_gateway.dart';
import 'package:skinmatch/features/scanner/data/image_compressor.dart';
import 'package:skinmatch/features/scanner/data/scanner_models.dart';

class FakeCameraGateway implements CameraGateway {
  FakeCameraGateway({this.initializeFailure});

  ScannerFailure? initializeFailure;
  ScannerFailure? torchFailure;
  PermissionStatus permissionStatus = PermissionStatus.granted;
  int checkPermissionCalls = 0;

  bool _initialized = false;
  bool torchEnabled = false;
  int initializeCalls = 0;
  int disposeCalls = 0;
  int captureCalls = 0;
  String capturePath = 'captured.jpg';

  @override
  bool get isReady => _initialized;

  /// Meniru kamera yang dilepas OS saat aplikasi di background.
  void simulateCameraLost() {
    _initialized = false;
  }

  @override
  Widget buildPreview() {
    return const ColoredBox(
      key: Key('fake-camera-preview'),
      color: Color(0xFF123456),
    );
  }

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final failure = initializeFailure;
    if (failure != null) throw failure;
    _initialized = true;
  }

  @override
  Future<PermissionStatus> checkPermission() async {
    checkPermissionCalls++;
    return permissionStatus;
  }

  @override
  Future<XFile> capture() async {
    captureCalls++;
    return XFile(capturePath);
  }

  @override
  Future<void> setTorch(bool enabled) async {
    final failure = torchFailure;
    if (failure != null) throw failure;
    torchEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _initialized = false;
    torchEnabled = false;
  }
}

class FakeImageCompressor implements ImageCompressor {
  FakeImageCompressor({this.failure});

  ScannerFailure? failure;
  int prepareCalls = 0;
  File? outputFile;

  @override
  Future<CapturedScan> prepare(File source, ScanSource scanSource) async {
    prepareCalls++;
    final failure = this.failure;
    if (failure != null) throw failure;

    return CapturedScan(
      file: outputFile ?? source,
      byteSize: 1024,
      source: scanSource,
    );
  }
}

class FakeGalleryGateway implements GalleryGateway {
  FakeGalleryGateway({this.nextPath});

  String? nextPath;
  ScannerFailure? failure;
  int pickCalls = 0;

  @override
  Future<XFile?> pickImage() async {
    pickCalls++;
    final failure = this.failure;
    if (failure != null) throw failure;

    final path = nextPath;
    return path == null ? null : XFile(path);
  }
}

class FakeAnalysisService implements AnalysisService {
  FakeAnalysisService({
    this.scanId = 'test-scan-001',
    this.failure,
  });

  String scanId;
  ScannerFailure? failure;
  Completer<void>? gate;
  int submitCalls = 0;
  CapturedScan? lastScan;

  @override
  Future<String> submit(CapturedScan scan) async {
    submitCalls++;
    lastScan = scan;
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return scanId;
  }
}

class FakeSettingsLauncher {
  int calls = 0;

  Future<bool> call() async {
    calls++;
    return true;
  }
}
