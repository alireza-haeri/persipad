import 'dart:async';

/// Serializes notification updates, coalescing queued outdated snapshots.
///
/// A failed update is reported to its caller but never poisons later updates:
/// a plugin or permission failure must not leave the queue permanently broken,
/// because the next reminder edit is how the user recovers.
class RescheduleQueue<T> {
  RescheduleQueue(this._apply);

  final Future<void> Function(T value, bool Function() isCurrent) _apply;
  Future<void> _tail = Future<void>.value();
  int _version = 0;

  Future<void> schedule(T value) {
    final version = ++_version;
    bool isCurrent() => version == _version;
    final run = _tail.then((_) async {
      if (isCurrent()) await _apply(value, isCurrent);
    });
    // Preserve the error on [run] for its caller, but release the queue even
    // after a plugin or permission failure so the next change can retry.
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return run;
  }
}
