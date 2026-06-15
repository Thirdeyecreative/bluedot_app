class AppBanner {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? placement;

  const AppBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.placement,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) => AppBanner(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        imageUrl: json['image'] as String?,
        placement: json['placement'] as String?,
      );
}
