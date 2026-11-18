import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/home_repository.dart';
import '../data/notifications_repository.dart';
import '../models/blog_model.dart';
import '../models/campaign_model.dart';
import '../models/eco_vitals_model.dart';
import '../models/notification_model.dart';

export '../models/eco_vitals_model.dart';

final homeFeedProvider = FutureProvider<HomeFeedData>((ref) {
  return ref.watch(homeRepositoryProvider).fetchHomeFeed();
});

final blogsProvider = FutureProvider<List<BlogPost>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchBlogs();
});

final campaignsProvider = FutureProvider<List<Campaign>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchCampaigns();
});

final blogDetailProvider = FutureProvider.family<BlogPost, String>((ref, slug) {
  return ref.watch(homeRepositoryProvider).fetchBlogBySlug(slug);
});

class NotificationsState {
  final List<AppNotification> items;
  final int unreadCount;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String selectedCategory;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.total = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.selectedCategory = 'all',
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    int? total,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? selectedCategory,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

class NotificationsNotifier extends Notifier<NotificationsState> {
  static const int _pageSize = 20;

  @override
  NotificationsState build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const NotificationsState();
    }

    Future.microtask(() => _loadInitial(category: 'all'));
    return const NotificationsState(isLoading: true);
  }

  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  Future<void> _loadInitial({required String category}) async {
    state = state.copyWith(
      selectedCategory: category,
      isLoading: true,
      clearError: true,
    );

    try {
      final res = await _repo.fetchNotifications(
        skip: 0,
        limit: _pageSize,
        category: category,
      );
      state = state.copyWith(
        items: res.items,
        unreadCount: res.unreadCount,
        total: res.total,
        hasMore: res.hasMore,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Unable to load notifications. Pull down to retry.',
      );
    }
  }

  Future<void> refresh() async {
    if (ref.read(currentUserProvider) == null) return;
    await _loadInitial(category: state.selectedCategory);
  }

  Future<void> setCategory(String category) async {
    if (state.selectedCategory == category &&
        !state.isLoading &&
        state.error == null) {
      return;
    }
    await _loadInitial(category: category);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (ref.read(currentUserProvider) == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final res = await _repo.fetchNotifications(
        skip: state.items.length,
        limit: _pageSize,
        category: state.selectedCategory,
      );
      final existingIds = state.items.map((e) => e.id).toSet();
      final appended = [
        ...state.items,
        ...res.items.where((e) => !existingIds.contains(e.id)),
      ];
      state = state.copyWith(
        items: appended,
        unreadCount: res.unreadCount,
        total: res.total,
        hasMore: res.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markAllRead() async {
    if (state.items.isEmpty && state.unreadCount == 0) return;

    final previousState = state;
    state = state.copyWith(
      items: [for (final n in state.items) n.copyWith(read: true)],
      unreadCount: 0,
    );

    try {
      await _repo.markAllRead();
    } catch (_) {
      state = previousState;
    }
  }

  Future<void> markRead(String id) async {
    final targetIndex = state.items.indexWhere((n) => n.id == id);
    if (targetIndex == -1 || state.items[targetIndex].read) return;

    final previousState = state;
    final updatedItems = [
      for (final n in state.items)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
    final nextUnread = (state.unreadCount - 1).clamp(0, 999999);

    state = state.copyWith(items: updatedItems, unreadCount: nextUnread);

    try {
      await _repo.markRead(id);
    } catch (_) {
      state = previousState;
    }
  }

  Future<bool> deleteNotification(String id) async {
    final targetIndex = state.items.indexWhere((n) => n.id == id);
    if (targetIndex == -1) return false;
    final target = state.items[targetIndex];
    if (target.isBroadcast) return false;

    final previousState = state;
    final nextItems = List<AppNotification>.of(state.items)
      ..removeAt(targetIndex);
    final nextUnread = target.read
        ? state.unreadCount
        : (state.unreadCount - 1).clamp(0, 999999);

    state = state.copyWith(
      items: nextItems,
      unreadCount: nextUnread,
      total: (state.total - 1).clamp(0, 999999),
    );

    try {
      await _repo.deleteNotification(id);
      return true;
    } catch (_) {
      state = previousState;
      return false;
    }
  }
}

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});

// ── Live Environmental Vitals (AQI, UV, Thermal Comfort & Noise) ──────────────

const Map<String, (double, double)> _cityCoords = {
  // ── Karnataka: All 31 Districts, Major Tech Hubs & Heritage Towns ──────────
  'bengaluru': (12.9716, 77.5946),
  'bangalore': (12.9716, 77.5946),
  'whitefield': (12.9698, 77.7500),
  'indiranagar': (12.9784, 77.6408),
  'koramangala': (12.9352, 77.6245),
  'hsr layout': (12.9121, 77.6446),
  'electronic city': (12.8399, 77.6770),
  'jayanagar': (12.9308, 77.5838),
  'yelahanka': (13.1007, 77.5963),
  'mysuru': (12.2958, 76.6394),
  'mysore': (12.2958, 76.6394),
  'mangaluru': (12.9141, 74.8560),
  'mangalore': (12.9141, 74.8560),
  'hubballi': (15.3647, 75.1240),
  'hubli': (15.3647, 75.1240),
  'dharwad': (15.4589, 75.0078),
  'belagavi': (15.8497, 74.4977),
  'belgaum': (15.8497, 74.4977),
  'kalaburagi': (17.3297, 76.8343),
  'gulbarga': (17.3297, 76.8343),
  'shivamogga': (13.9299, 75.5681),
  'shimoga': (13.9299, 75.5681),
  'davanagere': (14.4644, 75.9218),
  'davangere': (14.4644, 75.9218),
  'ballari': (15.1394, 76.9214),
  'bellary': (15.1394, 76.9214),
  'vijayapura': (16.8302, 75.7100),
  'bijapur': (16.8302, 75.7100),
  'udupi': (13.3409, 74.7421),
  'manipal': (13.3525, 74.7865),
  'tumakuru': (13.3379, 77.1017),
  'tumkur': (13.3379, 77.1017),
  'hassan': (13.0033, 76.1004),
  'chikkamagaluru': (13.3161, 75.7720),
  'chikmagalur': (13.3161, 75.7720),
  'kodagu': (12.4244, 75.7382),
  'coorg': (12.4244, 75.7382),
  'madikeri': (12.4244, 75.7382),
  'bidar': (17.9104, 77.5199),
  'raichur': (16.2120, 77.3439),
  'bagalkot': (16.1691, 75.6615),
  'bagalkote': (16.1691, 75.6615),
  'chitradurga': (14.2251, 76.3980),
  'kolar': (13.1367, 78.1291),
  'mandya': (12.5218, 76.8951),
  'ramanagara': (12.7209, 77.2799),
  'ramanagar': (12.7209, 77.2799),
  'chikkaballapur': (13.4325, 77.7275),
  'gadag': (15.4167, 75.6333),
  'haveri': (14.7954, 75.4024),
  'koppal': (15.3456, 76.1558),
  'yadgir': (16.7628, 77.1378),
  'chamarajanagar': (11.9261, 76.9437),
  'karwar': (14.8136, 74.1298),
  'gokarna': (14.5479, 74.3188),
  'dandeli': (15.2447, 74.6231),
  'hosapete': (15.2689, 76.3909),
  'hospet': (15.2689, 76.3909),
  'hampi': (15.3350, 76.4600),
  'sirsi': (14.6195, 74.8354),

  // ── Major Indian Metros & National State Capitals ──────────────────────────
  'mumbai': (19.0760, 72.8777),
  'navi mumbai': (19.0330, 73.0297),
  'thane': (19.2183, 72.9781),
  'delhi': (28.6139, 77.2090),
  'new delhi': (28.6139, 77.2090),
  'noida': (28.5355, 77.3910),
  'gurugram': (28.4595, 77.0266),
  'gurgaon': (28.4595, 77.0266),
  'faridabad': (28.4089, 77.3178),
  'ghaziabad': (28.6692, 77.4538),
  'pune': (18.5204, 73.8567),
  'hyderabad': (17.3850, 78.4867),
  'chennai': (13.0827, 80.2707),
  'kolkata': (22.5726, 88.3639),
  'ahmedabad': (23.0225, 72.5714),
  'surat': (21.1702, 72.8311),
  'jaipur': (26.9124, 75.7873),
  'lucknow': (26.8467, 80.9462),
  'kanpur': (26.4499, 80.3319),
  'nagpur': (21.1458, 79.0882),
  'indore': (22.7196, 75.8577),
  'bhopal': (23.2599, 77.4126),
  'visakhapatnam': (17.6868, 83.2185),
  'vizag': (17.6868, 83.2185),
  'vijayawada': (16.5062, 80.6480),
  'coimbatore': (11.0168, 76.9558),
  'madurai': (9.9252, 78.1198),
  'chandigarh': (30.7333, 76.7794),
  'patna': (25.5941, 85.1376),
  'bhubaneswar': (20.2961, 85.8245),
  'vadodara': (22.3072, 73.1812),
  'nashik': (19.9975, 73.7898),
  'varanasi': (25.3176, 82.9739),
  'amritsar': (31.6340, 74.8723),
  'dehradun': (30.3165, 78.0322),
  'guwahati': (26.1445, 91.7362),
  'ranchi': (23.3441, 85.3096),
  'raipur': (21.2514, 81.6296),

  // ── Kerala Hubs & Districts ────────────────────────────────────────────────
  'thiruvananthapuram': (8.5241, 76.9366),
  'trivandrum': (8.5241, 76.9366),
  'kochi': (9.9312, 76.2673),
  'cochin': (9.9312, 76.2673),
  'ernakulam': (9.9816, 76.2999),
  'kozhikode': (11.2588, 75.7804),
  'calicut': (11.2588, 75.7804),
  'thrissur': (10.5276, 76.2144),
  'kollam': (8.8932, 76.6141),
  'alappuzha': (9.4981, 76.3388),
  'alleppey': (9.4981, 76.3388),
  'palakkad': (10.7867, 76.6548),
  'kannur': (11.8745, 75.3704),
  'kottayam': (9.5916, 76.5222),
  'malappuram': (11.0510, 76.0711),
  'wayanad': (11.6854, 76.1320),
  'kalpetta': (11.6103, 76.0829),
  'idukki': (9.8494, 76.9804),
  'munnar': (10.0889, 77.0595),
  'kasaragod': (12.5102, 74.9852),
  'pathanamthitta': (9.2648, 76.7870),
};

final cityAqiProvider = FutureProvider<CityAqiData>((ref) async {
  final user = ref.watch(currentUserProvider);
  String displayLocation = (user?.city != null && user!.city!.trim().isNotEmpty)
      ? user.city!.trim()
      : '';

  double lat = 12.9716;
  double lng = 77.5946;
  bool foundPreciseLocation = false;

  // 1. Prioritize live GPS from the device
  try {
    final lastPos = await Geolocator.getLastKnownPosition();
    if (lastPos != null) {
      lat = lastPos.latitude;
      lng = lastPos.longitude;
      foundPreciseLocation = true;
    } else {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final curPos = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 2),
        );
        lat = curPos.latitude;
        lng = curPos.longitude;
        foundPreciseLocation = true;
      }
    }
  } catch (_) {}

  // 2. If GPS is off, match user's profile city against local coordinates directory
  if (!foundPreciseLocation && displayLocation.isNotEmpty) {
    final key = displayLocation.toLowerCase();
    if (_cityCoords.containsKey(key)) {
      lat = _cityCoords[key]!.$1;
      lng = _cityCoords[key]!.$2;
      foundPreciseLocation = true;
    }
  }

  if (displayLocation.isEmpty) {
    displayLocation = foundPreciseLocation ? 'Your Location' : 'Bengaluru';
  }

  // 3. Query the BlueDot Backend API directly (served via 45-min Redis cache)
  try {
    final vitals = await ref.read(homeRepositoryProvider).fetchEcoVitals(
      latitude: lat,
      longitude: lng,
      city: displayLocation,
    );
    return vitals;
  } catch (e) {
    debugPrint('EcoVitals backend request failed, using local baseline: $e');
  }

  return CityAqiData.fallbackBangalore;
});
