import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo/demo_data.dart';
import '../models/banner_model.dart';
import '../models/blog_model.dart';
import '../models/campaign_model.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository();
});

class HomeRepository {
  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));

  Future<List<AppBanner>> fetchBanners() async {
    await _demoDelay();
    return DemoData.banners;
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
    await _demoDelay();
    return DemoData.campaigns;
  }
}
