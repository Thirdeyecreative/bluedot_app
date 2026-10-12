import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluedot_app/core/widgets/app_html_view.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

void main() {
  group('AppHtmlView Tests', () {
    testWidgets('renders fallback text when html is empty or whitespace', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppHtmlView(
              html: '',
              fallbackText: 'No description provided.',
            ),
          ),
        ),
      );

      expect(find.text('No description provided.'), findsOneWidget);
    });

    testWidgets('renders fallback text when html only contains blank tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppHtmlView(
              html: '<p><br></p>',
              fallbackText: 'No description provided.',
            ),
          ),
        ),
      );

      expect(find.text('No description provided.'), findsOneWidget);
    });

    testWidgets('renders HtmlWidget for rich HTML content', (tester) async {
      const htmlSample = '''
        <h2>Project Overview</h2>
        <p>This initiative helps <strong>restore biodiversity</strong> across protected areas.</p>
        <ul>
          <li>Tree plantation</li>
          <li>Community workshops</li>
        </ul>
        <p class="ql-align-center">Visit <a href="https://bluedot.org">BlueDot</a></p>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppHtmlView(
              html: htmlSample,
            ),
          ),
        ),
      );

      expect(find.byType(HtmlWidget), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Project Overview'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('restore biodiversity'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Tree plantation'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('BlueDot'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('handles plain text by converting newlines properly', (tester) async {
      const plainText = 'First line of text\nSecond line of text';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppHtmlView(
              html: plainText,
            ),
          ),
        ),
      );

      expect(find.byType(HtmlWidget), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('First line of text'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Second line of text'),
        ),
        findsOneWidget,
      );
    });
  });
}
