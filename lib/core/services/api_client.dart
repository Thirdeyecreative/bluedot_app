import 'dart:async';
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

  static const Duration _timeout = Duration(seconds: 30);

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
    final res = await _guard(() async => http.get(uri, headers: await _headers(requireAuth: requireAuth)));
    return _handle(res);
  }

  Future<dynamic> post(
    String url, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final res = await _guard(() async => http.post(
          Uri.parse(url),
          headers: await _headers(requireAuth: requireAuth),
          body: body != null ? jsonEncode(body) : null,
        ));
    return _handle(res);
  }

  Future<dynamic> delete(
    String url, {
    bool requireAuth = true,
  }) async {
    final res = await _guard(() async => http.delete(
          Uri.parse(url),
          headers: await _headers(requireAuth: requireAuth),
        ));
    return _handle(res);
  }

  Future<dynamic> multipartPost(
    String url, {
    required Map<String, String> fields,
    List<File> files = const [],
    String fileField = 'images',
    bool requireAuth = true,
  }) async {
    final res = await _guard(() async {
      final token = requireAuth ? await _storage.getToken() : null;
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields.addAll(fields);
      // All files are sent under the same repeated field name, which FastAPI
      // collects into a `List[UploadFile]`.
      for (final file in files) {
        request.files.add(await http.MultipartFile.fromPath(
          fileField,
          file.path,
          // MultipartFile defaults to application/octet-stream, which the API
          // rejects — label it with the real image MIME type from its extension.
          contentType: _imageMediaType(file.path),
        ));
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    return _handle(res);
  }

  /// Runs a request, applying a timeout and converting connectivity failures
  /// into a friendly [ApiException] so callers never see raw socket errors.
  Future<http.Response> _guard(Future<http.Response> Function() run) async {
    try {
      return await run().timeout(_timeout);
    } on SocketException {
      throw const ApiException(
        message: 'No internet connection. Please check your network and try again.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
        statusCode: 0,
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Could not reach the server. Please try again in a moment.',
        statusCode: 0,
      );
    } on HandshakeException {
      throw const ApiException(
        message: 'A secure connection could not be established. Please try again.',
        statusCode: 0,
      );
    }
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
    throw ApiException(
      message: _extractMessage(res.body, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  /// Pulls a human-readable message out of an error body. Handles FastAPI's
  /// `{"detail": "..."}`, its `{"detail": [{"msg": ...}]}` validation shape,
  /// and a legacy `{"message": ...}`, falling back to a status-based default.
  String _extractMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            return (first['msg'] as String).trim();
          }
        }
      }
    } catch (_) {
      // body wasn't JSON — fall through to the default
    }
    return _defaultMessage(statusCode);
  }

  String _defaultMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Something about that request wasn\'t right. Please check and try again.';
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You don\'t have permission to do that.';
      case 404:
        return 'We couldn\'t find what you were looking for.';
      case 409:
        return 'That conflicts with something that already exists.';
      case 413:
        return 'That file is too large. Please choose a smaller one.';
      case 415:
        return 'That file type isn\'t supported.';
      case 429:
        return 'You\'re doing that a bit too quickly. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
        return 'Our servers are having a moment. Please try again shortly.';
      default:
        return 'Something went wrong (error $statusCode). Please try again.';
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException({required this.message, required this.statusCode});

  /// True when the failure was connectivity/timeout rather than a server reply.
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => message;
}
