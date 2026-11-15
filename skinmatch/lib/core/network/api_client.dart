import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/models/skinmatch_models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

class ApiClient {
  ApiClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _tokenKey = 'skinmatch_access_token';
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get _defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8000',
      _ => 'http://localhost:8000',
    };
  }

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String baseUrl;

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');

  Future<String> _authToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Sesi berakhir. Silakan masuk kembali.', statusCode: 401);
    }
    return token;
  }

  Future<Map<String, String>> _headers({bool authenticated = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (authenticated) {
      headers['Authorization'] = 'Bearer ${await _authToken()}';
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'Respons server tidak valid (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Format respons server tidak dikenali.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded['detail'] ?? decoded['message'];
      final message = detail is String
          ? detail
          : detail is List && detail.isNotEmpty
          ? (detail.first is Map
                ? detail.first['msg']?.toString()
                : detail.first.toString())
          : null;
      throw ApiException(
        message ?? 'Permintaan gagal (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
  }) async {
    final headers = await _headers(authenticated: authenticated);
    if (body != null) headers['Content-Type'] = 'application/json';
    final request = http.Request(method, _uri(path))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _client.send(request).timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse(response);
    } on http.ClientException {
      throw const ApiException(
        'Koneksi ke server gagal. Pastikan backend sedang berjalan.',
      );
    } on TimeoutException {
      throw const ApiException('Server terlalu lama merespons. Coba lagi.');
    }
  }

  Map<String, dynamic> _responseData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Data pada respons server tidak ditemukan.');
    }
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    final data = _responseData(response);
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Server tidak mengembalikan token autentikasi.');
    }
    await _storage.write(key: _tokenKey, value: token);
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _request(
      'POST',
      '/api/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      },
    );
    final data = _responseData(response);
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Server tidak mengembalikan token autentikasi.');
    }
    await _storage.write(key: _tokenKey, value: token);
    return data;
  }

  Future<void> logout() => _storage.delete(key: _tokenKey);

  Future<bool> hasSession() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _request('GET', '/api/profile', authenticated: true);
    return _responseData(response);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String skinType,
    required String ageRange,
    required String biologicalSex,
  }) async {
    final response = await _request(
      'PUT',
      '/api/profile',
      authenticated: true,
      body: {
        'skin_type': skinType,
        'age_range': ageRange,
        'biological_sex': biologicalSex,
      },
    );
    return _responseData(response);
  }

  Future<Map<String, dynamic>> uploadScan(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      throw const ApiException('Ukuran gambar terlalu besar. Maksimal 2MB.');
    }

    final contentType = _imageContentType(image.name);
    final request = http.MultipartRequest('POST', _uri('/api/scans'))
      ..headers.addAll(await _headers(authenticated: true))
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.name,
          contentType: contentType,
        ),
      );
    try {
      final streamed = await _client.send(request).timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamed);
      return _responseData(_decodeResponse(response));
    } on http.ClientException {
      throw const ApiException(
        'Koneksi ke server gagal. Pastikan backend sedang berjalan.',
      );
    } on TimeoutException {
      throw const ApiException('Unggah gambar terlalu lama. Coba lagi.');
    }
  }

  MediaType _imageContentType(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => throw const ApiException(
        'Format gambar tidak didukung. Pilih JPG, PNG, atau WEBP.',
      ),
    };
  }

  Future<List<ProductHistoryItem>> getScanHistory() async {
    final response = await _request('GET', '/api/scans', authenticated: true);
    final scans = _responseData(response)['scans'];
    if (scans is! List) {
      throw const ApiException('Daftar riwayat dari server tidak valid.');
    }
    return scans.map((scan) {
      if (scan is! Map<String, dynamic>) {
        throw const ApiException('Data riwayat dari server tidak valid.');
      }
      return _historyItem(scan);
    }).toList();
  }

  ProductHistoryItem _historyItem(Map<String, dynamic> scan) {
    final id = scan['scan_id']?.toString();
    if (id == null) {
      throw const ApiException('ID scan tidak ditemukan pada riwayat.');
    }
    final result = scan['result']?.toString() ?? 'Tidak diketahui';
    final score = _score(scan['confidence'], result);
    final timestamp = scan['timestamp']?.toString() ?? '';
    final resultModel = ScanAnalysisResult(
      scanId: id,
      userId: '',
      timestamp: _formatTimestamp(timestamp),
      brand: scan['brand']?.toString() ?? 'SkinMatch',
      productName: scan['product_name']?.toString() ?? 'Hasil pindai #$id',
      imageUrl: _absoluteUrl(scan['thumbnail_url']?.toString()),
      matchScore: score,
      safetyStatus: ScanAnalysisResult.statusFromScore(score),
      allergyPotential: _allergyPotential(score),
      comedogenicScale: 'Belum tersedia',
      formulaPh: 'Belum tersedia',
      routineRecommendation: result,
      ingredients: const [],
    );
    return ProductHistoryItem(
      historyId: id,
      scanResult: resultModel,
      trialStatus: TrialStatus.unreviewed,
      aiFeedbackApplied: false,
    );
  }

  Future<ScanAnalysisResult> getScanDetail(String scanId) async {
    final response = await _request(
      'GET',
      '/api/scans/$scanId',
      authenticated: true,
    );
    final data = _responseData(response);
    final rawClassification = data['classification'];
    if (rawClassification is! Map<String, dynamic>) {
      throw const ApiException('Data klasifikasi pada hasil scan tidak valid.');
    }
    final classification = rawClassification;
    final ocr = _asMap(data['ocr_result']);
    final analysis = _asMap(classification['ingredients_analysis']);
    final ingredients = <IngredientItem>[];
    for (final category in IngredientSafetyCategory.values) {
      final key = switch (category) {
        IngredientSafetyCategory.hero => 'hero',
        IngredientSafetyCategory.safeCarrier => 'safe',
        IngredientSafetyCategory.warning => 'risky',
        IngredientSafetyCategory.irritant => 'irritants',
        IngredientSafetyCategory.unknown => 'unknown',
      };
      final items = analysis[key];
      if (items is! List) continue;
      for (final rawIngredient in items) {
        if (rawIngredient is! Map<String, dynamic>) continue;
        final name = rawIngredient['name']?.toString() ?? 'Bahan tidak dikenal';
        ingredients.add(
          IngredientItem(
            id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
            inciName: name,
            cleanName: name,
            category: category,
            comedogenicRating: 0,
            irritancyRating: 0,
            functionDescription:
                rawIngredient['function']?.toString() ??
                'Belum dievaluasi oleh model analisis.',
          ),
        );
      }
    }
    if (ingredients.isEmpty) {
      final rawText = ocr['raw_text']?.toString() ?? '';
      ingredients.addAll(
        rawText
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .map(
              (name) => IngredientItem(
                id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
                inciName: name,
                cleanName: name,
                category: IngredientSafetyCategory.unknown,
                comedogenicRating: 0,
                irritancyRating: 0,
                functionDescription: 'Belum dievaluasi oleh model analisis.',
              ),
            ),
      );
    }

    final result = classification['result']?.toString() ?? 'Tidak diketahui';
    final score = _score(classification['confidence'], result);
    final warnings = classification['warnings'];
    return ScanAnalysisResult(
      scanId: data['scan_id']?.toString() ?? scanId,
      userId: data['user_id']?.toString() ?? '',
      timestamp: _formatTimestamp(data['timestamp']?.toString() ?? ''),
      brand: 'SkinMatch',
      productName: 'Hasil pindai #$scanId',
      imageUrl: _absoluteUrl(data['image_url']?.toString()),
      matchScore: score,
      safetyStatus: ScanAnalysisResult.statusFromScore(score),
      allergyPotential: _allergyPotential(score),
      comedogenicScale: 'Belum tersedia',
      formulaPh: 'Belum tersedia',
      keyWarning: warnings is List && warnings.isNotEmpty
          ? warnings.join(', ')
          : null,
      routineRecommendation:
          classification['recommendations']?.toString() ??
          classification['explanation']?.toString() ??
          'Hasil klasifikasi: $result.',
      ingredients: ingredients,
    );
  }

  int _score(dynamic confidence, String result) {
    if (confidence is! num) {
      throw const ApiException('Nilai kecocokan hasil scan tidak valid.');
    }
    final value = confidence.toDouble();
    final clamped = value.clamp(0, 100).toDouble();
    final notSuitable = result.toLowerCase().contains('tidak cocok');
    return (notSuitable ? 100 - clamped : clamped).round();
  }

  AllergyPotential _allergyPotential(int score) {
    if (score >= 90) return AllergyPotential.veryLow;
    if (score >= 80) return AllergyPotential.low;
    if (score >= 60) return AllergyPotential.medium;
    return AllergyPotential.high;
  }

  String _formatTimestamp(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.isEmpty ? 'Waktu tidak tersedia' : value;
    final local = date.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String? _absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri?.hasScheme == true) return path;
    return _uri(path.startsWith('/') ? path : '/$path').toString();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return const {};
  }

  void close() => _client.close();
}

final scanHistoryProvider = FutureProvider<List<ProductHistoryItem>>((ref) {
  return ref.watch(apiClientProvider).getScanHistory();
});

final scanDetailProvider =
    FutureProvider.family<ScanAnalysisResult, String>((ref, scanId) {
      return ref.watch(apiClientProvider).getScanDetail(scanId);
    });
