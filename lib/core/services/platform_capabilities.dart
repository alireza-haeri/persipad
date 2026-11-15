import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:storypad/core/services/backups/backup_service_type.dart';

/// Which StoryPad features can actually work on the current platform.
///
/// Linux is our primary target and also the weakest platform: several plugins
/// have no Linux implementation (`google_sign_in`, `local_auth`, IAP). Letting
/// those code paths fail silently is bad UX — in particular a "Connect" button
/// that can never sign in (see `GoogleDriveLinuxCloudService`, a stub whose
/// `signIn()` always returns false). The UI asks this class instead, and shows
/// an explanation rather than a dead button.
///
/// The pure functions take explicit platform flags so the whole matrix can be
/// unit-tested without pretending to be another OS.
class PlatformCapabilities {
  const PlatformCapabilities._();

  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Whether [type] can actually sign in and move files on a platform.
  ///
  /// - `google_drive`: backed by `google_sign_in`, which has no Linux
  ///   implementation. On Linux the registered service is a no-op stub, so the
  ///   tile must not offer a sign-in that can only fail.
  /// - `icloud`: iCloud/CloudKit only exists on Apple platforms (and the Linux
  ///   build doesn't even register the service).
  /// - `dropbox`: works through `flutter_web_auth_2`, which uses a loopback
  ///   redirect on Linux — a system browser, no embedded webview.
  /// - `nextcloud`: plain WebDAV over HTTPS, no platform code at all.
  static bool cloudSync({
    required BackupServiceType type,
    required bool isLinux,
    required bool isIOS,
    required bool isMacOS,
  }) {
    switch (type) {
      case BackupServiceType.google_drive:
        return !isLinux;
      case BackupServiceType.icloud:
        return isIOS || isMacOS;
      case BackupServiceType.dropbox:
      case BackupServiceType.nextcloud:
        return true;
    }
  }

  /// [cloudSync] for the platform we are actually running on.
  static bool cloudSyncOnThisDevice(BackupServiceType type) => cloudSync(
    type: type,
    isLinux: isLinux,
    isIOS: isIOS,
    isMacOS: isMacOS,
  );
}
