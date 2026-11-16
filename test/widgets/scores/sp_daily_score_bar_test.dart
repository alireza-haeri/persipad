import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/widgets/scores/sp_daily_score_bar.dart';

void main() {
  Future<Rect> pumpBar(
    WidgetTester tester, {
    required ValueChanged<int> onChanged,
    int value = 50,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300.0,
                child: SpDailyScoreBar(value: value, onChanged: onChanged),
              ),
            ),
          ),
        ),
      ),
    );

    return tester.getRect(find.byType(SpDailyScoreBar));
  }

  testWidgets('is a bar, not a number field: there is no text input at all', (tester) async {
    await pumpBar(tester, onChanged: (_) {});

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(Slider), findsNothing, reason: 'the bar is custom-painted so it can show the colour scale');
  });

  testWidgets('tapping the far end reports 100', (tester) async {
    int? reported;
    final Rect rect = await pumpBar(tester, onChanged: (value) => reported = value, value: 0);

    await tester.tapAt(Offset(rect.right - 2.0, rect.center.dy));
    await tester.pump();

    expect(reported, 100);
  });

  testWidgets('tapping the middle of the value 100 reports ~50', (tester) async {
    int? reported;
    final Rect rect = await pumpBar(tester, onChanged: (value) => reported = value, value: 100);

    await tester.tapAt(Offset(rect.center.dx, rect.center.dy));
    await tester.pump();

    expect(reported, inInclusiveRange(48, 52));
  });

  testWidgets('every reported value stays inside 0..100', (tester) async {
    final List<int> reported = [];
    final Rect rect = await pumpBar(tester, onChanged: reported.add, value: 50);

    for (double dx = rect.left - 20.0; dx <= rect.right + 20.0; dx += 10.0) {
      await tester.tapAt(Offset(dx, rect.center.dy));
      await tester.pump();
    }

    expect(reported, isNotEmpty);
    expect(reported.every((value) => value >= 0 && value <= 100), isTrue);
  });

  testWidgets('the palette is painted LTR under an explicit direction, never flipped by the tree', (
    tester,
  ) async {
    await pumpBar(tester, onChanged: (_) {}, textDirection: TextDirection.rtl);

    // The ramp's own ends are resolved for RTL in `DailyScoreScale.gradient`; this
    // inner Directionality is what keeps the framework from flipping them a second
    // time (that double flip is the bug where 100 looked red in Persian).
    final Directionality inner = tester.widget<Directionality>(
      find.descendant(of: find.byType(SpDailyScoreBar), matching: find.byType(Directionality)).first,
    );

    expect(inner.textDirection, TextDirection.ltr);
  });

  testWidgets('in RTL the scale starts on the right', (tester) async {
    int? reported;
    final Rect rect = await pumpBar(
      tester,
      onChanged: (value) => reported = value,
      value: 100,
      textDirection: TextDirection.rtl,
    );

    // The same far-right tap that means 100 in LTR means 0 in Persian.
    await tester.tapAt(Offset(rect.right - 2.0, rect.center.dy));
    await tester.pump();

    expect(reported, 0);
  });
}
