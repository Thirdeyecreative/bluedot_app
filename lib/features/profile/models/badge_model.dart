class Badge {
  final String id;
  final String name;
  final String? description;
  final String? metric;
  final int threshold;
  final int points;
  final bool unlocked;

  const Badge({
    required this.id,
    required this.name,
    this.description,
    this.metric,
    required this.threshold,
    required this.points,
    this.unlocked = false,
  });

  factory Badge.fromJson(Map<String, dynamic> json, {bool unlocked = false}) => Badge(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        metric: json['metric'] as String?,
        threshold: json['threshold'] as int? ?? 0,
        points: json['points'] as int? ?? 0,
        unlocked: unlocked,
      );

  String get emoji {
    if (metric == null) return '🏅';
    if (metric!.contains('scan')) return '🌿';
    if (metric!.contains('tree')) return '🌳';
    if (metric!.contains('event')) return '🎪';
    if (metric!.contains('donate')) return '💚';
    if (metric!.contains('volunteer')) return '🤝';
    return '⭐';
  }
}
