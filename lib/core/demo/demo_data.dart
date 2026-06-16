import '../../features/action_hub/models/event_model.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/directory/models/species_model.dart';
import '../../features/home/models/banner_model.dart';
import '../../features/home/models/blog_model.dart';
import '../../features/home/models/campaign_model.dart';
import '../../features/home/models/notification_model.dart';
import '../../features/profile/models/badge_model.dart';
import '../../features/profile/models/certificate_model.dart';
import '../../features/scanner/models/scan_result_model.dart';

class DemoData {
  static const demoPhone = '+919999999999';
  static const demoOtp = '123456';
  static const demoToken = 'demo-auth-token';

  static const user = AppUser(
    id: 'demo-user',
    phone: demoPhone,
    fullName: 'Avishkar',
    email: 'avishkar@bluedot.demo',
    totalPoints: 1320,
    level: 3,
    totalDonated: 7500,
    treesTagged: 18,
  );

  static const banners = [
    AppBanner(
      id: 'banner-1',
      title: 'Restore 10,000 native trees this monsoon',
      subtitle: 'Join drives, tag trees, and watch your impact grow.',
      imageUrl:
          'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?auto=format&fit=crop&w=1200&q=80',
      placement: 'home_top',
    ),
  ];

  static const campaigns = [
    Campaign(
      id: 'campaign-aravalli',
      title: 'Aravalli Native Forest Revival',
      targetAmount: 1500000,
      currentAmountRaised: 970000,
      description:
          'Help restore degraded Aravalli patches with native saplings, soil care, and community stewardship.',
      mediaUrls: [
        'https://images.unsplash.com/photo-1425913397330-cf8af2ff40a1?auto=format&fit=crop&w=1200&q=80',
      ],
      campaignStatus: 'Active',
    ),
    Campaign(
      id: 'campaign-school',
      title: 'School Miyawaki Micro-Forests',
      targetAmount: 800000,
      currentAmountRaised: 380000,
      description:
          'Create dense learning forests inside urban schools so students can care for biodiversity every day.',
      mediaUrls: [
        'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=1200&q=80',
      ],
      campaignStatus: 'Matching',
    ),
    Campaign(
      id: 'campaign-lake',
      title: 'Lake Edge Green Buffer',
      targetAmount: 1200000,
      currentAmountRaised: 640000,
      description:
          'Plant native wetland buffers around vulnerable lake edges to reduce erosion and bring back birds.',
      mediaUrls: [
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
      ],
      campaignStatus: 'Active',
    ),
  ];

