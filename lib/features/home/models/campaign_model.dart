class Campaign {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmountRaised;
  final String? description;
  final List<String> mediaUrls;
  final String? campaignStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? healthStatus;
  final String? projectManagerName;

  const Campaign({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmountRaised,
    this.description,
    this.mediaUrls = const [],
    this.campaignStatus,
    this.startDate,
    this.endDate,
    this.healthStatus,
    this.projectManagerName,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Campaign(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      targetAmount: parseDouble(json['target_amount']),
      currentAmountRaised: parseDouble(json['current_amount_raised']),
      description: json['description'] as String?,
      mediaUrls: (json['media_urls'] as List<dynamic>?)
          ?.where((e) => e is String && e.isNotEmpty)
          .cast<String>()
          .toList() ?? [],
      campaignStatus: json['campaign_status'] as String?,
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      healthStatus: json['health_status'] as String?,
      projectManagerName: json['project_manager_name'] as String?,
    );
  }

  double get progressPercent =>
      targetAmount > 0 ? (currentAmountRaised / targetAmount).clamp(0, 1) : 0;

  String? get thumbnailUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;

  String get formattedTimeline {
    if (startDate == null && endDate == null) return 'Ongoing Initiative';
    final startStr = startDate != null ? '${startDate!.day} ${_monthName(startDate!.month)}' : 'TBD';
    final endStr = endDate != null ? '${endDate!.day} ${_monthName(endDate!.month)} ${endDate!.year}' : 'Ongoing';
    return '$startStr — $endStr';
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }
}
