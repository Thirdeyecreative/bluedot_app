enum AppNotificationType { drive, badge, campaign, certificate, donation, system }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String timeLabel;
  final bool read;
  final String? route; // optional deep link target

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.read = false,
    this.route,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? 'system').toLowerCase();
    final type = switch (rawType) {
      'drive' => AppNotificationType.drive,
      'badge' => AppNotificationType.badge,
      'campaign' => AppNotificationType.campaign,
      'certificate' => AppNotificationType.certificate,
      'donation' => AppNotificationType.donation,
      _ => AppNotificationType.system,
    };

    return AppNotification(
      id: json['id'] as String? ?? '',
      type: type,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? 'Just now',
      read: json['read'] as bool? ?? false,
      route: json['route'] as String?,
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        timeLabel: timeLabel,
        read: read ?? this.read,
        route: route,
      );
}
