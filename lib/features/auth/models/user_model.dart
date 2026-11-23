class AppUser {
  final String id;
  final String phone;
  final String? fullName;
  final String? email;
  final String? city;
  final int totalPoints;
  final int level;
  final String? _levelTitle;
  final int? levelStartXp;
  final int? nextLevelXp;
  final double totalDonated;
  final int treesTagged;
  final String? avatarUrl;
  final String? panNumber;
  final Map<String, dynamic>? preferences;

  const AppUser({
    required this.id,
    required this.phone,
    this.fullName,
    this.email,
    this.city,
    this.totalPoints = 0,
    this.level = 1,
    String? levelTitle,
    this.levelStartXp,
    this.nextLevelXp,
    this.totalDonated = 0,
    this.treesTagged = 0,
    this.avatarUrl,
    this.panNumber,
    this.preferences,
  }) : _levelTitle = levelTitle;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    // The backend stores '' for ghost users to satisfy NOT NULL.
    // Normalise to null so the router treats it as "profile incomplete".
    String? _nonEmpty(String? v) => (v == null || v.trim().isEmpty) ? null : v;

    String? _fixUiAvatars(String? url) {
      if (url == null) return null;
      if (url.contains('ui-avatars.com') && !url.contains('format=')) {
        return url.contains('?') ? '$url&format=png' : '$url?format=png';
      }
      return url;
    }

    final points =
        json['total_impact_points'] as int? ??
        json['total_points'] as int? ??
        0;

    return AppUser(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      fullName: _nonEmpty(json['full_name'] as String?),
      email: _nonEmpty(json['email'] as String?),
      city: _nonEmpty(json['city'] as String?),
      totalPoints: points,
      level: json['level'] as int? ?? 1,
      levelTitle: json['level_title'] as String?,
      levelStartXp: json['level_start_xp'] as int?,
      nextLevelXp: json['next_level_xp'] as int?,
      totalDonated: (json['total_donated'] as num?)?.toDouble() ?? 0,
      treesTagged: json['trees_tagged'] as int? ?? 0,
      avatarUrl: _fixUiAvatars(json['avatar_url'] as String?),
      panNumber: _nonEmpty(json['pan_number'] as String?),
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  String get levelTitle => _levelTitle ?? 'Level $level';

  bool get hasLevelProgress =>
      levelStartXp != null &&
      nextLevelXp != null &&
      nextLevelXp! > levelStartXp!;
  int get pointsForNextLevel =>
      hasLevelProgress ? nextLevelXp! - levelStartXp! : 0;
  int get pointsInCurrentLevel => hasLevelProgress
      ? (totalPoints - levelStartXp!).clamp(0, pointsForNextLevel)
      : 0;
  double get levelProgress =>
      hasLevelProgress ? pointsInCurrentLevel / pointsForNextLevel : 0;

  AppUser copyWith({
    String? fullName,
    String? email,
    String? city,
    int? totalPoints,
    int? level,
    double? totalDonated,
    int? treesTagged,
    String? avatarUrl,
    String? panNumber,
    Map<String, dynamic>? preferences,
  }) =>
      AppUser(
        id: id,
        phone: phone,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        city: city ?? this.city,
        totalPoints: totalPoints ?? this.totalPoints,
    level: level ?? this.level,
    levelTitle: _levelTitle,
    levelStartXp: levelStartXp,
    nextLevelXp: nextLevelXp,
        totalDonated: totalDonated ?? this.totalDonated,
        treesTagged: treesTagged ?? this.treesTagged,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        panNumber: panNumber ?? this.panNumber,
        preferences: preferences ?? this.preferences,
      );
}
