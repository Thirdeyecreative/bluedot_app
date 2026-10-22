class BlogPost {
  final String id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? bodyText;
  final List<String> mediaUrls;
  final String? author;
  final String? publishedAt;
  final String? linkedCampaignName;
  final int views;

  const BlogPost({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.bodyText,
    this.mediaUrls = const [],
    this.author,
    this.publishedAt,
    this.linkedCampaignName,
    this.views = 0,
  });

  factory BlogPost.fromJson(Map<String, dynamic> json) => BlogPost(
        id: json['id']?.toString() ?? '',
        slug: json['slug']?.toString() ?? json['id']?.toString() ?? '',
        title: json['title'] as String? ?? 'Untitled',
        excerpt: json['excerpt'] as String?,
        bodyText: json['body_text'] as String?,
        mediaUrls: (json['media_urls'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        author: json['author'] as String?,
        publishedAt: json['published_at'] as String?,
        linkedCampaignName: json['linked_campaign_name'] as String?,
        views: (json['views'] as num?)?.toInt() ?? 0,
      );

  String? get thumbnailUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;
}
