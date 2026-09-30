import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/services/api_client.dart';
import '../models/banner_model.dart';
import '../models/blog_model.dart';
import '../models/campaign_model.dart';
import '../../action_hub/models/event_model.dart';

class HomeFeedData {
  final String tagline;
  final List<AppBanner> banners;
  final List<Campaign> campaigns;
  final List<PlantationEvent> events;

  HomeFeedData({
    required this.tagline,
    required this.banners,
    required this.campaigns,
    required this.events,
  });
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

class HomeRepository {
  final ApiClient _api;
  HomeRepository(this._api);

  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));

  Future<HomeFeedData> fetchHomeFeed() async {
    try {
      final json = await _api.get(ApiConfig.homeFeed, requireAuth: false) as Map<String, dynamic>;
      
      // Banners: use DemoData only if no banners exist in DB (visual-only content)
      final banners = AppBanner.parseList(json['banners'] as List<dynamic>? ?? []);
      if (banners.isEmpty) {
        banners.addAll(DemoData.banners);
        AppBanner.sortInPlace(banners);
      }

      // Campaigns: show ONLY real DB data — no demo fallback
      final campaignsList = json['campaigns'] as List<dynamic>? ?? [];
      final campaigns = campaignsList.map((c) => Campaign.fromJson(c)).toList();

      // Events: show ONLY real DB data — no demo fallback
      final eventsList = json['events'] as List<dynamic>? ?? [];
      final events = eventsList.map((e) => PlantationEvent.fromJson(e)).toList();

      return HomeFeedData(
        tagline: json['tagline'] as String? ?? 'Every Scan Plants a Story.',
        banners: banners,
        campaigns: campaigns,
        events: events,
      );
    } catch (e, stack) {
      print('Error fetching home feed: $e\n$stack');
      // On error: show demo banners but empty events/campaigns
      // so the user never sees stale hardcoded content
      final demoBanners = List<AppBanner>.of(DemoData.banners);
      AppBanner.sortInPlace(demoBanners);
      return HomeFeedData(
        tagline: 'Every Scan Plants a Story.',
        banners: demoBanners,
        campaigns: [],
        events: [],
      );
    }
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
