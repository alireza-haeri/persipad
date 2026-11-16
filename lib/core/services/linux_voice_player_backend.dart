import 'dart:async';
import 'dart:io';

import 'package:storypad/core/services/logger/app_logger.dart';

/// Pure-Dart voice playback adapter for Linux desktop, where `just_audio` has
/// no native implementation (`MissingPluginException` on
/// `com.ryanheise.just_audio.methods`).
///
/// Discovers an available system audio player once (`ffplay`, `mpv`, `cvlc`,
/// `gst-play-1.0`, or `paplay`) and drives it as a child process: pause is
/// `SIGSTOP` / resume is `SIGCONT` (so a pause never loses the position), and a
/// seek relaunches the player at the requested offset. Durations come from
/// `ffprobe` when it is installed, and fall back to the length stored with the
/// voice note.
///
/// No native C++ plugin and no new pub dependency: this is the reason the app
/// can play voice notes on Linux at all right now.
class LinuxVoicePlayerBackend {
  LinuxVoicePlayerBackend({
    required this.onPlayingChanged,
    required this.onPositionChanged,
    required this.onDurationChanged,
    required this.onCompleted,
  });

  final void Function(bool playing) onPlayingChanged;
  final void Function(Duration position) onPositionChanged;
  final void Function(Duration duration) onDurationChanged;
  final void Function() onCompleted;

  static _LinuxAudioTool? _cachedTool;
  static bool _probedTool = false;
  static bool? _hasFfprobe;
  static final Set<String> _warned = {};

  String? _filePath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;
  bool _playing = false;
  bool _disposed = false;

  Process? _process;
  int _generation = 0;
  Timer? _ticker;
  DateTime? _lastTickAt;

  bool get isPlaying => _playing;
  Duration get duration => _duration;
  Duration get position => _position;
  double get speed => _speed;

  /// Resolves which system CLI audio player is installed on this Linux host.
  static Future<_LinuxAudioTool?> _resolveTool() async {
    if (_probedTool) return _cachedTool;
    _probedTool = true;

    for (final candidate in _LinuxAudioTool.values) {
      if (await _commandExists(candidate.binary)) {
        _cachedTool = candidate;
        break;
      }
    }

    _hasFfprobe = await _commandExists('ffprobe');

    final tool = _cachedTool;
    if (tool != null) {
      AppLogger.d('$LinuxVoicePlayerBackend: playing voice notes with ${tool.binary}');
    } else {
      AppLogger.warning(
        '$LinuxVoicePlayerBackend: no CLI audio player found (looked for '
        '${_LinuxAudioTool.values.map((e) => e.binary).join(', ')}). '
        'Install one to hear voice notes: sudo dnf install -y ffmpeg-free',
      );
    }

    return tool;
  }

