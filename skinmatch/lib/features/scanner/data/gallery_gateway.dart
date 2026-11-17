import 'package:image_picker/image_picker.dart';

import 'scanner_models.dart';

/// Sumber gambar dari galeri; dipisah agar bisa difake pada widget test.
abstract interface class GalleryGateway {
  /// Mengembalikan `null` jika pengguna membatalkan pemilihan.
  Future<XFile?> pickImage();
}

class ImagePickerGallery implements GalleryGateway {
  ImagePickerGallery({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        // Metadata lengkap tidak diperlukan dan bisa memicu izin foto di iOS.
        requestFullMetadata: false,
      );
    } catch (error) {
      throw ScannerFailure(ScannerErrorCode.unknown, '$error');
    }
  }
}