  static const blogs = [
    BlogPost(
      id: 'blog-1',
      slug: 'why-native-trees-matter',
      title: 'Why native trees make urban forests stronger',
      excerpt:
          'Native species support local birds, pollinators, soil health, and long-term survival better than ornamental planting.',
      bodyText:
          'Native trees are adapted to local rainfall, heat, soil, and seasonal rhythms. That means they need less maintenance after establishment and support a richer web of insects, birds, and fungi.\n\nFor BlueDot plantation drives, every species mix is designed around ecological fit. Neem, Peepal, Jamun, Arjun, and Banyan are not just beautiful trees; they become living infrastructure for shade, carbon storage, and biodiversity.\n\nThe app flow helps volunteers understand that every scan and every tag becomes part of a long-term restoration record.',
      mediaUrls: [
        'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1200&q=80',
      ],
      author: 'BlueDot Field Team',
      publishedAt: '2026-06-01T09:30:00Z',
      linkedCampaignName: 'Aravalli Native Forest Revival',
      views: 1248,
    ),
    BlogPost(
      id: 'blog-2',
      slug: 'green-lens-field-notes',
      title: 'Green Lens field notes from our latest drive',
      excerpt:
          'Volunteers used camera scans to identify species and verify tagged trees across the restoration site.',
      bodyText:
          'The Green Lens is designed as the app hero feature: scan a tree, identify the species, earn XP, and update your personal impact profile.\n\nDuring client review, this demo flow uses local sample results so the team can evaluate navigation, camera UX, points, badges, and the result sheet before backend integration.\n\nOnce APIs are connected, the same flow can submit image, GPS, and species metadata to the BlueDot backend.',
      mediaUrls: [
        'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2?auto=format&fit=crop&w=1200&q=80',
      ],
      author: 'Product Team',
      publishedAt: '2026-05-28T11:00:00Z',
      linkedCampaignName: 'School Miyawaki Micro-Forests',
      views: 892,
    ),
    BlogPost(
      id: 'blog-3',
      slug: 'how-volunteers-earn-impact-points',
      title: 'How volunteers earn impact points',
      excerpt:
          'A simple walkthrough of scans, RSVPs, donations, badges, and the profile journey.',
      bodyText:
          'BlueDot turns climate action into a visible personal journey. Volunteers earn points for attending plantation drives, tagging new trees, verifying existing trees, suggesting restoration sites, and supporting campaigns.\n\nThe profile page brings that work together with XP, levels, badges, recent scans, and donation impact. It gives clients a clear picture of how engagement loops will feel in the finished app.',
      mediaUrls: [
        'https://images.unsplash.com/photo-1531206715517-5c0ba140b2b8?auto=format&fit=crop&w=1200&q=80',
      ],
      author: 'Community Team',
      publishedAt: '2026-05-21T10:15:00Z',
      views: 643,
    ),
  ];

  static const events = [
    PlantationEvent(
      id: 'event-eco-park',
      title: 'Monsoon Plantation Drive at Eco Park',
      description:
          'A morning volunteer drive focused on native saplings, mulching, and QR-based attendance passes.',
      eventDate: '2026-06-21T07:30:00Z',
      eventStatus: 'Upcoming',
      siteName: 'Eco Park, Gurugram',
      maxParticipants: 80,
      attendeesCount: 46,
      treesTarget: 350,
      treesPlanted: 0,
      mediaUrls: [
        'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&w=1200&q=80',
      ],
      isPlantationDrive: true,
    ),
    PlantationEvent(
      id: 'event-lake-buffer',
      title: 'Lake Buffer Restoration Walk',
      description:
          'Survey the lake edge, identify planting zones, and help prepare soil pockets for native wetland species.',
      eventDate: '2026-07-05T08:00:00Z',
      eventStatus: 'Open',
      siteName: 'Sector 54 Lake',
      maxParticipants: 40,
      attendeesCount: 28,
      treesTarget: 120,
      treesPlanted: 35,
      mediaUrls: [
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
      ],
      isPlantationDrive: true,
    ),
  ];

  static const notifications = [
    AppNotification(
      id: 'notif-drive',
      type: AppNotificationType.drive,
      title: 'Drive starting soon 🌱',
      body: 'Monsoon Plantation Drive at Eco Park starts on 21 Jun, 7:30 AM. Tap to view your pass.',
      timeLabel: '2h ago',
      route: '/action-hub/event/event-eco-park',
    ),
    AppNotification(
      id: 'notif-badge',
      type: AppNotificationType.badge,
      title: 'New badge unlocked!',
      body: 'You earned the "Ranger" badge for tagging 15+ trees. Keep it up!',
      timeLabel: '5h ago',
      route: '/profile/badges',
    ),
    AppNotification(
      id: 'notif-certificate',
      type: AppNotificationType.certificate,
      title: 'Certificate ready 🎖️',
      body: 'Your contribution certificate for the Aravalli Spring Drive is ready to download.',
      timeLabel: 'Yesterday',
      route: '/profile/certificates',
    ),
    AppNotification(
      id: 'notif-campaign',
      type: AppNotificationType.campaign,
      title: 'Campaign nearly funded',
      body: 'Aravalli Native Forest Revival has reached 65% of its goal. Every tree counts!',
      timeLabel: '2 days ago',
      read: true,
      route: '/action-hub',
    ),
    AppNotification(
      id: 'notif-system',
      type: AppNotificationType.system,
      title: 'Welcome to BlueDot 👋',
      body: 'Scan trees, join drives, and watch your climate impact grow.',
      timeLabel: '3 days ago',
      read: true,
    ),
  ];

