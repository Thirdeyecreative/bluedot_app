import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluedot_app/core/theme/app_theme.dart';
import 'package:bluedot_app/core/constants/app_colors.dart';

void main() {
  testWidgets('App theme and design tokens smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: Text(
              'BlueDot',
              style: TextStyle(color: AppColors.primaryBlue),
            ),
          ),
        ),
      ),
    );

    expect(find.text('BlueDot'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
