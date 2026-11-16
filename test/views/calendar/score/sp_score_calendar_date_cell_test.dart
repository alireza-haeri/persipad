// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/views/calendar/score/local_widgets/sp_score_calendar_date_cell.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  Future<void> pumpCell(
    WidgetTester tester, {
    required DateTime date,
    int? score,
    bool isDisplayMonth = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 56.0,
              height: 56.0,
              child: SpScoreCalendarDateCell(
                date: date,
                isDisplayMonth: isDisplayMonth,
                score: score,
                onTap: null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a rated day shows the day number and the score', (tester) async {
    await pumpCell(tester, date: DateTime(2026, 11, 15), score: 72);

    expect(find.text('15'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
  });

  testWidgets('an unrated day shows the day and nothing else — not a zero', (tester) async {
    await pumpCell(tester, date: DateTime(2026, 11, 15));

    expect(tester.takeException(), isNull);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.byType(Text), findsOneWidget, reason: 'the empty space is the message');
  });

  testWidgets('a day borrowed from the neighbouring month never shows a score', (tester) async {
    await pumpCell(tester, date: DateTime(2026, 11, 30), score: 72, isDisplayMonth: false);

    expect(find.text('30'), findsOneWidget);
    expect(find.text('72'), findsNothing);
  });

  testWidgets('extreme scores stay readable and rendered', (tester) async {
    await pumpCell(tester, date: DateTime(2026, 11, 1), score: 0);
    expect(find.text('0'), findsOneWidget);

    await pumpCell(tester, date: DateTime(2026, 11, 2), score: 100);
    expect(find.text('100'), findsOneWidget);
  });
}
