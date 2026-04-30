// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:worldcup2026/main.dart';

void main() {
  testWidgets('Shows schedule screen and bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WorldCupApp());
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Thursday 11th June 2026'), findsOneWidget);
    expect(find.textContaining('Mexico v South Africa'), findsOneWidget);
  });
}
