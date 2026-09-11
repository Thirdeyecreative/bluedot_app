import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/services/api_client.dart';
import '../models/banner_model.dart';
import '../models/blog_model.dart';
import '../models/campaign_model.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

class HomeRepository {
  final ApiClient _api;
  HomeRepository(this._api);

  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));

  static const _defaultScanTagline = 'Every Scan Plants a Story.';

  Future<String> fetchScanTagline() async {
    try {
      final json = await _api.get(ApiConfig.homeScreenConfig) as Map<String, dynamic>;
      return json['scan_tagline'] as String? ?? _defaultScanTagline;
    } catch (_) {
      return _defaultScanTagline;
    }
  }

  Future<List<AppBanner>> fetchBanners() async {
    try {
      // Public endpoint (no auth) — banners are home-screen content. The
      // response is a JSON array shaped to AppBanner's fromJson contract.
      final data = await _api.get(ApiConfig.appBanners, requireAuth: false);
      final banners = AppBanner.parseList(data as List<dynamic>);
      // Fall back to demo content if the server has no published banners yet,
      // so the carousel still has something to show in dev/staging.
      if (banners.isNotEmpty) return banners;
    } catch (_) {
      // Network/parse failure -> fall back to demo data; never break home.
    }
    final demo = List<AppBanner>.of(DemoData.banners);
    AppBanner.sortInPlace(demo);
    return demo;
  }

  Future<List<BlogPost>> fetchBlogs({int page = 1, int limit = 10}) async {
    await _demoDelay();
    return DemoData.blogs;
  }

  Future<BlogPost> fetchBlogBySlug(String slug) async {
    await _demoDelay();
    return DemoData.blogs.firstWhere(
      (blog) => blog.slug == slug,
      orElse: () => DemoData.blogs.first,
    );
  }

  Future<List<Campaign>> fetchCampaigns() async {
    try {
      final data = await _api.get(ApiConfig.campaigns, requireAuth: false);
      if (data is List) {
        return data.map((json) => Campaign.fromJson(json)).toList();
      }
    } catch (e, stackTrace) {
      print('Error fetching campaigns: $e\n$stackTrace');
      // Fallback to demo data on error
    }
    return DemoData.campaigns;
  }
}
