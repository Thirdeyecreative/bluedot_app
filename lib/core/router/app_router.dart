// ignore_for_file: unnecessary_underscores
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../features/scanner/pages/green_lens_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.value ?? false;
      final isSplash = state.matchedLocation == '/splash';
      final isAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/otp');

      if (isSplash) return null;
      if (!isLoggedIn && !isAuth) return '/login';
      if (isLoggedIn && isAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (__, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (__, _) => const LoginPage()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpPage(phone: state.extra as String),
      ),
      // Full-screen routes (no nav shell)
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
});
