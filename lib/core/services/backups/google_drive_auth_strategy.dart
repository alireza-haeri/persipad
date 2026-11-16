import 'dart:async';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:storypad/core/objects/backup_exceptions/backup_exception.dart' as exp;
import 'package:storypad/core/objects/google_user_object.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/backups/google_desktop_oauth_service.dart';
import 'package:storypad/core/storages/base_object_storages/object_storage.dart';
import 'package:storypad/core/storages/google_user_storage.dart';
import 'package:storypad/core/storages/storage_adapters/base_storage_adapter.dart';
import 'package:storypad/core/storages/storage_adapters/secure_storage_adaptor.dart';

/// How Google Drive access tokens are obtained and renewed across supported
/// platforms (Android and Linux) via [GoogleDesktopOAuthService]'s OAuth2 flow.
///
/// Every method returns `null` (rather than throwing) for "the user has to
/// interact": that is the difference between a silent token refresh and a
/// re-sign-in, and callers surface it as `signInRequired`.
abstract class GoogleDriveAuthStrategy {
  /// The app-only scope requested — the hidden `appDataFolder`, where StoryPad
  /// stores backups.
  static const List<String> requestedScopes = [drive.DriveApi.driveAppdataScope];

  bool get isConfigured => true;

  /// Loads the stored account, renewing its token first if it has expired.
  /// Returns null when there is nothing usable (no account, or a dead token).
  Future<GoogleUserObject?> restore();

  /// Interactive sign-in. Throws [exp.AuthException] on failure.
  Future<GoogleUserObject> signIn();

  /// Interactive scope grant on top of an existing account; null when the user
  /// declined (callers then drop the account).
  Future<GoogleUserObject?> requestScope(GoogleUserObject current);

  /// Silent renewal; null means "needs a fresh interactive sign-in".
  Future<GoogleUserObject?> refresh(GoogleUserObject current);

  /// Local sign-out: forget the account, keep the grant on Google's side.
  Future<void> signOut();

  /// Revoke the grant as well (used when the user declines a scope).
  Future<void> disconnect();
}

/// Unified OAuth2 PKCE + loopback redirect strategy (Android and Linux): runs
/// the flow in the system browser / Custom Tabs via [GoogleDesktopOAuthService]
/// and keeps the resulting refresh token in secure storage.
///
/// A Google OAuth access token lives one hour, so [refresh] is what keeps
/// automatic backups working without human involvement.
class GoogleDesktopAuthStrategy implements GoogleDriveAuthStrategy {
  final GoogleOAuthClient _oauth;
  final GoogleDesktopTokenStore _tokens;
  final GoogleDesktopUserStore _users;

  GoogleDesktopAuthStrategy({
    GoogleOAuthClient? oauth,
    GoogleDesktopTokenStore? tokens,
    GoogleDesktopUserStore? users,
  }) : _oauth = oauth ?? GoogleDesktopOAuthService(),
       _tokens = tokens ?? const GoogleDesktopSecureTokenStore(),
       _users = users ?? const GoogleDesktopSecureUserStore();

  /// Whether this build knows which OAuth client it is. False means the user
  /// must be handed setup instructions instead of a browser window that Google
  /// would reject (`Invalid client_id: ""`).
  @override
  bool get isConfigured => _oauth.isConfigured;

  @override
  Future<GoogleUserObject?> restore() async {
    final user = await _users.read();
    final token = await _tokens.read();
    if (user == null || token == null) {
      if (user != null || token != null) await _forget();
      return null;
    }

    if (!token.isExpired) return user;

    final renewed = await _renew(user: user, token: token);
    if (renewed == null) {
      await _forget();
      return null;
    }

    return renewed;
  }

