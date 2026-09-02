/// A single promo banner shown in the home-screen carousel.
///
/// This is a flat, immutable value object. All behavior lives in computed
/// getters (not in the widget) so the carousel only ever *asks questions* —
/// it never parses strings or branches on raw field values.
class AppBanner {
  final String id;

  /// The image / GIF / video URL. Required to render anything.
  final String mediaUrl;

  /// One of `image` | `gif` | `video`. Drives the rendering path.
  final String mediaType;

  /// Display order: lower = first. `0`/unset sorts to the end.
  final int priority;

  /// Admin override for how long the slide stays up. `null` means
  /// "use the media-aware default". Never `<= 0` (see [fromJson]).
  final int? durationSeconds;

  /// One of `route` | `link` | `scan` | `none`. Drives the tap behavior.
  final String actionType;

  /// go_router path for [actionType] == `route`. Always absolute (see [fromJson]).
  final String? actionTarget;

  /// External URL for [actionType] == `link`.
  final String? linkUrl;

  /// Optional copy kept for semantics / accessibility — not rendered.
  final String? title;
  final String? subtitle;

  const AppBanner({
    required this.id,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.priority = 0,
    this.durationSeconds,
    this.actionType = 'none',
    this.actionTarget,
    this.linkUrl,
    this.title,
    this.subtitle,
  });

  // --- Behavior as getters (PassiTon principle) ---

  bool get isVideo => mediaType == 'video';
  bool get isGif => mediaType == 'gif';
  bool get isImage => !isVideo && !isGif;

  bool get hasLink => linkUrl != null && linkUrl!.trim().isNotEmpty;
  bool get isRoute =>
      actionType == 'route' && (actionTarget?.trim().isNotEmpty ?? false);
  bool get isScan => actionType == 'scan';

  /// Whether a tap should do anything at all.
  bool get isTappable => isRoute || isScan || (actionType == 'link' && hasLink);

  /// Whether there is media to render. Banners without a URL are dropped.
  bool get isRenderable => mediaUrl.trim().isNotEmpty;

  /// Defensive parsing at the network/cache boundary: null-coalesce every
  /// field, lowercase enums, trim links/targets, accept the legacy `image`
  /// key as a `media_url` fallback, treat `duration_seconds <= 0` as null so
  /// the rotate timer can never be armed at zero, and force [actionTarget]
  /// to an absolute path so go_router never resolves it relatively.
  factory AppBanner.fromJson(Map<String, dynamic> json) {
    final rawDuration = (json['duration_seconds'] as num?)?.toInt();
    final rawTarget = (json['action_target'] as String?)?.trim();
    final mediaUrl =
        ((json['media_url'] ?? json['image']) as String?)?.trim() ?? '';

    return AppBanner(
      id: (json['id'] ?? '').toString(),
      mediaUrl: mediaUrl,
      mediaType: (json['media_type'] as String?)?.trim().toLowerCase() ?? 'image',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      durationSeconds: (rawDuration != null && rawDuration > 0) ? rawDuration : null,
      actionType: (json['action_type'] as String?)?.trim().toLowerCase() ?? 'none',
      actionTarget: (rawTarget == null || rawTarget.isEmpty)
          ? null
          : (rawTarget.startsWith('/') ? rawTarget : '/$rawTarget'),
      linkUrl: (json['link_url'] as String?)?.trim(),
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
    );
  }

  /// Turns a raw list into a trustworthy, ordered list before the UI sees it:
  /// drop malformed/empty entries, then sort so the order can't be disturbed
  /// by caching, re-parsing, or API array order.
  ///
  /// Order: ascending [priority], unset/`0` last, ties broken by newest [id].
  static List<AppBanner> parseList(List<dynamic> raw) {
    final banners = raw
        .whereType<Map<String, dynamic>>()
        .map(AppBanner.fromJson)
        .where((b) => b.isRenderable)
        .toList();
    sortInPlace(banners);
    return banners;
  }

  /// Shared sort so demo and live paths render identically.
  static void sortInPlace(List<AppBanner> banners) {
    banners.sort((a, b) {
      final aUnset = a.priority <= 0, bUnset = b.priority <= 0;
      if (aUnset != bUnset) return aUnset ? 1 : -1; // unset/0 -> last
      final byPriority = a.priority.compareTo(b.priority); // ascending
      return byPriority != 0 ? byPriority : b.id.compareTo(a.id); // tie -> newest
    });
  }
}
