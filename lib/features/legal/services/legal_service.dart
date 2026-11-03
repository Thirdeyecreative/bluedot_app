import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';

class LegalDocumentModel {
  final String slug;
  final String version;
  final String title;
  final String contentMarkdown;
  final String effectiveDate;

  const LegalDocumentModel({
    required this.slug,
    required this.version,
    required this.title,
    required this.contentMarkdown,
    required this.effectiveDate,
  });

  factory LegalDocumentModel.fromJson(Map<String, dynamic> json) {
    return LegalDocumentModel(
      slug: json['slug'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      title: json['title'] as String? ?? '',
      contentMarkdown: json['content_markdown'] as String? ?? '',
      effectiveDate: json['effective_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'version': version,
        'title': title,
        'content_markdown': contentMarkdown,
        'effective_date': effectiveDate,
      };
}

class PendingConsentModel {
  final String slug;
  final String version;
  final String title;
  final String? changeSummary;

  const PendingConsentModel({
    required this.slug,
    required this.version,
    required this.title,
    this.changeSummary,
  });

  factory PendingConsentModel.fromJson(Map<String, dynamic> json) {
    return PendingConsentModel(
      slug: json['slug'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      title: json['title'] as String? ?? '',
      changeSummary: json['change_summary'] as String?,
    );
  }
}

class ConsentStatusResult {
  final bool requiresConsent;
  final List<PendingConsentModel> pendingDocuments;

  const ConsentStatusResult({
    required this.requiresConsent,
    this.pendingDocuments = const [],
  });
}

final legalServiceProvider = Provider<LegalService>((ref) {
  return LegalService(ref.watch(apiClientProvider));
});

class LegalService {
  final ApiClient _api;

  LegalService(this._api);

  static const String _cachePrefix = 'bluedot_legal_cache_';

  /// Stale-While-Revalidate: Returns cached document immediately if present,
  /// then fetches and caches the fresh copy from backend.
  Future<LegalDocumentModel?> getDocument(String slug, {Function(LegalDocumentModel)? onUpdated}) async {
    LegalDocumentModel? cachedDoc;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJsonStr = prefs.getString('$_cachePrefix$slug');
      if (cachedJsonStr != null) {
        cachedDoc = LegalDocumentModel.fromJson(jsonDecode(cachedJsonStr));
      }
    } catch (e) {
      // Non-fatal cache read error
    }

    // Silent background fetch
    _fetchAndCache(slug).then((freshDoc) {
      if (freshDoc != null && onUpdated != null) {
        if (cachedDoc == null || cachedDoc.version != freshDoc.version || cachedDoc.contentMarkdown != freshDoc.contentMarkdown) {
          onUpdated(freshDoc);
        }
      }
    }).catchError((_) {});

    return cachedDoc ?? await _fetchAndCache(slug);
  }

  Future<LegalDocumentModel?> _fetchAndCache(String slug) async {
    try {
      final res = await _api.get(ApiConfig.legalDocument(slug), requireAuth: false);
      if (res is Map<String, dynamic>) {
        final doc = LegalDocumentModel.fromJson(res);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_cachePrefix$slug', jsonEncode(doc.toJson()));
        return doc;
      }
    } catch (e) {
      // Network failure / offline
    }
    return null;
  }

  /// Checks whether authenticated mobile user has pending legal documents requiring re-consent.
  Future<ConsentStatusResult> checkConsentStatus() async {
    try {
      final res = await _api.get(ApiConfig.consentStatus, requireAuth: true);
      if (res is Map<String, dynamic>) {
        final requires = res['requires_consent'] as bool? ?? false;
        final rawDocs = res['pending_documents'] as List<dynamic>? ?? [];
        final pending = rawDocs.map((d) => PendingConsentModel.fromJson(d as Map<String, dynamic>)).toList();
        return ConsentStatusResult(requiresConsent: requires, pendingDocuments: pending);
      }
    } catch (e) {
      // If offline or error, avoid blocking user
    }
    return const ConsentStatusResult(requiresConsent: false);
  }

  /// Submits affirmative consent for a specific version.
  Future<bool> recordConsent(String slug, String version) async {
    try {
      final res = await _api.post(
        ApiConfig.recordConsent,
        body: {'document_slug': slug, 'version': version},
        requireAuth: true,
      );
      if (res is Map<String, dynamic> && res['success'] == true) {
        return true;
      }
    } catch (e) {
      // Error recording consent
    }
    return false;
  }

  /// Submits an automated DPDP data export request.
  Future<bool> requestDataExport() async {
    try {
      final res = await _api.post(
        ApiConfig.privacyRequest,
        body: {'request_type': 'EXPORT'},
        requireAuth: true,
      );
      return res is Map<String, dynamic> && res['status'] != null;
    } catch (e) {
      return false;
    }
  }
}

