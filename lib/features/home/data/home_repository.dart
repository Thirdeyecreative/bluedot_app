import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';
import '../models/banner_model.dart';
import '../models/blog_model.dart';
import '../models/campaign_model.dart';
import '../models/eco_vitals_model.dart';
import '../../action_hub/models/event_model.dart';

class HomeFeedData {
  final AppBanner? hero;
  final List<AppBanner> banners;
  final List<Campaign> campaigns;
  final List<PlantationEvent> events;
  final List<BlogPost> blogs;

  HomeFeedData({
    this.hero,
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
    final json =
        await _api.get(ApiConfig.homeFeed, requireAuth: false)
            as Map<String, dynamic>;
    final hero = json['hero'];
    return HomeFeedData(
      hero: hero == null
          ? null
          : AppBanner.fromJson(hero as Map<String, dynamic>),
      banners: AppBanner.parseList(json['banners'] as List<dynamic>? ?? []),
      campaigns: (json['campaigns'] as List<dynamic>? ?? [])
          .map((item) => Campaign.fromJson(item))
          .toList(),
      events: (json['events'] as List<dynamic>? ?? [])
          .map((item) => PlantationEvent.fromJson(item))
          .toList(),
      blogs: (json['blogs'] as List<dynamic>? ?? [])
          .map((item) => BlogPost.fromJson(item))
          .toList(),
    );
  }

  Future<List<BlogPost>> fetchBlogs({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
      final data = await _api.get(
        ApiConfig.appBlogs,
        requireAuth: false,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final items = data is List
        ? data
        : (data as Map<String, dynamic>)['items'] ?? data['blogs'];
    return (items as List<dynamic>)
        .map((item) => BlogPost.fromJson(item))
        .toList();
  }

  Future<BlogPost> fetchBlogBySlug(String slug) async {
      final data = await _api.get(
        ApiConfig.appBlogDetail(slug),
        requireAuth: false,
    );
    return BlogPost.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Campaign>> fetchCampaigns() async {
    final data =
        await _api.get(ApiConfig.campaigns, requireAuth: false)
            as List<dynamic>;
    return data.map((item) => Campaign.fromJson(item)).toList();
  }

  /// Fetches live eco vitals (AQI, UV, Climate & Canopy metrics) from BlueDot backend API.
  /// Backend serves this from Redis with a 45-minute TTL per 10km grid cell.
  Future<CityAqiData> fetchEcoVitals({
    double? latitude,
    double? longitude,
    String? city,
  }) async {
    final json = await _api.get(
      ApiConfig.ecoVitals,
      requireAuth: false,
      query: {
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    ) as Map<String, dynamic>;
    return CityAqiData.fromJson(json);
  }
}
