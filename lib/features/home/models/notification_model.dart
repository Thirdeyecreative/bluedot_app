enum AppNotificationType { drive, badge, campaign, certificate, system }

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
