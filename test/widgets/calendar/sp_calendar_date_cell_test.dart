// ignore: depend_on_referenced_packages
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  group('semantics', () {
    // A grid cell is a stack of ring + tint + emoji + badge. Without one label a
    // screen reader announces those as unrelated fragments, so the cell carries a
    // single sentence and excludes the fragments (T-15 / accessibility).
    //
    // Assertions go through the semantics *tree* (`tester.binding.pipelineOwner.
    // semanticsOwner`) rather than one node's identity: `SpTapEffect` wraps the cell
    // in a `GestureDetector`, which contributes its own node above ours.
    SemanticsNode rootNode(WidgetTester tester) =>
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;

    String allLabels(SemanticsNode node) {
      final labels = <String>[];
      void visit(SemanticsNode current) {
        final label = current.getSemanticsData().label;
        if (label.isNotEmpty) labels.add(label);
        current.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(node);
      return labels.join(' | ');
    }

    testWidgets('one label carries the date, the feeling and the score', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCell(tester, feelings: ['🥳'], score: 70);

      final labels = allLabels(rootNode(tester));
      expect(labels, contains('🥳'));
      expect(labels, contains('70%'));
      expect(labels, contains('2026'), reason: 'the spoken label is a formatted date, not a bare number');

      handle.dispose();
    });

    testWidgets('an unrated day says nothing about a score', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCell(tester, feelings: ['🥳']);

      expect(allLabels(rootNode(tester)), isNot(contains('%')));

      handle.dispose();
    });

    testWidgets('the day number is announced once, through the label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCell(tester, feelings: ['🥳'], score: 70);

      final labels = allLabels(rootNode(tester));
      expect('15'.allMatches(labels).length, lessThanOrEqualTo(1),
          reason: 'excludeSemantics keeps the badge from being read as a second, bare "15"');

      handle.dispose();
    });

    testWidgets('a cell with a tap callback is announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCell(tester, feelings: ['🥳'], onTap: () {});

      var found = false;
      void visit(SemanticsNode node) {
        if (node.getSemanticsData().hasFlag(SemanticsFlag.isButton)) found = true;
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(rootNode(tester));
      expect(found, isTrue);

      handle.dispose();
    });
  });
}
