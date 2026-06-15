class PlantationEvent {
  final String id;
  final String title;
  final String? description;
  final String? eventDate;
  final String? eventStatus;
  final String? siteName;
  final int maxParticipants;
  final int participantsCount;
  final int treesTarget;
  final int treesPlanted;
  final List<String> mediaUrls;
  final bool isPlantationDrive;

  const PlantationEvent({
    required this.id,
    required this.title,
    this.description,
    this.eventDate,
    this.eventStatus,
    this.siteName,
    this.maxParticipants = 0,
    this.participantsCount = 0,
    this.treesTarget = 0,
    this.treesPlanted = 0,
    this.mediaUrls = const [],
    this.isPlantationDrive = true,
  });

  factory PlantationEvent.fromJson(Map<String, dynamic> json) => PlantationEvent(
        id: json['id'] as String,
        title: json['title'] as String? ?? json['name'] as String? ?? '',
        description: json['description'] as String?,
        eventDate: json['event_date'] as String? ?? json['date'] as String?,
        eventStatus: json['event_status'] as String?,
        siteName: json['site_name'] as String?,
        maxParticipants: json['max_participants'] as int? ?? 0,
        participantsCount: json['participants_count'] as int? ?? json['registrations'] as int? ?? 0,
        treesTarget: json['trees_target'] as int? ?? 0,
        treesPlanted: json['trees_planted'] as int? ?? 0,
        mediaUrls: (json['media_urls'] as List<dynamic>?)?.cast<String>() ?? [],
        isPlantationDrive: json['is_plantation_drive'] as bool? ?? true,
      );

  String? get thumbnailUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;

  String get formattedDate {
    if (eventDate == null) return 'TBD';
    try {
      final dt = DateTime.parse(eventDate!);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return eventDate!;
    }
  }

  bool get isFull => maxParticipants > 0 && participantsCount >= maxParticipants;
}