  static const certificates = [
    VolunteerCertificate(
      id: 'cert-aravalli-2026',
      eventTitle: 'Aravalli Spring Plantation Drive',
      siteName: 'Aravalli Biodiversity Park',
      dateLabel: '22 March 2026',
      treesPlanted: 24,
      hours: 5,
      role: 'Volunteer',
      certificateNo: 'BD-CERT-2026-00412',
    ),
    VolunteerCertificate(
      id: 'cert-yamuna-2026',
      eventTitle: 'Yamuna Floodplain Restoration',
      siteName: 'Yamuna Biodiversity Zone',
      dateLabel: '08 February 2026',
      treesPlanted: 16,
      hours: 4,
      role: 'Team Lead',
      certificateNo: 'BD-CERT-2026-00188',
    ),
    VolunteerCertificate(
      id: 'cert-school-2025',
      eventTitle: 'School Miyawaki Micro-Forest',
      siteName: 'Govt. School, Sector 12',
      dateLabel: '14 December 2025',
      treesPlanted: 9,
      hours: 3,
      role: 'Volunteer',
      certificateNo: 'BD-CERT-2025-09921',
    ),
  ];

  static const species = [
    TreeSpecies(
      id: 'neem',
      localName: 'Neem',
      scientificName: 'Azadirachta indica',
      co2OffsetFactor: 22.4,
      growthTimeYears: 20,
      imageUrls: [
        'https://images.unsplash.com/photo-1566650554919-44ec6bbe2518?auto=format&fit=crop&w=900&q=80',
      ],
      description:
          'A hardy native tree valued for shade, drought tolerance, and ecological resilience in hot Indian cities.',
      family: 'Meliaceae',
      nativeRegion: 'Indian subcontinent',
    ),
    TreeSpecies(
      id: 'peepal',
      localName: 'Peepal',
      scientificName: 'Ficus religiosa',
      co2OffsetFactor: 28.0,
      growthTimeYears: 25,
      imageUrls: [
        'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=900&q=80',
      ],
      description:
          'A large canopy species that supports birds, pollinators, and long-lived urban biodiversity pockets.',
      family: 'Moraceae',
      nativeRegion: 'South Asia',
    ),
    TreeSpecies(
      id: 'jamun',
      localName: 'Jamun',
      scientificName: 'Syzygium cumini',
      co2OffsetFactor: 24.7,
      growthTimeYears: 18,
      imageUrls: [
        'https://images.unsplash.com/photo-1473773508845-188df298d2d1?auto=format&fit=crop&w=900&q=80',
      ],
      description:
          'A fruiting native tree that brings shade, food for wildlife, and seasonal community value.',
      family: 'Myrtaceae',
      nativeRegion: 'India and Southeast Asia',
    ),
    TreeSpecies(
      id: 'arjun',
      localName: 'Arjun',
      scientificName: 'Terminalia arjuna',
      co2OffsetFactor: 26.1,
      growthTimeYears: 22,
      imageUrls: [
        'https://images.unsplash.com/photo-1518495973542-4542c06a5843?auto=format&fit=crop&w=900&q=80',
      ],
      description:
          'A strong riverbank and lake-edge species useful for green buffers, shade, and soil stability.',
      family: 'Combretaceae',
      nativeRegion: 'Indian subcontinent',
    ),
    TreeSpecies(
      id: 'banyan',
      localName: 'Banyan',
      scientificName: 'Ficus benghalensis',
      co2OffsetFactor: 31.2,
      growthTimeYears: 35,
      imageUrls: [
        'https://images.unsplash.com/photo-1511497584788-876760111969?auto=format&fit=crop&w=900&q=80',
      ],
      description:
          'A keystone canopy tree that creates habitat, deep shade, and a strong sense of place over decades.',
      family: 'Moraceae',
      nativeRegion: 'India',
    ),
    TreeSpecies(
      id: 'amaltas',
      localName: 'Amaltas',
      scientificName: 'Cassia fistula',
      co2OffsetFactor: 16.8,
      growthTimeYears: 12,
      imageUrls: [
        'https://images.unsplash.com/photo-1520412099551-62b6bafeb5bb?auto=format&fit=crop&w=900&q=80',
      ],
      description:
          'A flowering native tree known for golden summer blooms and pollinator-friendly planting.',
      family: 'Fabaceae',
      nativeRegion: 'South Asia',
    ),
  ];

