/// Kumpulan aturan pemeriksa isian form.
class Validators {
  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  static String? emailOrPhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email atau No. Handphone wajib diisi';

    if (v.contains('@')) {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(v)) return 'Format email tidak valid';
    } else {
      final phoneRegex = RegExp(r'^(\+62|62|0)8[0-9]{8,11}$');
      if (!phoneRegex.hasMatch(v)) return 'Format No. Handphone tidak valid';
    }
    return null;
  }

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Kata sandi wajib diisi';
    if (v.length < 8) return 'Minimal 8 karakter';
    return null;
  }
}