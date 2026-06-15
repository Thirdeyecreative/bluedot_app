import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(storageServiceProvider));
});

class ApiClient {
  final StorageService _storage;

  ApiClient(this._storage);

  Future<Map<String, String>> _headers({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requireAuth) {
      final token = await _storage.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(
    String url, {
    bool requireAuth = true,
    Map<String, String>? query,
  }) async {
    Uri uri = Uri.parse(url);
    if (query != null) uri = uri.replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers(requireAuth: requireAuth));
    return _handle(res);
  }

  Future<dynamic> post(
    String url, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final res = await http.post(
      Uri.parse(url),
      headers: await _headers(requireAuth: requireAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  Future<dynamic> multipartPost(
    String url, {
    required Map<String, String> fields,
    File? imageFile,
    String fileField = 'image',
    bool requireAuth = true,
  }) async {
    final token = requireAuth ? await _storage.getToken() : null;
    final request = http.MultipartRequest('POST', Uri.parse(url));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        fileField,
        imageFile.path,
        // MultipartFile defaults to application/octet-stream, which the API
        // rejects — label it with the real image MIME type from its extension.
        contentType: _imageMediaType(imageFile.path),
      ));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  MediaType _imageMediaType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    Map<String, dynamic>? error;
    try {
      error = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    throw ApiException(
      message: error?['message'] as String? ?? 'Request failed (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException({required this.message, required this.statusCode});
  @override
  String toString() => message;
}
