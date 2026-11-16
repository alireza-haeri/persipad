import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/scores/daily_score_scale.dart';
import 'package:storypad/widgets/scores/sp_score_callout.dart';

void main() {
  Future<void> pumpCallout(
    WidgetTester tester, {
    required String title,
    required String subtitle,
    required int? score,
    VoidCallback? onTap,
    TextDirection textDirection = TextDirection.ltr,
    double width = 320.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: SpScoreCallout(
                  title: title,
                  subtitle: subtitle,
                  score: score,
                  onTap: onTap ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a rated day shows the number itself, not just a colour', (tester) async {
    await pumpCallout(tester, title: '24 Aban 1405', subtitle: "Day's score", score: 72);

    expect(find.text('72'), findsOneWidget);
    expect(find.byKey(const ValueKey('score-callout-value')), findsOneWidget);
    expect(find.byKey(const ValueKey('score-callout-add')), findsNothing);
  });

  testWidgets('an unrated day invites a rating instead of showing a zero', (tester) async {
    await pumpCallout(tester, title: '24 Aban 1405', subtitle: 'No score yet', score: null);

    expect(find.byKey(const ValueKey('score-callout-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('score-callout-value')), findsNothing);
    expect(find.text('0'), findsNothing, reason: 'unrated is not the same as scored 0');
  });

  testWidgets('tapping the card opens the sheet once', (tester) async {
    int taps = 0;
    await pumpCallout(tester, title: '24 Aban 1405', subtitle: "Day's score", score: 40, onTap: () => taps++);

    await tester.tap(find.byType(SpScoreCallout));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('a long title is ellipsised instead of overflowing the row', (tester) async {
    await pumpCallout(
      tester,
      title: 'A deliberately long date label that will never fit in one line of a narrow card',
      subtitle: 'A subtitle that is also much too long for the space it is given',
      score: 12,
      width: 180.0,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SpScoreCallout), findsOneWidget);
  });

  testWidgets('lays out in Persian too', (tester) async {
    await pumpCallout(
      tester,
      title: '۲۴ آبان ۱۴۰۵',
      subtitle: 'امتیاز روز',
      score: 88,
      textDirection: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SpScoreCallout), findsOneWidget);
  });

  testWidgets('the tint follows the score, so the card reads at a glance', (tester) async {
    await pumpCallout(tester, title: 'today', subtitle: 'score', score: 100);
    final Color best = _borderColor(tester);

    await pumpCallout(tester, title: 'today', subtitle: 'score', score: 0);
    final Color worst = _borderColor(tester);

    expect(best, isNot(worst));
    expect(best, DailyScoreScale.colorOf(100).withValues(alpha: 0.3));
  });

  testWidgets('an unreachable score is clamped rather than throwing', (tester) async {
    await pumpCallout(tester, title: 'today', subtitle: 'score', score: 140);

    expect(tester.takeException(), isNull);
  });
}

/// The card's border is the accent; it is the cheapest stable read of the tint.
Color? _borderColor(WidgetTester tester) {
  final Container container = tester.widget<Container>(
    find.descendant(of: find.byType(SpScoreCallout), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.border?.top.color;
}
