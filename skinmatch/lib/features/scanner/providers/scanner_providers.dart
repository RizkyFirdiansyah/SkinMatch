import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_client.dart';
import '../data/analysis_service.dart';
import '../data/camera_gateway.dart';
import '../data/gallery_gateway.dart';
import '../data/image_compressor.dart';

/// Dependency scanner. Semuanya dibuat per pemakaian (stateless), sehingga
/// widget test cukup meng-override provider ini dengan fake.
final cameraGatewayProvider = Provider<CameraGateway>(
  (ref) => DeviceCameraGateway(),
);

final imageCompressorProvider = Provider<ImageCompressor>(
  (ref) => NativeImageCompressor(),
);

final galleryGatewayProvider = Provider<GalleryGateway>(
  (ref) => ImagePickerGallery(),
);

final analysisServiceProvider = Provider<AnalysisService>(
  (ref) => ApiAnalysisService(ref.watch(apiClientProvider)),
);

final openAppSettingsProvider = Provider<Future<bool> Function()>(
  (ref) => openAppSettings,
);
