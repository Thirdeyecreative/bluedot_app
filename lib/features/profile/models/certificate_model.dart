class VolunteerCertificate {
  final String id;
  final String eventTitle;
  final String siteName;
  final String dateLabel;
  final int treesPlanted;
  final int hours;
  final String role; // e.g. Volunteer, Team Lead
  final String certificateNo;

  const VolunteerCertificate({
    required this.id,
    required this.eventTitle,
    required this.siteName,
    required this.dateLabel,
    required this.treesPlanted,
    required this.hours,
    this.role = 'Volunteer',
    required this.certificateNo,
  });
}