  static const badges = [
    Badge(
      id: 'first-scan',
      name: 'First Scan',
      description: 'Completed your first Green Lens scan.',
      metric: 'scan',
      threshold: 1,
      points: 50,
      unlocked: true,
    ),
    Badge(
      id: 'tree-ranger',
      name: 'Tree Ranger',
      description: 'Tagged 10 trees in the field.',
      metric: 'tree',
      threshold: 10,
      points: 150,
      unlocked: true,
    ),
    Badge(
      id: 'event-starter',
      name: 'Drive Starter',
      description: 'RSVPed for your first plantation drive.',
      metric: 'event',
      threshold: 1,
      points: 80,
      unlocked: true,
    ),
    Badge(
      id: 'green-donor',
      name: 'Green Donor',
      description: 'Supported a restoration campaign.',
      metric: 'donate',
      threshold: 1,
      points: 120,
      unlocked: true,
    ),
    Badge(
      id: 'site-scout',
      name: 'Site Scout',
      description: 'Suggested a new restoration site.',
      metric: 'volunteer',
      threshold: 1,
      points: 100,
    ),
    Badge(
      id: 'canopy-builder',
      name: 'Canopy Builder',
      description: 'Tag 50 trees to unlock this badge.',
      metric: 'tree',
      threshold: 50,
      points: 500,
    ),
  ];

  static const scanHistory = [
    ScanHistoryItem(
      id: 'scan-1',
      imageUrl:
          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=500&q=80',
      taggedAt: 'Today, 09:42 AM',
      plantnetSummary: {'scientific_name': 'Azadirachta indica'},
    ),
    ScanHistoryItem(
      id: 'scan-2',
      imageUrl:
          'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=500&q=80',
      taggedAt: 'Yesterday, 05:18 PM',
      plantnetSummary: {'scientific_name': 'Ficus religiosa'},
    ),
    ScanHistoryItem(
      id: 'scan-3',
      imageUrl:
          'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=500&q=80',
      taggedAt: '29 May 2026',
      plantnetSummary: {'scientific_name': 'Terminalia arjuna'},
    ),
  ];

  static const leaderboard = [
    {'rank': 1, 'name': 'Aarav Mehta', 'points': 4280, 'trees': 63},
    {'rank': 2, 'name': 'Nisha Rao', 'points': 3860, 'trees': 55},
    {'rank': 3, 'name': 'Avishkar', 'points': 1320, 'trees': 18},
  ];

  static const scanResult = ScanResult(
    status: 'new_tag',
    message: 'Demo scan complete. This tree was added to your impact record.',
    treeId: 'demo-tree-184',
    speciesMatched: 'Azadirachta indica',
    pointsAwarded: 50,
    totalPoints: 1370,
    assetUrl:
        'https://images.unsplash.com/photo-1566650554919-44ec6bbe2518?auto=format&fit=crop&w=900&q=80',
    plantnetData: PlantNetData(
      scientificName: 'Azadirachta indica',
      commonName: 'Neem',
      score: 0.91,
      family: 'Meliaceae',
    ),
  );
}
