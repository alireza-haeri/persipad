import 'package:storypad/core/services/backups/google_drive_auth_strategy.dart';
import 'package:storypad/core/services/backups/google_drive_cloud_service.dart';

/// Google Drive on Linux.
///
/// This used to be a 100-line stub whose `signIn()` always returned false,
/// because `google_sign_in` has no Linux implementation — the Connect button
/// could only ever fail. The Drive REST half was fine all along; only the way a
/// token is obtained was missing, so the stub is now just the desktop auth
/// strategy plugged into the real service (ai/DECISIONS.md D-019).
///
/// The OAuth2 flow opens the system browser, so nothing here needs a webview.
class GoogleDriveLinuxCloudService extends GoogleDriveCloudService {
  final GoogleDesktopAuthStrategy desktopAuth;

  factory GoogleDriveLinuxCloudService({GoogleDesktopAuthStrategy? auth}) {
    final strategy = auth ?? GoogleDesktopAuthStrategy();
    return GoogleDriveLinuxCloudService._(strategy, strategy);
  }

  GoogleDriveLinuxCloudService._(this.desktopAuth, GoogleDesktopAuthStrategy auth) : super(auth: auth);

  /// False until the build is given a Google OAuth "Desktop app" client id (see
  /// `bin/setup_sync`). The UI asks before opening a browser Google would
  /// reject with `invalid_client`.
  bool get isConfigured => desktopAuth.isConfigured;
}
