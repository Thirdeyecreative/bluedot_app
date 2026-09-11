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

  factory Campaign.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    return Campaign(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      targetAmount: parseDouble(json['target_amount']),
      currentAmountRaised: parseDouble(json['current_amount_raised']),
      description: json['description'] as String?,
      mediaUrls: (json['media_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      campaignStatus: json['campaign_status'] as String?,
    );
  }

  double get progressPercent =>
      targetAmount > 0 ? (currentAmountRaised / targetAmount).clamp(0, 1) : 0;

  String? get thumbnailUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;
}
