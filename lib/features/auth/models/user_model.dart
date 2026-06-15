class AppUser {
  final String id;
  final String phone;
  final String? fullName;
  final String? email;
  final String? city;
  final int totalPoints;
  final int level;
  final double totalDonated;
  final int treesTagged;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.phone,
    this.fullName,
    this.email,
    this.city,
    this.totalPoints = 0,
    this.level = 1,
    this.totalDonated = 0,
    this.treesTagged = 0,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        phone: json['phone'] as String? ?? '',
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        city: json['city'] as String?,
        totalPoints: json['total_points'] as int? ?? 0,
        level: json['level'] as int? ?? 1,
        totalDonated: (json['total_donated'] as num?)?.toDouble() ?? 0,
        treesTagged: json['trees_tagged'] as int? ?? 0,
        avatarUrl: json['avatar_url'] as String?,
      );

  String get levelTitle {
    switch (level) {
      case 1:
        return 'Seedling';
      case 2:
        return 'Sapling';
      case 3:
        return 'Ranger';
      case 4:
        return 'Guardian';
      case 5:
        return 'Elder';
      default:
        return level >= 5 ? 'Elder' : 'Seedling';
    }
  }

  int get pointsForNextLevel => level * 500;
  int get pointsInCurrentLevel => totalPoints % 500;
  double get levelProgress => pointsInCurrentLevel / pointsForNextLevel;

  AppUser copyWith({
    String? fullName,
    String? email,
    String? city,
    String? avatarUrl,
  }) =>
      AppUser(
        id: id,
        phone: phone,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        city: city ?? this.city,
        totalPoints: totalPoints,
        level: level,
        totalDonated: totalDonated,
        treesTagged: treesTagged,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}