  /// `command -v` through `sh` rather than `which`, which is not installed on
  /// every Linux (and is deprecated on Fedora).
  static Future<bool> _commandExists(String binary) async {
    try {
      final result = await Process.run('sh', ['-c', r'command -v "$1"', 'sh', binary]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Validates [filePath] and probes its duration if `ffprobe` is available.
  Future<bool> setFilePath(String filePath, {Duration? fallbackDuration}) async {
    await stop();

    if (!File(filePath).existsSync()) return false;

    final tool = await _resolveTool();
    if (tool == null) return false;

    _filePath = filePath;
    _position = Duration.zero;

    if (fallbackDuration != null && fallbackDuration > Duration.zero) {
      _duration = fallbackDuration;
    }

    if (_hasFfprobe == true) {
      final probed = await _probeDuration(filePath);
      if (probed != null && probed > Duration.zero && !_disposed) {
        _duration = probed;
        onDurationChanged(_duration);
      }
    }

    return true;
  }

  Future<Duration?> _probeDuration(String filePath) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        filePath,
      ]);
      if (result.exitCode != 0) return null;

      final seconds = double.tryParse(result.stdout.toString().trim());
      if (seconds == null || seconds.isNaN || seconds <= 0) return null;

      return Duration(milliseconds: (seconds * 1000).round());
    } catch (_) {
      return null;
    }
  }

  Future<void> play() async {
    if (_disposed || _playing) return;

    final path = _filePath;
    if (path == null) return;

    // A paused player is still running, just stopped: resume it so it continues
    // from where it was instead of decoding the file again from the start.
    final pausedProcess = _process;
    if (pausedProcess != null) {
      pausedProcess.kill(ProcessSignal.sigcont);
      _resumeTicker();
      return;
    }

    final tool = await _resolveTool();
    if (tool == null || _disposed) return;

    await _killActiveProcess();
    final int runGeneration = ++_generation;

    final proc = await Process.start(
      tool.binary,
      tool.buildArgs(filePath: path, startOffset: _position, speed: _speed),
    );

    if (_disposed || runGeneration != _generation) {
      proc.kill(ProcessSignal.sigkill);
      return;
    }

    _process = proc;

    // Drain the pipes: an unread stdout would fill up and freeze the player.
    unawaited(proc.stdout.drain<void>().catchError((_) {}));
    unawaited(proc.stderr.drain<void>().catchError((_) {}));

    _resumeTicker();

    unawaited(
      proc.exitCode.then((_) {
        if (_disposed || runGeneration != _generation) return;

        _stopTicker();
        _process = null;
        _playing = false;
        _position = Duration.zero;

        onPlayingChanged(false);
        onPositionChanged(Duration.zero);
        onCompleted();
      }),
    );
  }

  Future<void> pause() async {
    if (!_playing) return;

    _position = _positionAfterElapsed();
    _stopTicker();

    // SIGSTOP, not kill: the player keeps its place, and play() continues with
    // SIGCONT. This also means pause works for players that have no seek
    // support at all (gst-play-1.0, paplay).
    _process?.kill(ProcessSignal.sigstop);

    if (!_disposed) {
      onPlayingChanged(false);
      onPositionChanged(_position);
    }
  }

  Future<void> stop() async {
    _generation++;
    _stopTicker();
    await _killActiveProcess();

    _playing = false;
    _position = Duration.zero;

    if (!_disposed) {
      onPlayingChanged(false);
      onPositionChanged(Duration.zero);
    }
  }

  Future<void> seek(Duration target) async {
    final wasPlaying = _playing;
    final tool = await _resolveTool();

    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (_duration > Duration.zero && clamped > _duration) clamped = _duration;

    await _killActiveProcess();
    _playing = false;

    if (tool != null && !tool.supportsOffset) {
      // This player cannot start mid-file, so the only honest position is 0.
      _warnOnce(
        'seek:${tool.binary}',
        '$LinuxVoicePlayerBackend: ${tool.binary} cannot start mid-file - seeking '
        'restarts the note. Install ffmpeg-free (ffplay) or mpv for scrubbing.',
      );
      clamped = Duration.zero;
    }

    _position = clamped;
    if (!_disposed) onPositionChanged(_position);

    if (wasPlaying && !_disposed) await play();
  }

  Future<void> setSpeed(double newSpeed) async {
    if (_speed == newSpeed) return;

    final tool = await _resolveTool();
    if (tool != null && !tool.supportsSpeed) {
      _warnOnce(
        'speed:${tool.binary}',
        '$LinuxVoicePlayerBackend: ${tool.binary} cannot change playback speed - '
        'staying at 1x. Install ffmpeg-free (ffplay) or mpv for speed control.',
      );
      return;
    }

    final wasPlaying = _playing;
    await _killActiveProcess();
    _playing = false;
    _speed = newSpeed;

    if (wasPlaying && !_disposed) await play();
  }

  void _resumeTicker() {
    _playing = true;
    _lastTickAt = DateTime.now();
    onPlayingChanged(true);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_disposed || !_playing) return;
      _position = _positionAfterElapsed();
      onPositionChanged(_position);
    });
  }

  /// Position [position] would have after the time elapsed since the last tick,
  /// scaled by the playback rate (`ffplay -af atempo`, `mpv --speed`, ...).
  Duration _positionAfterElapsed() {
    final now = DateTime.now();
    final last = _lastTickAt;
    _lastTickAt = now;
    if (last == null) return _position;

    final elapsedMs = (now.difference(last).inMilliseconds * _speed).round();
    final next = _position + Duration(milliseconds: elapsedMs);

    if (_duration > Duration.zero && next > _duration) return _duration;
    return next;
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _lastTickAt = null;
  }

  /// Kills the child process without touching the reported state; bumping the
  /// generation makes the exit callback of that process a no-op.
  Future<void> _killActiveProcess() async {
    final proc = _process;
    _process = null;
    _generation++;

    if (proc == null) return;

    proc.kill(ProcessSignal.sigstop);
    proc.kill(ProcessSignal.sigkill);
    // Don't leak the process object if it somehow ignores the signals.
    unawaited(proc.exitCode.catchError((_) => -1));
  }

  void _warnOnce(String key, String message) {
    if (!_warned.add(key)) return;
    AppLogger.warning(message);
  }

  Future<void> dispose() async {
    _disposed = true;
    _stopTicker();
    await _killActiveProcess();
  }
}

enum _LinuxAudioTool {
  // Order matters: the first one installed wins, and the earlier entries
  // support more (seek + speed) than the later ones.
  ffplay('ffplay', supportsOffset: true, supportsSpeed: true),
  mpv('mpv', supportsOffset: true, supportsSpeed: true),
  cvlc('cvlc', supportsOffset: true, supportsSpeed: true),
  // Ships with Fedora Workstation (gstreamer1-plugins-base-tools) but has no
  // CLI flags for a start offset or a playback rate.
  gstPlay('gst-play-1.0', supportsOffset: false, supportsSpeed: false),
  // Raw PCM to the sound server: no seek, no rate, and no m4a/AAC decoding.
  paplay('paplay', supportsOffset: false, supportsSpeed: false);

  const _LinuxAudioTool(
    this.binary, {
    required this.supportsOffset,
    required this.supportsSpeed,
  });

  final String binary;
  final bool supportsOffset;
  final bool supportsSpeed;

  List<String> buildArgs({
    required String filePath,
    required Duration startOffset,
    required double speed,
  }) {
    final offsetSec = (startOffset.inMilliseconds / 1000.0).toStringAsFixed(2);
    final bool seek = supportsOffset && startOffset > Duration.zero;
    final bool rate = supportsSpeed && speed != 1.0;

    switch (this) {
      case _LinuxAudioTool.ffplay:
        return [
          '-nodisp',
          '-autoexit',
          '-loglevel',
          'quiet',
          if (seek) ...['-ss', offsetSec],
          if (rate) ...['-af', 'atempo=$speed'],
          filePath,
        ];
      case _LinuxAudioTool.mpv:
        return [
          '--no-video',
          '--really-quiet',
          if (seek) '--start=+$offsetSec',
          if (rate) '--speed=$speed',
          filePath,
        ];
      case _LinuxAudioTool.cvlc:
        return [
          '--play-and-exit',
          '--intf',
          'dummy',
          '--quiet',
          if (seek) '--start-time=$offsetSec',
          if (rate) '--rate=$speed',
          filePath,
        ];
      case _LinuxAudioTool.gstPlay:
        return ['--no-interactive', '--quiet', filePath];
      case _LinuxAudioTool.paplay:
        return [filePath];
    }
  }
}
