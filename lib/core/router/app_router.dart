// ignore_for_file: unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/otp_page.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/navigation/main_navigation.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/home/pages/blog_detail_page.dart';
import '../../features/home/pages/notifications_page.dart';
import '../../features/action_hub/pages/action_hub_page.dart';
import '../../features/action_hub/pages/event_detail_page.dart';
import '../../features/action_hub/pages/event_checkin_page.dart';
import '../../features/action_hub/pages/suggest_site_page.dart';
import '../../features/action_hub/pages/campaign_detail_page.dart';
import '../../features/directory/pages/directory_page.dart';
import '../../features/directory/pages/species_detail_page.dart';
import '../../features/map/pages/eco_garden_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/badges_page.dart';
import '../../features/profile/pages/leaderboard_page.dart';
import '../../features/profile/pages/settings_page.dart';
import '../../features/profile/pages/edit_profile_page.dart';
import '../../features/profile/pages/legal_page.dart';
import '../../features/profile/pages/certificates_page.dart';
import '../../features/auth/pages/complete_profile_page.dart';
import '../../features/scanner/pages/green_lens_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      // Only consider the user truly "logged in" if we have successfully fetched
      // their profile from the backend. A Supabase session alone is not enough.
      final currentUser = ref.read(currentUserProvider);
      final isLoggedIn = currentUser != null;
      
      final isSplash = state.matchedLocation == '/splash';
      final isAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/otp');
      final isCompleteProfile = state.matchedLocation == '/complete-profile';

      if (isSplash) return null;
      
      if (!isLoggedIn) {
        return isAuth ? null : '/login';
      }
      
      // If logged in, check if profile is complete.
      // currentUser is null when the splash page hasn't fetched it yet — let it through.
      // fullName is null when the backend created a ghost user with empty name.
      final needsProfileCompletion = currentUser != null && currentUser.fullName == null;
      
      if (needsProfileCompletion) {
        return isCompleteProfile ? null : '/complete-profile';
      }
      
      // If logged in and profile is complete, don't let them stay on auth pages or complete-profile
      if (isAuth || isCompleteProfile) return '/home';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'];
          return OtpPage(phone: phone ?? '');
        },
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfilePage(),
      ),
      GoRoute(path: '/scanner', builder: (__, _) => const GreenLensPage()),
      GoRoute(path: '/map', builder: (__, _) => const EcoGardenPage()),
      GoRoute(path: '/notifications', builder: (__, _) => const NotificationsPage()),

      ShellRoute(
        builder: (_, __, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (__, _) => const HomePage(),
            routes: [
              GoRoute(
                path: 'blog/:slug',
                builder: (_, state) => BlogDetailPage(slug: state.pathParameters['slug']!),
              ),
            ],
          ),
          GoRoute(
            path: '/action-hub',
            builder: (__, _) => const ActionHubPage(),
            routes: [
              GoRoute(
                path: 'campaign/:id',
                builder: (_, state) => CampaignDetailPage(campaignId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'event/:id',
                builder: (_, state) => EventDetailPage(eventId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'checkin',
                    builder: (_, state) => EventCheckinPage(eventId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: 'suggest-site',
                builder: (__, _) => const SuggestSitePage(),
              ),
            ],
          ),
          GoRoute(
            path: '/directory',
            builder: (__, _) => const DirectoryPage(),
            routes: [
              GoRoute(
                path: 'species/:id',
                builder: (_, state) => SpeciesDetailPage(speciesId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (__, _) => const ProfilePage(),
            routes: [
              GoRoute(path: 'badges', builder: (__, _) => const BadgesPage()),
              GoRoute(path: 'leaderboard', builder: (__, _) => const LeaderboardPage()),
              GoRoute(path: 'edit', builder: (__, _) => const EditProfilePage()),
              GoRoute(path: 'certificates', builder: (__, _) => const CertificatesPage()),
              GoRoute(
                path: 'settings',
                builder: (__, _) => const SettingsPage(),
                routes: [
                  GoRoute(path: 'tax-vault', builder: (__, _) => const TaxVaultPage()),
                  GoRoute(path: 'edit', builder: (__, _) => const EditProfilePage()),
                  GoRoute(path: 'terms', builder: (__, _) => const TermsPage()),
                  GoRoute(path: 'privacy', builder: (__, _) => const PrivacyPage()),
                  GoRoute(path: 'certificates', builder: (__, _) => const CertificatesPage()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Trigger a router refresh whenever auth state changes
  ref.listen(authStateProvider, (_, __) {
    router.refresh();
  });

  // Also refresh when currentUser changes (e.g. they complete their profile)
  ref.listen(currentUserProvider, (_, __) {
    router.refresh();
  });

  return router;
});
