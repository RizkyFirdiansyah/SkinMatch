import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skinmatch/features/scanner/data/scanner_models.dart';
import 'package:skinmatch/features/scanner/presentation/camera_screen.dart';
import 'package:skinmatch/features/scanner/providers/scanner_providers.dart';

import '../../helpers/scanner_fakes.dart';

class _Setup {
  _Setup({
    FakeCameraGateway? camera,
    FakeImageCompressor? compressor,
    FakeGalleryGateway? gallery,
    FakeAnalysisService? analysis,
    FakeSettingsLauncher? settings,
  })  : camera = camera ?? FakeCameraGateway(),
        compressor = compressor ?? FakeImageCompressor(),
        gallery = gallery ?? FakeGalleryGateway(),
        analysis = analysis ?? FakeAnalysisService(),
        settings = settings ?? FakeSettingsLauncher();

  final FakeCameraGateway camera;
  final FakeImageCompressor compressor;
  final FakeGalleryGateway gallery;
  final FakeAnalysisService analysis;
  final FakeSettingsLauncher settings;

  late final GoRouter router = GoRouter(
    initialLocation: '/scan',
    routes: [
      GoRoute(
        path: '/scan',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/analysis/:id',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('RESULT:${state.pathParameters['id']}'),
          ),
        ),
      ),
    ],
  );

  List<Override> get overrides => [
        cameraGatewayProvider.overrideWithValue(camera),
        imageCompressorProvider.overrideWithValue(compressor),
        galleryGatewayProvider.overrideWithValue(gallery),
        analysisServiceProvider.overrideWithValue(analysis),
        openAppSettingsProvider.overrideWithValue(settings.call),
      ];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            );
          },
        ),
      ),
    );
    // Biarkan post-frame callback start() berjalan.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Menunggu alur async + transisi route tanpa `pumpAndSettle`, karena spinner
/// di layar kamera tetap ter-mount di bawah halaman hasil.
Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() {
    // Jangan coba mengunduh font saat test berjalan.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('menampilkan panduan dan galeri saat izin kamera ditolak',
      (tester) async {
    final setup = _Setup(
      camera: FakeCameraGateway(
        initializeFailure: const ScannerFailure(
          ScannerErrorCode.permissionDenied,
        ),
      ),
    );
    await setup.pump(tester);

    expect(find.text('Izin kamera diperlukan'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scanner-gallery-button')));
    await tester.pumpAndSettle();

    expect(setup.gallery.pickCalls, 1);
    // Galeri dibatalkan (nextPath null) → tetap di state semula.
    expect(find.text('Izin kamera diperlukan'), findsOneWidget);
  });

  testWidgets('izin ditolak permanen membuka pengaturan aplikasi',
      (tester) async {
    final setup = _Setup(
      camera: FakeCameraGateway(
        initializeFailure: const ScannerFailure(
          ScannerErrorCode.permissionPermanentlyDenied,
        ),
      ),
    );
    await setup.pump(tester);

    expect(find.text('Buka Pengaturan'), findsOneWidget);

    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pump();

    expect(setup.settings.calls, 1);
  });

  testWidgets('menampilkan pesan saat kamera tidak tersedia', (tester) async {
    final setup = _Setup(
      camera: FakeCameraGateway(
        initializeFailure: const ScannerFailure(
          ScannerErrorCode.cameraUnavailable,
        ),
      ),
    );
    await setup.pump(tester);

    expect(find.text('Kamera tidak tersedia'), findsOneWidget);
    expect(find.text('Galeri'), findsWidgets);
  });

  testWidgets('preview kamera tampil saat siap', (tester) async {
    final setup = _Setup();
    await setup.pump(tester);

    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
    expect(find.text('Pindai INCI'), findsOneWidget);
    expect(setup.camera.initializeCalls, 1);
  });

  testWidgets('capture memproses gambar lalu membuka halaman hasil',
      (tester) async {
    final setup = _Setup();
    await setup.pump(tester);

    await tester.tap(find.byKey(const Key('scanner-capture-button')));
    await _pumpNavigation(tester);

    expect(setup.camera.captureCalls, 1);
    expect(setup.compressor.prepareCalls, 1);
    expect(setup.analysis.submitCalls, 1);
    expect(find.text('RESULT:test-scan-001'), findsOneWidget);
  });

  testWidgets('tap capture dua kali tidak memicu dua pengambilan foto',
      (tester) async {
    final setup = _Setup();
    final gate = Completer<void>();
    setup.analysis.gate = gate;
    await setup.pump(tester);

    await tester.tap(find.byKey(const Key('scanner-capture-button')));
    await tester.tap(find.byKey(const Key('scanner-capture-button')));
    await tester.pump();

    expect(setup.camera.captureCalls, 1);

    gate.complete();
    await _pumpNavigation(tester);

    expect(find.text('RESULT:test-scan-001'), findsOneWidget);
  });

  testWidgets('memilih gambar galeri memproses dan membuka hasil',
      (tester) async {
    final setup = _Setup();
    setup.gallery.nextPath = 'gallery.jpg';
    await setup.pump(tester);

    await tester.tap(find.byKey(const Key('scanner-gallery-button')));
    await _pumpNavigation(tester);

    expect(setup.gallery.pickCalls, 1);
    expect(setup.analysis.submitCalls, 1);
    expect(setup.analysis.lastScan?.source, ScanSource.gallery);
    expect(find.text('RESULT:test-scan-001'), findsOneWidget);
  });

  testWidgets('galeri yang dibatalkan tetap di layar pemindai', (tester) async {
    final setup = _Setup();
    await setup.pump(tester);

    await tester.tap(find.byKey(const Key('scanner-gallery-button')));
    await tester.pumpAndSettle();

    expect(setup.gallery.pickCalls, 1);
    expect(setup.analysis.submitCalls, 0);
    expect(find.text('RESULT:test-scan-001'), findsNothing);
    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
  });

  testWidgets('kegagalan torch menampilkan snackbar dan tidak mengubah ikon',
      (tester) async {
    final setup = _Setup();
    setup.camera.torchFailure = const ScannerFailure(
      ScannerErrorCode.torchUnavailable,
    );
    await setup.pump(tester);

    expect(find.byIcon(LucideIcons.zap_off), findsOneWidget);

    await tester.tap(find.byKey(const Key('scanner-torch-button')));
    await tester.pumpAndSettle();

    expect(find.text('Flash tidak tersedia di perangkat ini.'), findsOneWidget);
    expect(find.byIcon(LucideIcons.zap_off), findsOneWidget);
    expect(find.byIcon(LucideIcons.zap), findsNothing);

    // Selesaikan timer auto-dismiss SnackBar agar tidak ada timer pending.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('tidak overflow pada layar kecil 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final setup = _Setup();
    await setup.pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
  });
}
