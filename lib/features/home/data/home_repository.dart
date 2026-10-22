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
  final List<BlogPost> blogs;

  HomeFeedData({
    required this.tagline,
    required this.banners,
    required this.campaigns,
    required this.events,
    this.blogs = const [],
  });
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

class HomeRepository {
  final ApiClient _api;
  HomeRepository(this._api);

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

      // Blogs: show ONLY real DB data
      final blogsList = json['blogs'] as List<dynamic>? ?? [];
      final blogs = blogsList.map((b) => BlogPost.fromJson(b as Map<String, dynamic>)).toList();

      return HomeFeedData(
        tagline: json['tagline'] as String? ?? 'Every Scan Plants a Story.',
        banners: banners,
        campaigns: campaigns,
        events: events,
        blogs: blogs,
      );
    } catch (e, stack) {
      print('Error fetching home feed: $e\n$stack');
      // On error: show demo banners but empty events/campaigns/blogs
      // so the user never sees stale hardcoded content
      final demoBanners = List<AppBanner>.of(DemoData.banners);
      AppBanner.sortInPlace(demoBanners);
      return HomeFeedData(
        tagline: 'Every Scan Plants a Story.',
        banners: demoBanners,
        campaigns: [],
        events: [],
        blogs: [],
      );
    }
  }

  Future<List<BlogPost>> fetchBlogs({int page = 1, int limit = 10, String? search}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final data = await _api.get(
        ApiConfig.appBlogs,
        requireAuth: false,
        query: queryParams,
      );

      if (data is List) {
        return data.map((j) => BlogPost.fromJson(j as Map<String, dynamic>)).toList();
      } else if (data is Map<String, dynamic>) {
        final items = data['items'] as List<dynamic>? ?? data['blogs'] as List<dynamic>? ?? [];
        return items.map((j) => BlogPost.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e, stack) {
      print('Error fetching blogs: $e\n$stack');
      // On local/dev fallback when backend is unreachable
      if (!ApiConfig.isProduction) {
        return DemoData.blogs;
      }
    }
    return [];
  }

  Future<BlogPost> fetchBlogBySlug(String slug) async {
    try {
      final data = await _api.get(
        ApiConfig.appBlogDetail(slug),
        requireAuth: false,
      );
      if (data is Map<String, dynamic>) {
        return BlogPost.fromJson(data);
      }
    } catch (e, stack) {
      print('Error fetching blog ($slug): $e\n$stack');
      // If offline/demo fallback is available in non-prod
      if (!ApiConfig.isProduction) {
        final match = DemoData.blogs.where((b) => b.slug == slug || b.id == slug);
        if (match.isNotEmpty) return match.first;
      }
      rethrow;
    }
    throw Exception('Blog not found');
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
