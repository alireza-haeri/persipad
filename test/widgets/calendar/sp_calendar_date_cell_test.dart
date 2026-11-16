// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/widgets/calendar/sp_calendar_date_cell.dart';

/// The tile's own background: the score tint lives here, and the widget keeps one
/// stable key so the colour can fade in rather than snap.
Decoration? cellDecoration(WidgetTester tester) {
  return tester.widget<AnimatedContainer>(find.byKey(const ValueKey('calendar-cell-background'))).decoration;
}

void main() {
  setUpAll(() async => initializeDateFormatting());
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  Future<void> pumpCell(
    WidgetTester tester, {
    DateTime? date,
    List<String>? feelings,
    int? score,
    bool isDisplayMonth = true,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 47.0,
              height: 47.0,
              child: SpCalendarDateCell(
                feelingVisibleIndexNotifier: ValueNotifier<int>(0),
                date: date ?? DateTime(2026, 11, 15),
                selectedYear: 2026,
                selectedMonth: 11,
                selectedDay: null,
                feelings: feelings,
                isDisplayMonth: isDisplayMonth,
                score: score,
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a day with a feeling keeps the emoji and the day number', (tester) async {
    await pumpCell(tester, feelings: ['🥳']);

    expect(tester.takeException(), isNull);
    expect(find.text('🥳'), findsOneWidget);
    // The regression this exists for: the emoji used to *replace* the number.
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('a day with stories but no feeling shows a check and the day number', (tester) async {
    await pumpCell(tester, feelings: ['exist_but_not_set']);

    expect(tester.takeException(), isNull);
    expect(find.byType(Icon), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('a plain day is just the day number', (tester) async {
    await pumpCell(tester);

    expect(find.text('15'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('a rated day is tinted, an unrated one is not', (tester) async {
    await pumpCell(tester, score: 82);
    expect(cellDecoration(tester), isNotNull);

    await pumpCell(tester);
    expect(cellDecoration(tester), isNull);
  });

  testWidgets('a rated day with a feeling shows all three: emoji, day, tint', (tester) async {
    await pumpCell(tester, feelings: ['🥳'], score: 82);

    expect(tester.takeException(), isNull);
    expect(find.text('🥳'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(cellDecoration(tester), isNotNull);
  });

  testWidgets('tap selects, long press rates — the two gestures stay separate', (tester) async {
    int taps = 0;
    int longPresses = 0;

    await pumpCell(
      tester,
      feelings: ['🥳'],
      score: 40,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    );

    await tester.tap(find.byType(SpCalendarDateCell));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(longPresses, 0);

    await tester.longPress(find.byType(SpCalendarDateCell));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(taps, 1);
  });

  testWidgets('a day borrowed from the neighbouring month hides its content', (tester) async {
    await pumpCell(tester, feelings: ['🥳'], score: 82, isDisplayMonth: false);

    expect(find.text('15'), findsOneWidget);
    expect(find.text('🥳'), findsNothing);
  });
}
