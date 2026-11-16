import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/widgets/sp_icons.dart';

/// The direction-aware chevrons behind the month arrows and the "opens a screen"
/// trailing icons.
///
/// They exist as helpers because every caller used to pick a literal
/// `keyboardLeft`/`keyboardRight` for "previous"/"next", which is only correct in
/// a left-to-right layout: in Persian the previous-month arrow pointed forward
/// and the two arrows read as swapped.
void main() {
  Future<(IconData, IconData)> resolve(WidgetTester tester, TextDirection direction) async {
    late IconData previous;
    late IconData next;

    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) {
            previous = SpIcons.previous(context);
            next = SpIcons.next(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    return (previous, next);
  }

  testWidgets('previous points back in reading order, next points forward', (tester) async {
    final ltr = await resolve(tester, TextDirection.ltr);
    expect(ltr.$1, SpIcons.keyboardLeft);
    expect(ltr.$2, SpIcons.keyboardRight);

    final rtl = await resolve(tester, TextDirection.rtl);
    expect(rtl.$1, SpIcons.keyboardRight);
    expect(rtl.$2, SpIcons.keyboardLeft);
  });

  testWidgets('the pair really mirrors, so an arrow is never both ways at once', (tester) async {
    final ltr = await resolve(tester, TextDirection.ltr);
    final rtl = await resolve(tester, TextDirection.rtl);

    expect(ltr.$1, isNot(ltr.$2), reason: 'back and forward must differ in LTR');
    expect(rtl.$1, isNot(rtl.$2), reason: 'back and forward must differ in RTL');
    expect(rtl.$1, ltr.$2, reason: 'RTL previous is LTR next, mirrored');
    expect(rtl.$2, ltr.$1, reason: 'RTL next is LTR previous, mirrored');
  });
}
