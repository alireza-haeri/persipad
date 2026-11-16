// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/monthly_score_average.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/views/calendar/trend/local_widgets/score_month_line_chart.dart';
import 'package:storypad/views/calendar/trend/local_widgets/score_monthly_average_chart.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  Future<void> pump(WidgetTester tester, Widget child, {bool settle = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );

    // Both charts animate their data in; settle so the assertions read the
    // finished layout instead of the first frame of the tween.
    if (settle) await tester.pumpAndSettle();
  }

  group('ScoreMonthLineChart', () {
    testWidgets('paints a month whose rated days are full of gaps', (tester) async {
      await pump(
        tester,
        const ScoreMonthLineChart(
          scores: {1: 20, 5: 90, 9: 40, 20: 70},
          daysInMonth: 30,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('This month'), findsOneWidget);
    });

    testWidgets('a single rated day still draws instead of failing', (tester) async {
      await pump(
        tester,
        const ScoreMonthLineChart(scores: {14: 63}, daysInMonth: 31),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('two rated days paint, in both directions', (tester) async {
      await pump(
        tester,
        const ScoreMonthLineChart(scores: {2: 10, 28: 95}, daysInMonth: 31),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: const ScoreMonthLineChart(scores: {2: 10, 28: 95}, daysInMonth: 31),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a month with no rated day says so instead of drawing zeros', (tester) async {
      await pump(
        tester,
        const ScoreMonthLineChart(scores: {}, daysInMonth: 30),
      );

      expect(find.text('No score yet'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('ScoreMonthlyAverageChart', () {
    testWidgets('draws one bar per month that has data, named in full', (tester) async {
      await pump(
        tester,
        const ScoreMonthlyAverageChart(
          months: [
            MonthlyScoreAverage(year: 2026, month: 9, average: 40.0, days: 3),
            MonthlyScoreAverage(year: 2026, month: 10, average: 75.5, days: 8),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Monthly averages'), findsOneWidget);
      expect(find.text('September'), findsOneWidget);
      expect(find.text('October'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('76'), findsOneWidget, reason: 'a 75.5 average is labelled with its rounded value');
    });

    testWidgets('bars grow in from the baseline instead of appearing at full height', (tester) async {
      await pump(
        tester,
        const ScoreMonthlyAverageChart(
          months: [MonthlyScoreAverage(year: 2026, month: 10, average: 80.0, days: 4)],
        ),
        settle: false,
      );

      final FractionallySizedBox start = tester.widget<FractionallySizedBox>(
        _barFinder(),
      );
      expect(start.heightFactor, 0.0, reason: 'the first frame is the baseline');

      await tester.pumpAndSettle();

      final FractionallySizedBox grown = tester.widget<FractionallySizedBox>(
        _barFinder(),
      );
      expect(grown.heightFactor, closeTo(0.8, 0.001), reason: '80 out of 100 of the track');
    });

    testWidgets('renders nothing when no month has data', (tester) async {
      await pump(tester, const ScoreMonthlyAverageChart(months: []));

      expect(find.text('Monthly averages'), findsNothing);
    });
  });
}

Finder _barFinder() {
  return find
      .descendant(of: find.byType(ScoreMonthlyAverageChart), matching: find.byType(FractionallySizedBox))
      .first;
}
