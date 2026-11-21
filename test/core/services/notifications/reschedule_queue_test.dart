import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/notifications/reschedule_queue.dart';

void main() {
  test('failure is reported but the next update still runs', () async {
    final applied = <int>[];
    final queue = RescheduleQueue<int>((value, isCurrent) async {
      applied.add(value);
      if (value == 1) throw StateError('plugin failed');
    });

    await expectLater(queue.schedule(1), throwsStateError);
    await queue.schedule(2);
    expect(applied, [1, 2]);
  });

  test('updates are serial and a newer pending snapshot supersedes an older one', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final applied = <int>[];
    final queue = RescheduleQueue<int>((value, isCurrent) async {
      applied.add(value);
      if (value == 1) {
        started.complete();
        await release.future;
        expect(isCurrent(), isFalse);
      }
    });

    final first = queue.schedule(1);
    await started.future;
    final second = queue.schedule(2);
    final third = queue.schedule(3);
    release.complete();
    await Future.wait([first, second, third]);
    expect(applied, [1, 3]);
  });
}
