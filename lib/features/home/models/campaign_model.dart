class Campaign {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmountRaised;
  final String? description;
  final List<String> mediaUrls;
  final String? campaignStatus;

  const Campaign({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmountRaised,
    this.description,
    this.mediaUrls = const [],
    this.campaignStatus,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
        id: json['id'] as String,
        title: json['title'] as String? ?? json['name'] as String? ?? '',
        targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
        currentAmountRaised: (json['current_amount_raised'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String?,
        mediaUrls: (json['media_urls'] as List<dynamic>?)?.cast<String>() ?? [],
        campaignStatus: json['campaign_status'] as String?,
      );

  double get progressPercent =>
      targetAmount > 0 ? (currentAmountRaised / targetAmount).clamp(0, 1) : 0;

  String? get thumbnailUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;
}