  @override
  Future<GoogleUserObject> signIn() async {
    try {
      final token = await _oauth.authenticate();
      final info = await _oauth.fetchUserInfo(token.accessToken);

      final user = GoogleUserObject(
        id: info.id,
        email: info.email,
        displayName: info.name,
        photoUrl: info.picture,
        accessToken: token.accessToken,
        refreshedAt: DateTime.now(),
        autoBackupEnabled: null,
      );

      await _tokens.write(token);
      await _users.write(user);
      return user;
    } on GoogleOAuthException catch (e) {
      throw exp.AuthException(
        e.message,
        e.isNotConfigured ? exp.AuthExceptionType.signInRequired : exp.AuthExceptionType.signInFailed,
        context: 'signIn',
        serviceType: BackupServiceType.google_drive,
      );
    }
  }

  /// There is no non-interactive way to add a scope to a Google grant, so this
  /// is another full sign-in — which also lets the user pick a *different*
  /// account.
  @override
  Future<GoogleUserObject?> requestScope(GoogleUserObject current) async {
    try {
      return await signIn();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<GoogleUserObject?> refresh(GoogleUserObject current) async {
    final token = await _tokens.read();
    if (token == null) return null;
    if (!token.isExpired) return current;

    return _renew(user: current, token: token);
  }

  /// Exchanges the refresh token for a new access token and persists both the
  /// new token and the account it belongs to. Null when Google says the refresh
  /// token is dead — the caller then treats it as "sign in again".
  Future<GoogleUserObject?> _renew({required GoogleUserObject user, required GoogleDesktopToken token}) async {
    final renewed = await _oauth.refresh(token: token);
    if (renewed == null) return null;

    final updated = user.copyWith(accessToken: renewed.accessToken, refreshedAt: DateTime.now());
    await _tokens.write(renewed);
    await _users.write(updated);
    return updated;
  }

  @override
  Future<void> signOut() => _forget();

  @override
  Future<void> disconnect() async {
    final token = await _tokens.read();
    if (token != null) await _oauth.revoke(token.refreshToken ?? token.accessToken);
    await _forget();
  }

  Future<void> _forget() async {
    await _tokens.clear();
    await _users.clear();
  }
}

/// Persistence seams. Kept as tiny interfaces because [GoogleDesktopAuthStrategy]
/// is the one piece of the Drive stack that can be unit-tested without a browser:
/// the tests swap in an in-memory store and a fake OAuth client.
abstract class GoogleDesktopTokenStore {
  Future<GoogleDesktopToken?> read();
  Future<void> write(GoogleDesktopToken token);
  Future<void> clear();
}

abstract class GoogleDesktopUserStore {
  Future<GoogleUserObject?> read();
  Future<void> write(GoogleUserObject user);
  Future<void> clear();
}

/// Secure storage (libsecret / Keychain / Keystore) — a refresh token is a
/// long-lived bearer credential, so it must not sit in shared preferences.
class GoogleDesktopTokenStorage extends ObjectStorage<GoogleDesktopToken> {
  @override
  Future<BaseStorageAdapter<String>> get adapter async => SecureStorageAdaptor();

  @override
  GoogleDesktopToken decode(Map<String, dynamic> json) => GoogleDesktopToken.fromJson(json);

  @override
  Map<String, dynamic> encode(GoogleDesktopToken object) => object.toJson();
}

class GoogleDesktopSecureTokenStore implements GoogleDesktopTokenStore {
  const GoogleDesktopSecureTokenStore();

  @override
  Future<GoogleDesktopToken?> read() => GoogleDesktopTokenStorage().readObject();

  @override
  Future<void> write(GoogleDesktopToken token) => GoogleDesktopTokenStorage().writeObject(token);

  @override
  Future<void> clear() => GoogleDesktopTokenStorage().remove();
}

class GoogleDesktopSecureUserStore implements GoogleDesktopUserStore {
  const GoogleDesktopSecureUserStore();

  @override
  Future<GoogleUserObject?> read() => GoogleUserStorage().readObject();

  @override
  Future<void> write(GoogleUserObject user) => GoogleUserStorage().writeObject(user);

  @override
  Future<void> clear() => GoogleUserStorage().remove();
}
