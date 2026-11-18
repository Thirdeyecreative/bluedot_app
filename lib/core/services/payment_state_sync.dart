import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/action_hub/providers/action_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/profile/pages/settings_page.dart';
import '../../features/profile/providers/leaderboard_provider.dart';
import '../../features/profile/providers/profile_provider.dart';

/// Central state synchronizer executed immediately after a successful payment
/// (such as a campaign donation, plantation event sponsorship, or micro-pledge).
///
/// Ensures all impacted Riverpod providers across the application reflect the latest
/// data without requiring an app reload:
/// - User profile XP, level, total donated & PAN
/// - Campaign funding amount, progress % & donor metrics
/// - Event drive funding, trees planted & attendance
/// - Home feed campaign banners & stats
/// - 80G tax receipt records & donation history
/// - Badges, certificates & global leaderboard rank
/// - Unread system notifications
Future<void> syncAppStateAfterPayment(
  dynamic ref, {
  String? campaignId,
  String? eventId,
}) async {
  try {
    final futures = <Future<dynamic>>[];

    // 1. User Profile & Local Identity (XP points, total donated, badges)
    if (ref is WidgetRef) {
      futures.add(ref.read(authNotifierProvider.notifier).refreshProfile());
    } else if (ref is Ref) {
      futures.add(ref.read(authNotifierProvider.notifier).refreshProfile());
    }

    // 2. Campaigns list (raised amount, progress bar, goal status)
    futures.add(ref.refresh(campaignsProvider.future));

    // 3. Events list (trees planted, participant metrics)
    futures.add(ref.refresh(eventsProvider.future));

    // 4. Home feed (top campaign hero, community stats)
    futures.add(ref.refresh(homeFeedProvider.future));

    // 5. 80G Tax Vault & Receipts ledger
    futures.add(ref.refresh(donationsProvider.future));

    // 6. User Badges & Certificates (awarded on donation thresholds)
    futures.add(ref.refresh(badgesProvider.future));
    futures.add(ref.refresh(certificatesProvider.future));

    // 7. System notifications badge
    if (ref is WidgetRef) {
      futures.add(ref.read(notificationsProvider.notifier).refresh());
    } else if (ref is Ref) {
      futures.add(ref.read(notificationsProvider.notifier).refresh());
    }

    // 8. Specific Event detail if provided
    if (eventId != null && eventId.isNotEmpty) {
      futures.add(ref.refresh(eventDetailProvider(eventId).future));
    }

    // 9. Invalidate leaderboard so next view re-ranks with new impact XP
    ref.invalidate(leaderboardProvider);

    await Future.wait(futures);
  } catch (e, stack) {
    debugPrint('[PaymentStateSync] Sync error after payment: $e\n$stack');
  }
}
