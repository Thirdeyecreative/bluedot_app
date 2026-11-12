enum AppNotificationType { drive, badge, campaign, certificate, donation, system }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String rawType;
  final String category;
  final String title;
  final String body;
  final String timeLabel;
  final bool read;
  final bool isBroadcast;
  final String? route; // optional deep link target
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    this.rawType = 'system',
    this.category = 'system',
    required this.title,
    required this.body,
    required this.timeLabel,
    this.read = false,
    this.isBroadcast = false,
    this.route,
    this.data = const {},
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? 'system').trim().toLowerCase();
    final type = switch (rawType) {
      'drive' || 'drive_reminder' || 'event_rsvp' || 'event_checkin' || 'event_update' =>
        AppNotificationType.drive,
      'badge' || 'badge_earned' || 'tree_tagged' || 'suggestion_approved' || 'suggestion_rejected' =>
        AppNotificationType.badge,
      'campaign' || 'campaign_update' || 'admin_broadcast' || 'announcement' =>
        AppNotificationType.campaign,
      'certificate' || 'certificate_ready' => AppNotificationType.certificate,
      'donation' || 'donation_confirmed' => AppNotificationType.donation,
      _ => AppNotificationType.system,
    };

    final createdAtRaw = json['created_at'] as String?;
    final parsedDate = createdAtRaw != null ? DateTime.tryParse(createdAtRaw)?.toLocal() : null;
    final serverLabel = (json['timeLabel'] as String?)?.trim();
    final computedLabel = (serverLabel != null && serverLabel.isNotEmpty)
        ? serverLabel
        : _formatRelativeTime(parsedDate);

    final rawData = json['data'];
    final parsedData = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map ? Map<String, dynamic>.from(rawData) : const <String, dynamic>{});

    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: type,
      rawType: rawType,
      category: (json['category'] as String?)?.trim().toLowerCase() ?? _inferCategory(rawType),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timeLabel: computedLabel,
      read: json['read'] as bool? ?? json['is_read'] as bool? ?? false,
      isBroadcast: json['is_broadcast'] as bool? ?? false,
      route: json['route'] as String?,
      data: parsedData,
      createdAt: parsedDate,
    );
  }

  static String _inferCategory(String rawType) {
    return switch (rawType) {
      'drive' || 'drive_reminder' || 'event_rsvp' || 'event_checkin' || 'event_update' => 'drives',
      'badge' || 'badge_earned' || 'tree_tagged' || 'certificate' || 'certificate_ready' || 'suggestion_approved' || 'suggestion_rejected' =>
        'badges',
      'donation' || 'donation_confirmed' || 'campaign' || 'campaign_update' => 'donations',
      'admin_broadcast' || 'announcement' => 'announcements',
      _ => 'system',
    };
  }

  static String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
  }

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        rawType: rawType,
        category: category,
        title: title,
        body: body,
        timeLabel: timeLabel,
        read: read ?? this.read,
        isBroadcast: isBroadcast,
        route: route,
        data: data,
        createdAt: createdAt,
      );
}

class PaginatedNotificationsResponse {
  final List<AppNotification> items;
  final int unreadCount;
  final int total;
  final bool hasMore;

  const PaginatedNotificationsResponse({
    required this.items,
    required this.unreadCount,
    required this.total,
    required this.hasMore,
  });

  factory PaginatedNotificationsResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List<dynamic>? ?? const [];
    final items = rawList
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final unread = (json['unread_count'] as num?)?.toInt() ??
        items.where((n) => !n.read).length;
    final total = (json['total'] as num?)?.toInt() ?? items.length;
    final hasMore = json['has_more'] as bool? ?? (items.length < total);

    return PaginatedNotificationsResponse(
      items: items,
      unreadCount: unread,
      total: total,
      hasMore: hasMore,
    );
  }
}
