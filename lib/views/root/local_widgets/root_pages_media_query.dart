import 'package:flutter/material.dart';

/// The screen insets the pages navigator's routes see: on a big window, 88 on each side, clear of the sidebar.
///
/// The sidebar sits on the start edge — left in LTR, right in RTL — so the exact 88 replaces the safe-area
/// inset on that side and is added on the other one. Reading it as "left" in both directions pushed every
/// page clear of a sidebar that was no longer there in Persian, leaving a stray 88 gap on the wrong edge.
///
/// Set on both the padding and the view padding. Pages read either -- the view padding where they shouldn't rebuild
/// as the keyboard moves (the padding's bottom changes with it) -- so a side set on only one is lost on the screens
/// that read the other (as the story pages once lost theirs, running under the sidebar).
class RootPagesMediaQuery extends StatelessWidget {
  const RootPagesMediaQuery({
    super.key,
    required this.bigScreen,
    required this.child,
  });

  static const double sidebarInset = 88;

  final bool bigScreen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenPadding = mediaQuery.padding;

    // `maybeOf`: this widget is also pumped on its own in tests, and a missing
    // Directionality must not turn a padding calculation into an assert.
    final bool isRtl = Directionality.maybeOf(context) == TextDirection.rtl;

    final double left = bigScreen ? (isRtl ? screenPadding.left + sidebarInset : sidebarInset) : screenPadding.left;
    final double right = bigScreen ? (isRtl ? sidebarInset : screenPadding.right + sidebarInset) : screenPadding.right;

    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: screenPadding.copyWith(left: left, right: right),
        viewPadding: mediaQuery.viewPadding.copyWith(left: left, right: right),
      ),
      child: child,
    );
  }
}
