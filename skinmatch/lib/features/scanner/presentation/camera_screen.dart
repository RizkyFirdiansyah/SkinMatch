import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../application/scanner_controller.dart';
import '../data/scanner_models.dart';
import '../providers/scanner_providers.dart';
import '../widgets/camera_overlay_painter.dart';

// scan — Pemindai Komposisi (INCI)
// Preview kamera langsung + capture, galeri, dan torch.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  late final ScannerController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _controller = ScannerController(
      camera: ref.read(cameraGatewayProvider),
      compressor: ref.read(imageCompressorProvider),
      gallery: ref.read(galleryGatewayProvider),
      analysis: ref.read(analysisServiceProvider),
      openSettings: ref.read(openAppSettingsProvider),
    )..addListener(_handleControllerChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Hormati pengaturan "remove animations" agar test & aksesibilitas aman.
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _pulseController.stop();
      _pulseController.value = 1;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleCapture() async {
    final outcome = await _controller.capture();
    await _handleOutcome(outcome);
  }

  Future<void> _handleGallery() async {
    final outcome = await _controller.pickFromGallery();
    await _handleOutcome(outcome);
  }

  Future<void> _handleOutcome(ScanOutcome? outcome) async {
    if (!mounted || outcome == null) return;

    if (!outcome.isSuccess) {
      _showMessage(outcome.failure?.userMessage ?? 'Terjadi kesalahan.');
      return;
    }

    await _openResult(outcome.scanId!);
  }

  Future<void> _openResult(String scanId) async {
    // Keep camera initialized while result route is open. Scanner preview
    // remains mounted, and next scan avoids a full camera startup cycle.
    await context.push(AppRoutes.analysisPath(scanId));
  }

  Future<void> _handleTorch() async {
    final failure = await _controller.toggleTorch();
    if (failure != null && mounted) {
      _showMessage(failure.userMessage);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final stage = _controller.stage;

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: SkinMatchAppBar(
        title: 'Pindai Komposisi',
        actions: [
          IconButton(
            tooltip: 'Tips memindai',
            icon: const Icon(LucideIcons.info, size: 20),
            onPressed: () => _showMessage(
              'Pastikan pencahayaan cukup dan teks kemasan tidak terlipat.',
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            children: [
              Expanded(child: _buildScannerSurface(stage)),
              const SizedBox(height: 12),
              _buildGuidance(),
              const SizedBox(height: 16),
              _buildControls(stage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerSurface(ScannerStage stage) {
    switch (stage) {
      case ScannerStage.booting:
        return _buildPreviewCard(
          child: const _PreviewPlaceholder(message: 'Menyiapkan kamera...'),
        );
      case ScannerStage.permissionDenied:
        return _buildStateCard(
          icon: LucideIcons.camera_off,
          title: 'Izin kamera diperlukan',
          message:
              'Izinkan akses kamera untuk memindai label. Anda tetap bisa memilih foto dari galeri.',
          primaryLabel: 'Coba Lagi',
          onPrimary: _controller.start,
          secondaryLabel: 'Galeri',
          onSecondary: _handleGallery,
        );
      case ScannerStage.permissionPermanentlyDenied:
        return _buildStateCard(
          icon: LucideIcons.camera_off,
          title: 'Izin kamera ditolak',
          message:
              'Aktifkan izin kamera melalui Pengaturan aplikasi, atau pilih foto dari galeri.',
          primaryLabel: 'Buka Pengaturan',
          onPrimary: _controller.openSettings,
          secondaryLabel: 'Galeri',
          onSecondary: _handleGallery,
        );
      case ScannerStage.cameraUnavailable:
        return _buildStateCard(
          icon: LucideIcons.camera_off,
          title: 'Kamera tidak tersedia',
          message:
              'Perangkat ini tidak dapat membuka kamera. Silakan pilih foto dari galeri.',
          secondaryLabel: 'Galeri',
          onSecondary: _handleGallery,
        );
      case ScannerStage.failure:
        return _buildStateCard(
          icon: LucideIcons.triangle_alert,
          title: 'Kamera gagal dibuka',
          message: _controller.failure?.userMessage ??
              'Terjadi kesalahan saat membuka kamera.',
          primaryLabel: 'Coba Lagi',
          onPrimary: _controller.start,
          secondaryLabel: 'Galeri',
          onSecondary: _handleGallery,
        );
      case ScannerStage.ready:
      case ScannerStage.capturing:
      case ScannerStage.compressing:
      case ScannerStage.analyzing:
        return _buildPreviewCard(child: _buildLivePreview(stage));
    }
  }

  Widget _buildPreviewCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }

  Widget _buildLivePreview(ScannerStage stage) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.primaryDark),
        Positioned.fill(child: _controller.buildPreview()),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: const CameraOverlayPainter()),
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.scan_line,
                        size: 14,
                        color: AppColors.primarySage,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Arahkan kamera ke daftar komposisi (INCI)',
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TorchButton(
                key: const Key('scanner-torch-button'),
                active: _controller.torchOn,
                enabled: stage == ScannerStage.ready && !_controller.isBusy,
                onTap: _handleTorch,
              ),
            ],
          ),
        ),
        if (stage != ScannerStage.ready)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.62),
              child: Center(child: _buildBusyIndicator(stage)),
            ),
          ),
      ],
    );
  }

  Widget _buildBusyIndicator(ScannerStage stage) {
    final (title, subtitle) = switch (stage) {
      ScannerStage.capturing => (
          'Mengambil foto...',
          'Tahan perangkat tetap stabil',
        ),
      ScannerStage.compressing => (
          'Mengoptimalkan gambar...',
          'Menyiapkan foto untuk analisis',
        ),
      ScannerStage.analyzing => (
          'Menganalisis INCI List...',
          'AI Vision OCR sedang bekerja',
        ),
      _ => ('Memproses...', 'Mohon tunggu'),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: AppColors.primarySage,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: AppTypography.labelLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    String? primaryLabel,
    Future<void> Function()? onPrimary,
    String? secondaryLabel,
    Future<void> Function()? onSecondary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minContentHeight = (constraints.maxHeight - 48)
              .clamp(0.0, double.infinity)
              .toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minContentHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.backgroundClean,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (primaryLabel != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onPrimary,
                        child: Text(primaryLabel),
                      ),
                    ),
                  ],
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        child: Text(secondaryLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuidance() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.statusSafeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primarySage.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.sun, size: 16, color: AppColors.primarySage),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pastikan pencahayaan cukup dan teks kemasan tidak terlipat agar OCR maksimal.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ScannerStage stage) {
    final busy = _controller.isBusy;
    final ready = stage == ScannerStage.ready && !busy;
    final processing = stage == ScannerStage.capturing ||
        stage == ScannerStage.compressing ||
        stage == ScannerStage.analyzing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SideActionButton(
          key: const Key('scanner-gallery-button'),
          icon: LucideIcons.image,
          label: 'Galeri',
          onTap: busy ? null : _handleGallery,
        ),
        _CaptureButton(
          key: const Key('scanner-capture-button'),
          enabled: ready,
          busy: processing,
          pulse: _pulseAnimation,
          onTap: _handleCapture,
        ),
        _SideActionButton(
          key: const Key('scanner-manual-button'),
          icon: LucideIcons.keyboard,
          label: 'Ketik Manual',
          onTap: () =>
              _showMessage('Input komposisi manual segera hadir.'),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primaryDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primarySage,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({
    super.key,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      label: active ? 'Matikan flash' : 'Nyalakan flash',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.primarySage
                  : Colors.black.withValues(alpha: 0.5),
            ),
            child: Icon(
              active ? LucideIcons.zap : LucideIcons.zap_off,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    super.key,
    required this.enabled,
    required this.busy,
    required this.pulse,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final button = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled
            ? AppColors.primarySage
            : AppColors.primarySage.withValues(alpha: 0.4),
        boxShadow: enabled ? AppColors.buttonGlow : null,
      ),
      child: Icon(
        busy ? LucideIcons.loader : LucideIcons.scan_line,
        color: Colors.white,
        size: 28,
      ),
    );

    return SizedBox(
      width: 84,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            enabled: enabled,
            label: 'Pindai INCI',
            child: GestureDetector(
              onTap: enabled ? onTap : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primarySage.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                  ),
                  if (disableAnimations)
                    button
                  else
                    ScaleTransition(scale: pulse, child: button),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pindai INCI',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  const _SideActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.cardShadow,
                ),
                child: Icon(icon, size: 22, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
