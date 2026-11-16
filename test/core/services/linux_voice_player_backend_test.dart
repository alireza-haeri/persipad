import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/linux_voice_player_backend.dart';

/// `just_audio` has no Linux implementation, so voice notes on desktop are
/// played through [LinuxVoicePlayerBackend]. These cover the parts that must
/// not depend on which CLI player (if any) the machine happens to have.
void main() {
  late LinuxVoicePlayerBackend backend;
  late List<String> events;

  setUp(() {
    events = [];
    backend = LinuxVoicePlayerBackend(
      onPlayingChanged: (playing) => events.add('playing:$playing'),
      onPositionChanged: (position) => events.add('position:${position.inMilliseconds}'),
      onDurationChanged: (duration) => events.add('duration:${duration.inMilliseconds}'),
      onCompleted: () => events.add('completed'),
    );
  });

  tearDown(() => backend.dispose());

  test('refuses a file that does not exist instead of spawning a player', () async {
    final loaded = await backend.setFilePath('/definitely/not/here/voice.m4a');

    expect(loaded, isFalse);
    expect(backend.isPlaying, isFalse);
    expect(events, isNot(contains('playing:true')));
  });

  test('starts idle, at zero, on 1x', () {
    expect(backend.isPlaying, isFalse);
    expect(backend.position, Duration.zero);
    expect(backend.duration, Duration.zero);
    expect(backend.speed, 1.0);
  });

  test('playing without a loaded file does nothing', () async {
    await backend.play();

    expect(backend.isPlaying, isFalse);
    expect(events, isEmpty);
  });

  test('pausing when nothing is playing is a no-op', () async {
    await backend.pause();

    expect(backend.isPlaying, isFalse);
    expect(backend.position, Duration.zero);
  });

  test('seeking before the start clamps to zero', () async {
    await backend.seek(-const Duration(seconds: 5));

    expect(backend.position, Duration.zero);
    expect(backend.isPlaying, isFalse);
  });

  test('dispose is safe to call twice', () async {
    await backend.dispose();
    await backend.dispose();

    expect(backend.isPlaying, isFalse);
  });
}
