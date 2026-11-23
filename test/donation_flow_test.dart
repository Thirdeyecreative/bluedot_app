import 'package:bluedot_app/features/action_hub/models/donation_policy.dart';
import 'package:bluedot_app/features/action_hub/providers/action_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluedot_app/features/action_hub/pages/action_hub_page.dart';
import 'package:bluedot_app/features/home/models/campaign_model.dart';
import 'package:bluedot_app/features/auth/models/user_model.dart';
import 'package:bluedot_app/features/auth/providers/auth_provider.dart';
import 'package:bluedot_app/features/profile/pages/profile_page.dart';

void main() {
  group('Donation Flow & XP / Impact Tests', () {
    const testCampaign = Campaign(
      id: 'campaign-don-001',
      title: 'Mangrove Sanctuary Restoration',
      targetAmount: 500000,
      currentAmountRaised: 120000,
      description: 'Restoring critical mangrove habitat.',
    );

    test('AppUser model uses server level boundaries for progress', () {
      final json = {
        'id': 'user-123',
        'phone': '+919876543210',
        'full_name': 'Green Champion',
        'total_impact_points': 750,
        'level': 2,
        'level_title': 'Sapling',
        'level_start_xp': 500,
        'next_level_xp': 1000,
        'total_donated': 800.0,
        'pan_number': 'ABCDE1234F',
      };

      final user = AppUser.fromJson(json);
      expect(user.totalPoints, 750);
      expect(user.totalDonated, 800.0);
      expect(user.level, 2);
      expect(user.levelProgress, 0.5);
      expect(user.levelTitle, 'Sapling');
      expect(user.panNumber, 'ABCDE1234F');
    });

    testWidgets('DonationSheet uses server amounts and pre-fills registered PAN', (tester) async {
      final user = AppUser.fromJson({
        'id': 'user-123',
        'phone': '+919876543210',
        'full_name': 'Green Champion',
        'total_impact_points': 500,
        'total_donated': 800.0,
        'pan_number': 'ABCDE1234F',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            donationPolicyProvider.overrideWith((ref) async => const DonationPolicy(
              minAmount: 10,
              maxAmount: 500000,
              campaignPresets: [750, 1250],
              eventPresets: [500],
              receiptIssuanceEnabled: true,
            )),
            currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(user)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DonationSheet(campaign: testCampaign),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify campaign title
      expect(find.text('Support Campaign'), findsOneWidget);
      expect(find.text('Mangrove Sanctuary Restoration'), findsOneWidget);

      // Verify amount buttons
      expect(find.text('₹750'), findsOneWidget);
      expect(find.text('₹1250'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Since user has PAN registered, PAN field should be prefilled
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'ABCDE1234F'),
        findsOneWidget,
      );
      expect(find.text('Proceed to Pay ₹750'), findsOneWidget);
    });

    testWidgets('ProfilePage displays formatted donation (₹800 instead of ₹0.8k), XP, and 80G Vault link', (tester) async {
      final user = AppUser.fromJson({
        'id': 'user-123',
        'phone': '+919876543210',
        'full_name': 'Eco Warrior',
        'total_impact_points': 650,
        'total_donated': 800.0,
        'pan_number': 'ABCDE1234F',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(user)),
          ],
          child: const MaterialApp(
            home: ProfilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Total XP
      expect(find.text('650'), findsOneWidget);
      expect(find.text('Total XP'), findsOneWidget);

      // Verify Donated amount is formatted cleanly as ₹800 (not ₹0.8k)
      expect(find.text('₹800'), findsOneWidget);
      expect(find.text('Donated'), findsOneWidget);

      // Verify 80G Vault link is visible
      expect(find.text('80G Vault →'), findsOneWidget);
    });
  });
}

class _MockCurrentUserNotifier extends CurrentUserNotifier {
  final AppUser? _initial;
  _MockCurrentUserNotifier(this._initial);

  @override
  AppUser? build() => _initial;
}
