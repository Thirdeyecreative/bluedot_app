class DonationPolicy {
  const DonationPolicy({
    required this.minAmount,
    required this.maxAmount,
    required this.campaignPresets,
    required this.eventPresets,
    required this.receiptIssuanceEnabled,
  });

  final int minAmount;
  final int maxAmount;
  final List<int> campaignPresets;
  final List<int> eventPresets;
  final bool receiptIssuanceEnabled;

  factory DonationPolicy.fromJson(Map<String, dynamic> json) => DonationPolicy(
    minAmount: json['min_amount'] as int,
    maxAmount: json['max_amount'] as int,
    campaignPresets: List<int>.from(json['campaign_presets'] as List),
    eventPresets: List<int>.from(json['event_presets'] as List),
    receiptIssuanceEnabled: json['receipt_issuance_enabled'] as bool,
  );

  bool allows(int amount) => amount >= minAmount && amount <= maxAmount;
}
