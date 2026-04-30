// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:worldcup2026/data/world_cup_data.dart';
import 'package:worldcup2026/main.dart';

void main() {
  testWidgets('Shows schedule screen and bottom navigation',
      (WidgetTester tester) async {
    final sampleData = WorldCupData(
      scheduleByDay: const [
        DaySchedule(
          date: 'Thursday 11th June 2026',
          matches: [
            MatchFixture(
              matchNumber: 1,
              date: 'Thursday 11th June 2026',
              time: '20:00',
              homeTeam: 'Mexico',
              awayTeam: 'South Africa',
              broadcaster: 'ITV1',
              stage: 'Group A',
              stadium: 'Estadio Azteca',
              city: 'Mexico City',
            ),
          ],
        ),
      ],
      teams: const [
        TeamInfo('Mexico', group: 'Group A'),
        TeamInfo('South Africa', group: 'Group A'),
      ],
    );

    await tester.pumpWidget(WorldCupApp(dataFuture: Future.value(sampleData)));
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('THURSDAY 11TH JUNE 2026'), findsOneWidget);
    expect(find.text('Mexico'), findsWidgets);
    expect(find.text('South Africa'), findsWidgets);
  });
}
