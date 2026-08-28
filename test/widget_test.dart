// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acronyms/main.dart';

void main() {
  testWidgets('searches the acronym directory', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AcronymsApp());
    await tester.pumpAndSettle();

    expect(find.text('No. 1 Air Control Centre'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1ACC');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('No. 1 Air Control Centre'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit acronym'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'Updated Air Control Centre');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Updated Air Control Centre'), findsOneWidget);
  });
}
