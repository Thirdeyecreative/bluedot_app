import 'package:bluedot_app/core/config/api_config.dart';
import 'package:bluedot_app/core/services/api_client.dart';
import 'package:bluedot_app/core/services/storage_service.dart';
import 'package:bluedot_app/features/auth/models/user_model.dart';
import 'package:bluedot_app/features/auth/providers/auth_provider.dart';
import 'package:bluedot_app/features/profile/pages/profile_page.dart';
import 'package:bluedot_app/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _HistoryApi extends ApiClient {
  _HistoryApi(this.scanCount) : super(StorageService());

  final int scanCount;
  final offsets = <int>[];

  @override
  Future<dynamic> get(
    String url, {
    bool requireAuth = true,
    Map<String, String>? query,
  }) async {
    expect(url, ApiConfig.scanHistory);
    expect(requireAuth, isTrue);
    expect(query?['limit'], '10');
    final skip = int.parse(query!['skip']!);
    offsets.add(skip);
    final end = (skip + 10).clamp(0, scanCount);
    return {
      'has_more': end < scanCount,
      'data': [
        for (var i = skip; i < end; i++)
          {
            'id': 'scan-${i + 1}',
            'species': {'local_name': 'Scan ${i + 1}'},
          },
      ],
    };
  }
}

class _ProfileUser extends CurrentUserNotifier {
  @override
  AppUser build() => AppUser.fromJson({
    'id': 'scan-owner',
    'phone': '+910000000000',
    'full_name': 'Scan Owner',
  });
}

class _ProfileAuth extends AuthNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<AppUser?> refreshProfile() async => null;
}

Future<void> _mountProfile(WidgetTester tester, _HistoryApi api) async {
  await tester.binding.setSurfaceSize(const Size(800, 3500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(_ProfileUser.new),
        authNotifierProvider.overrideWith(_ProfileAuth.new),
        badgesProvider.overrideWith((ref) async => []),
        apiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an exact first page has no See all control', (tester) async {
    final api = _HistoryApi(10);
    await _mountProfile(tester, api);

    expect(find.text('Scan 10'), findsOneWidget);
    expect(find.bySemanticsLabel('See all scans'), findsNothing);
    expect(api.offsets, [0]);
  });

  testWidgets('See all opens separately loaded older pages inline', (
    tester,
  ) async {
    final api = _HistoryApi(23);
    await _mountProfile(tester, api);

    expect(find.text('Scan 10'), findsOneWidget);
    expect(find.text('Scan 11'), findsNothing);
    expect(api.offsets, [0]);

    await tester.tap(find.bySemanticsLabel('See all scans'));
    await tester.pumpAndSettle();
    expect(find.text('Older Scans'), findsOneWidget);
    expect(find.text('Scan 20'), findsOneWidget);
    expect(find.text('Scan 21'), findsNothing);
    expect(api.offsets, [0, 10]);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Scan 10'), findsOneWidget);
    expect(find.text('Scan 20'), findsNothing);
    expect(find.text('Scan 23'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Next'))
          .onPressed,
      isNull,
    );
    expect(api.offsets, [0, 10, 20]);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Scan 20'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show fewer scans'));
    await tester.pumpAndSettle();
    expect(find.text('Older Scans'), findsNothing);
    expect(find.text('Scan 10'), findsOneWidget);
  });
}
