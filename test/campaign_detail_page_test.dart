import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluedot_app/features/action_hub/pages/campaign_detail_page.dart';
import 'package:bluedot_app/features/home/models/campaign_model.dart';
import 'package:bluedot_app/features/home/providers/home_provider.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

void main() {
  testWidgets('CampaignDetailPage displays WYSIWYG HTML and Donate button just above bottom nav bar', (tester) async {
    const testCampaign = Campaign(
      id: 'test-campaign-123',
      title: 'Rainforest Reforestation Initiative',
      targetAmount: 500000,
      currentAmountRaised: 250000,
      description: '<p>Protecting vulnerable wildlife through <strong>direct tree planting</strong>.</p>',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          campaignsProvider.overrideWith((ref) async => [testCampaign]),
        ],
        child: const MaterialApp(
          home: CampaignDetailPage(campaignId: 'test-campaign-123'),
        ),
      ),
    );

    // Let the FutureProvider resolve
    await tester.pumpAndSettle();

    // Verify title and progress
    expect(find.text('Rainforest Reforestation Initiative'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // Verify WYSIWYG HTML rendering
    expect(find.byType(HtmlWidget), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('direct tree planting'),
      ),
      findsOneWidget,
    );

    // Verify the Donate Now button is present
    expect(find.text('Donate Now'), findsOneWidget);

    // Verify Positioned widget geometry for the Donate Now button
    final positionedFinder = find.ancestor(
      of: find.text('Donate Now'),
      matching: find.byType(Positioned),
    );
    expect(positionedFinder, findsOneWidget);

    final Positioned positionedWidget = tester.widget(positionedFinder);
    // Button is positioned at bottom: 86 (12px above the 74px bottom nav bar)
    expect(positionedWidget.bottom, 86.0);
    expect(positionedWidget.left, 16.0);
    expect(positionedWidget.right, 16.0);
  });
}
