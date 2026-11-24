// ignore_for_file: unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/otp_page.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/navigation/main_navigation.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/home/pages/blog_detail_page.dart';
import '../../features/home/pages/all_blogs_page.dart';
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
import '../widgets/no_internet_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      // Only consider the user truly "logged in" if we have successfully fetched
      // their profile from the backend. A Supabase session alone is not enough.
      final currentUser = ref.read(currentUserProvider);
      final isLoggedIn = currentUser != null;
      
      final isSplash = state.matchedLocation == '/splash';
      final isAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/otp');
      final isLegal = state.matchedLocation == '/terms' ||
          state.matchedLocation == '/privacy';
      final isCompleteProfile = state.matchedLocation == '/complete-profile';
      final isNoInternet = state.matchedLocation == '/no-internet';

      if (isSplash || isNoInternet || isLegal) return null;

      if (!isLoggedIn) {
        return isAuth ? null : '/login';
      }
      
      // If logged in, check if profile is complete.
      // currentUser is null when the splash page hasn't fetched it yet — let it through.
      // fullName is null when the backend created a ghost user with empty name.
      final needsProfileCompletion = currentUser.fullName == null;
      
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
        path: '/no-internet',
        builder: (context, state) => const NoInternetPage(isOverlay: false),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsPage(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPage(),
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
      GoRoute(path: '/recent-scans', builder: (__, _) => const RecentScansPage()),
      GoRoute(path: '/about-bluedot', builder: (__, _) => const AboutBlueDotPage()),
      GoRoute(path: '/notifications', builder: (__, _) => const NotificationsPage()),

      StatefulShellRoute(
        builder: (_, __, navigationShell) => MainNavigationShell(navigationShell: navigationShell),
        navigatorContainerBuilder: MainNavigationShell.buildBranchContainer,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (__, _) => const HomePage(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'blogs',
                    builder: (__, _) => const AllBlogsPage(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'blog/:slug',
                    builder: (_, state) => BlogDetailPage(slug: state.pathParameters['slug']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/action-hub',
                builder: (_, state) {
                  final tabStr = state.uri.queryParameters['tab'];
                  final tab = int.tryParse(tabStr ?? '0') ?? 0;
                  return ActionHubPage(initialTab: tab);
                },
                routes: [
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'campaign/:id',
                    builder: (_, state) => CampaignDetailPage(campaignId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'event/:id',
                    builder: (_, state) => EventDetailPage(eventId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'checkin',
                        builder: (_, state) => EventCheckinPage(eventId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'suggest-site',
                    builder: (__, _) => const SuggestSitePage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/directory',
                builder: (__, _) => const DirectoryPage(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'species/:id',
                    builder: (_, state) => SpeciesDetailPage(speciesId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (__, _) => const ProfilePage(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'badges',
                    builder: (__, _) => const BadgesPage(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'leaderboard',
                    builder: (__, _) => const LeaderboardPage(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'edit',
                    builder: (__, _) => const EditProfilePage(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'certificates',
                    builder: (__, _) => const CertificatesPage(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'settings',
                    builder: (__, _) => const SettingsPage(),
                    routes: [
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'tax-vault',
                        builder: (__, _) => const TaxVaultPage(),
                      ),
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'edit',
                        builder: (__, _) => const EditProfilePage(),
                      ),
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'terms',
                        builder: (__, _) => const TermsPage(),
                      ),
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'privacy',
                        builder: (__, _) => const PrivacyPage(),
                      ),
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'certificates',
                        builder: (__, _) => const CertificatesPage(),
                      ),
                    ],
                  ),
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
