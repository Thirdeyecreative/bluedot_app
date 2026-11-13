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
    if (route != null && route.trim().isNotEmpty) {
      return route.trim();
    }

    final normalizedType = (type ?? data?['type']?.toString() ?? '').trim().toLowerCase();
    final eventId = data?['event_id']?.toString() ?? data?['eventId']?.toString();
    final campaignId = data?['campaign_id']?.toString() ?? data?['campaignId']?.toString();

    switch (normalizedType) {
      case 'drive':
      case 'drive_reminder':
      case 'event_rsvp':
      case 'event_checkin':
      case 'event_update':
        if (eventId != null && eventId.isNotEmpty) {
          return '/action-hub/event/$eventId';
        }
        return '/action-hub';
      case 'tree_tagged':
        return '/map';
      case 'badge':
      case 'badge_earned':
        return '/profile/badges';
      case 'certificate':
      case 'certificate_ready':
        return '/profile/certificates';
      case 'donation':
      case 'donation_confirmed':
        return '/profile/settings/tax-vault';
      case 'campaign':
      case 'campaign_update':
        if (campaignId != null && campaignId.isNotEmpty) {
          return '/action-hub/campaign/$campaignId';
        }
        return '/action-hub';
      case 'suggestion':
      case 'site_suggestion':
        return '/action-hub/suggest-site';
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

    // Avoid pushing a duplicate Notifications page when already viewing it.
    if (resolved == '/notifications' &&
        GoRouterState.of(context).uri.path == '/notifications') {
      return;
    }

    if (_isSupportedRoute(resolved)) {
      context.push(resolved);
      return;
    }

    debugPrint('RouteDispatcher: Unknown route received from server: $resolved');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please update your app to view this content.'),
        ),
      );
    }
  }
}

