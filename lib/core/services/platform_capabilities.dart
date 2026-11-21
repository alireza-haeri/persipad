import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:storypad/core/services/backups/backup_service_type.dart';

/// Which StoryPad features can actually work on the current platform.
///
/// The pure functions take explicit platform flags so the whole matrix can be
/// unit-tested without pretending to be another OS.
class PlatformCapabilities {
  const PlatformCapabilities._();

  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Whether [type] can sign in and move files on a platform.
  ///
  /// Google Drive authenticates through loopback OAuth2 across supported
  /// platforms (only depending on whether the build carries a client id,
  /// surfaced via `GoogleDriveCloudService.isConfigured`).
  static bool cloudSync({
    required BackupServiceType type,
    required bool isLinux,
    required bool isIOS,
    required bool isMacOS,
  }) {
    switch (type) {
      case BackupServiceType.google_drive:
        return true;
    }
  }

  /// Whether Firebase can be initialized on a platform.
  ///
  /// Linux does not link Firebase (`FirebaseInitializer` returns early) and
  /// `DefaultFirebaseOptions.currentPlatform` *throws* there, so nothing may read
  /// that getter on Linux — doing so crashed the app before the first frame.
  static bool firebase({required bool isLinux}) => !isLinux;

  /// [cloudSync] for the platform we are actually running on.
  static bool get firebaseOnThisDevice => firebase(isLinux: isLinux);

  /// Whether `video_player` has a native implementation on a platform.
  ///
  /// It ships Android/iOS/macOS/web backends only -- on Linux and Windows
  /// `VideoPlayerController.initialize()` throws a `MissingPluginException`
  /// over the `flutter.io/videoPlayer` channel, so callers must fall back to
  /// something else (a static tile, or opening the file externally).
  static bool videoPlayback({
    required bool isLinux,
    required bool isWindows,
  }) => !isLinux && !isWindows;

  static bool get videoPlaybackOnThisDevice => videoPlayback(isLinux: isLinux, isWindows: isWindows);

  static bool cloudSyncOnThisDevice(BackupServiceType type) => cloudSync(
    type: type,
    isLinux: isLinux,
    isIOS: isIOS,
    isMacOS: isMacOS,
  );
}
