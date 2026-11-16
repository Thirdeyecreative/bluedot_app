import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Central dispatcher for notification deep links and backend-driven routes
/// (Passiton RouteDispatcher standard).
///
/// Resolves explicit `route` paths first, falls back to `type` + `data` mapping,
/// and degrades gracefully on unknown routes instead of crashing.
class RouteDispatcher {
  RouteDispatcher._();

  static const Set<String> _knownExactRoutes = {
    '/home',
    '/map',
    '/scanner',
    '/notifications',
    '/action-hub',
    '/action-hub/suggest-site',
    '/directory',
    '/profile',
    '/profile/badges',
    '/profile/leaderboard',
    '/profile/certificates',
    '/profile/edit',
    '/profile/settings',
    '/profile/settings/tax-vault',
    '/profile/settings/certificates',
    '/profile/settings/terms',
    '/profile/settings/privacy',
    '/home/blogs',
  };

  static const List<String> _knownPrefixes = [
    '/action-hub/event/',
    '/action-hub/campaign/',
    '/directory/species/',
    '/home/blog/',
  ];

  static bool _isSupportedRoute(String path) {
    final clean = path.split('?').first.trim();
    if (_knownExactRoutes.contains(clean)) return true;
    return _knownPrefixes.any(clean.startsWith);
  }

  static String? resolveRoute({
    String? route,
    String? type,
    Map<String, dynamic>? data,
  }) {
    final normalizedType = (type ?? data?['type']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final eventId =
        data?['event_id']?.toString() ?? data?['eventId']?.toString();
    final campaignId =
        data?['campaign_id']?.toString() ?? data?['campaignId']?.toString();
    final slug = data?['slug']?.toString();
    final speciesId =
        data?['species_id']?.toString() ?? data?['speciesId']?.toString();

    // If explicit route is provided
    if (route != null && route.trim().isNotEmpty) {
      final trimmed = route.trim();
      // If server sent a generic route but specific content IDs exist, prefer the deep target
      if (trimmed == '/notifications' || trimmed == '/action-hub') {
        if (eventId != null && eventId.isNotEmpty) {
          return '/action-hub/event/$eventId';
        }
        if (campaignId != null && campaignId.isNotEmpty) {
          return '/action-hub/campaign/$campaignId';
        }
      }
      return trimmed;
    }

    // Direct content fallback when IDs are in data payload
    if (eventId != null && eventId.isNotEmpty) {
      return '/action-hub/event/$eventId';
    }
    if (campaignId != null && campaignId.isNotEmpty) {
      return '/action-hub/campaign/$campaignId';
    }
    if (slug != null && slug.isNotEmpty) {
      return '/home/blog/$slug';
    }
    if (speciesId != null && speciesId.isNotEmpty) {
      return '/directory/species/$speciesId';
    }

    switch (normalizedType) {
      case 'drive':
      case 'drive_reminder':
      case 'event_rsvp':
      case 'event_checkin':
      case 'event_update':
      case 'event':
        return '/action-hub?tab=0';
      case 'campaign':
      case 'campaign_update':
      case 'cause':
        return '/action-hub?tab=1';
      case 'tree_tagged':
      case 'tree_approved':
      case 'tree':
        return '/map';
      case 'badge':
      case 'badge_earned':
      case 'badge_unlocked':
        return '/profile/badges';
      case 'certificate':
      case 'certificate_ready':
      case 'volunteer_certificate':
        return '/profile/certificates';
      case 'donation':
      case 'donation_confirmed':
      case 'receipt_80g':
      case 'tax_vault':
        return '/profile/settings/tax-vault';
      case 'suggestion':
      case 'site_suggestion':
      case 'suggestion_approved':
      case 'suggestion_rejected':
        return '/action-hub/suggest-site';
      case 'leaderboard':
      case 'impact_milestone':
      case 'xp':
        return '/profile/leaderboard';
      case 'blog':
      case 'story':
      case 'article':
        return '/home/blogs';
      case 'species':
      case 'species_discovery':
        return '/directory';
      case 'admin_broadcast':
      case 'announcement':
      default:
        return '/notifications';
    }
  }

  static void dispatch(
    BuildContext context, {
    String? route,
    String? type,
    Map<String, dynamic>? data,
  }) {
    final resolved = resolveRoute(route: route, type: type, data: data);
    if (resolved == null || resolved.isEmpty) return;

    // Avoid pushing duplicate notifications route
    if (resolved == '/notifications' &&
        GoRouterState.of(context).uri.path == '/notifications') {
      return;
    }

    if (_isSupportedRoute(resolved)) {
      try {
        context.push(resolved);
        return;
      } catch (pushErr) {
        debugPrint('RouteDispatcher: push failed ($pushErr), using go()');
        try {
          GoRouter.of(context).go(resolved);
          return;
        } catch (goErr) {
          debugPrint('RouteDispatcher: go failed ($goErr)');
        }
      }
    }

    debugPrint(
      'RouteDispatcher: Unknown route received from server: $resolved',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please update your app to view this content.'),
        ),
      );
    }
  }
}
