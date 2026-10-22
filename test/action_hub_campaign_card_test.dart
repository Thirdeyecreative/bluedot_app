import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluedot_app/features/home/models/campaign_model.dart';
import 'package:bluedot_app/features/action_hub/pages/action_hub_page.dart';
import 'package:bluedot_app/features/home/providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Campaign Model & Action Hub Card Tests', () {
    test('Campaign model parses dates, health status, and manager correctly', () {
      final json = {
        'id': 'camp-123',
        'title': 'Mangrove Forest Restoration',
        'target_amount': 500000,
        'current_amount_raised': 250000,
        'description': '<p>Protect coastal areas with <strong>10,000 mangroves</strong>.</p>',
        'media_urls': ['https://example.com/mangrove.jpg'],
        'campaign_status': 'Active',
        'start_date': '2026-10-01T00:00:00Z',
        'end_date': '2026-12-31T00:00:00Z',
        'health_status': 'On Track',
        'project_manager_name': 'Priya Sharma',
      };

      final campaign = Campaign.fromJson(json);

      expect(campaign.id, 'camp-123');
      expect(campaign.title, 'Mangrove Forest Restoration');
      expect(campaign.targetAmount, 500000.0);
      expect(campaign.currentAmountRaised, 250000.0);
      expect(campaign.progressPercent, 0.5);
      expect(campaign.campaignStatus, 'Active');
      expect(campaign.healthStatus, 'On Track');
      expect(campaign.projectManagerName, 'Priya Sharma');
      expect(campaign.startDate, DateTime.parse('2026-10-01T00:00:00Z'));
      expect(campaign.endDate, DateTime.parse('2026-12-31T00:00:00Z'));
      expect(campaign.formattedTimeline, '1 Oct — 31 Dec 2026');
    });

    testWidgets('ActionHubPage renders campaign card with tags, timeline, and actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testCampaign = Campaign(
        id: 'camp-test',
        title: 'Western Ghats Corridor Revival',
        targetAmount: 1000000,
        currentAmountRaised: 800000,
        description: '<p>Reconnecting isolated canopy patches for <em>wildlife migration</em>.</p>',
        mediaUrls: const [],
        campaignStatus: 'Active',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 11, 30),
        healthStatus: 'On Track',
        projectManagerName: 'Vikram Seth',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campaignsProvider.overrideWith((ref) => Future.value([testCampaign])),
          ],
          child: const MaterialApp(
            home: ActionHubPage(initialTab: 0),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Western Ghats Corridor Revival'), findsOneWidget);

      // Verify Status Badge (Health Tag removed per requirements)
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('On Track'), findsNothing);
      expect(find.text('Nearly Funded'), findsOneWidget); // 80% >= 75%

      // Verify Timeline and Manager
      expect(find.text('1 Jun — 30 Nov 2026'), findsOneWidget);
      expect(find.text('Vikram Seth'), findsOneWidget);

      // Verify Clean Plain Text Narrative (stripped of HTML tags)
      expect(
        find.textContaining('Reconnecting isolated canopy patches'),
        findsOneWidget,
      );

      // Verify Financial Goals (800000 = 8.0L, 1000000 = 10.0L)
      expect(find.text('₹8.0L raised'), findsOneWidget);
      expect(find.text('of ₹10.0L goal'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Donate Now'), findsOneWidget);
    });
  });
}
