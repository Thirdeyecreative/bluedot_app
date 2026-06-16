class PlantationEvent {
  final String id;
  final String title;
  final String? description;
  final String? eventDate;
  final String? eventStatus;
  final String? siteName;
  final String? eventTypeName;
  final int? maxParticipants;
  final int? volunteersRequired;
  final int attendeesCount;
  final int volunteersCount;
  final int? spotsLeft;
  final int? volunteerSpotsLeft;
  final int treesTarget;
  final int treesPlanted;
  final List<String> mediaUrls;
  final bool isPlantationDrive;
  final bool isUserRsvped;
  final bool isUserVolunteered;
  final bool isUserCheckedIn;

  const PlantationEvent({
    required this.id,
    required this.title,
    this.description,
    this.eventDate,
    this.eventStatus,
    this.siteName,
    this.eventTypeName,
    this.maxParticipants,
    this.volunteersRequired,
    this.attendeesCount = 0,
    this.volunteersCount = 0,
    this.spotsLeft,
    this.volunteerSpotsLeft,
    this.treesTarget = 0,
    this.treesPlanted = 0,
    this.mediaUrls = const [],
    this.isPlantationDrive = false,
    this.isUserRsvped = false,
    this.isUserVolunteered = false,
    this.isUserCheckedIn = false,
  });

  factory PlantationEvent.fromJson(Map<String, dynamic> json) => PlantationEvent(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        eventDate: json['event_date'] as String?,
        eventStatus: json['event_status'] as String?,
        siteName: json['site_name'] as String?,
        eventTypeName: json['event_type_name'] as String?,
        maxParticipants: json['max_participants'] as int?,
        volunteersRequired: json['volunteers_required'] as int?,
        attendeesCount: json['attendees_count'] as int? ?? 0,
        volunteersCount: json['volunteers_count'] as int? ?? 0,
        spotsLeft: json['spots_left'] as int?,
        volunteerSpotsLeft: json['volunteer_spots_left'] as int?,
        treesTarget: json['trees_target'] as int? ?? 0,
        treesPlanted: json['trees_planted'] as int? ?? 0,
        mediaUrls: (json['media_urls'] as List<dynamic>?)?.cast<String>() ?? [],
        isPlantationDrive: json['is_plantation_drive'] as bool? ?? false,
        isUserRsvped: json['is_user_rsvped'] as bool? ?? false,
        isUserVolunteered: json['is_user_volunteered'] as bool? ?? false,
        isUserCheckedIn: json['is_user_checked_in'] as bool? ?? false,
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

  bool get isAttendeeFull => maxParticipants != null && attendeesCount >= maxParticipants!;
  bool get isVolunteerFull => volunteersRequired != null && volunteersCount >= volunteersRequired!;

  PlantationEvent copyWith({
    bool? isUserRsvped,
    bool? isUserVolunteered,
    bool? isUserCheckedIn,
    int? attendeesCount,
    int? volunteersCount,
    int? spotsLeft,
    int? volunteerSpotsLeft,
  }) =>
      PlantationEvent(
        id: id,
        title: title,
        description: description,
        eventDate: eventDate,
        eventStatus: eventStatus,
        siteName: siteName,
        eventTypeName: eventTypeName,
        maxParticipants: maxParticipants,
        volunteersRequired: volunteersRequired,
        attendeesCount: attendeesCount ?? this.attendeesCount,
        volunteersCount: volunteersCount ?? this.volunteersCount,
        spotsLeft: spotsLeft ?? this.spotsLeft,
        volunteerSpotsLeft: volunteerSpotsLeft ?? this.volunteerSpotsLeft,
        treesTarget: treesTarget,
        treesPlanted: treesPlanted,
        mediaUrls: mediaUrls,
        isPlantationDrive: isPlantationDrive,
        isUserRsvped: isUserRsvped ?? this.isUserRsvped,
        isUserVolunteered: isUserVolunteered ?? this.isUserVolunteered,
        isUserCheckedIn: isUserCheckedIn ?? this.isUserCheckedIn,
      );
}
