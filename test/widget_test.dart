import 'package:flutter_test/flutter_test.dart';
import 'package:bluedot_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: BlueDotApp(),
      ),
    );

    // Verify that the Foundation Preview screen is visible.
    expect(find.text('BlueDot Foundation'), findsOneWidget);
    expect(find.text('Typography: Outfit'), findsOneWidget);
  });
}
