import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:storypad/core/objects/backup_exceptions/backup_exception.dart' as exp;
import 'package:storypad/core/objects/google_user_object.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/backups/google_desktop_oauth_service.dart';
import 'package:storypad/core/storages/base_object_storages/object_storage.dart';
import 'package:storypad/core/storages/google_user_storage.dart';
import 'package:storypad/core/storages/storage_adapters/base_storage_adapter.dart';
import 'package:storypad/core/storages/storage_adapters/secure_storage_adaptor.dart';

/// The part of Google Drive that differs per platform: **how an access token is
/// obtained and renewed**. Everything else (the Drive REST calls in
/// [GoogleDriveCloudService]) is identical, so the split lives here instead of
/// in a second 800-line copy of the API code.
///
/// - [GoogleSignInAuthStrategy] — Android/iOS/macOS, via `google_sign_in`, which
///   borrows the OS Google account.
/// - [GoogleDesktopAuthStrategy] — Linux, where no OS account integration exists,
///   via [GoogleDesktopOAuthService]'s loopback OAuth2 flow.
///
/// Every method returns `null` (rather than throwing) for "the user has to
/// interact": that is the difference between a silent token refresh and a
/// re-sign-in, and callers surface it as `signInRequired`.
abstract class GoogleDriveAuthStrategy {
  /// The app-only scope both strategies request — the hidden `appDataFolder`,
  /// which is exactly where the mobile build already keeps backups.
  static const List<String> requestedScopes = [drive.DriveApi.driveAppdataScope];

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

/// `google_sign_in` path — unchanged behaviour, moved out of the Drive service.
class GoogleSignInAuthStrategy implements GoogleDriveAuthStrategy {
  Completer<gsi.GoogleSignIn>? _googleServiceCompleter;

  Future<gsi.GoogleSignIn> get googleServiceInstance async {
    if (_googleServiceCompleter != null) return _googleServiceCompleter!.future;
    _googleServiceCompleter = Completer<gsi.GoogleSignIn>();

    try {
      await gsi.GoogleSignIn.instance.initialize();
      _googleServiceCompleter!.complete(gsi.GoogleSignIn.instance);
    } catch (e) {
      _googleServiceCompleter!.completeError(e);
      _googleServiceCompleter = null;
    }

    return _googleServiceCompleter!.future;
  }

  @override
  Future<GoogleUserObject?> restore() => GoogleUserStorage().readObject();

  @override
  Future<GoogleUserObject> signIn() async {
    try {
      if (!(await googleServiceInstance).supportsAuthenticate()) {
        throw exp.AuthException(
          'Platform does not support authentication',
          exp.AuthExceptionType.signInFailed,
          serviceType: BackupServiceType.google_drive,
        );
      }

      final account = await (await googleServiceInstance).authenticate(
        scopeHint: GoogleDriveAuthStrategy.requestedScopes,
      );
      final authHeaders = await account.authorizationClient.authorizationHeaders(
        GoogleDriveAuthStrategy.requestedScopes,
        promptIfNecessary: true,
      );

      return GoogleUserObject(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        accessToken: authHeaders?['Authorization']?.replaceFirst('Bearer ', ''),
        refreshedAt: DateTime.now(),
        autoBackupEnabled: null,
      );
    } catch (e) {
      if (e is exp.AuthException) rethrow;

      if (e is gsi.GoogleSignInException) {
        throw exp.AuthException(
          e.description ?? e.toString(),
          exp.AuthExceptionType.signInRequired,
          context: 'signIn',
          serviceType: BackupServiceType.google_drive,
        );
      }

      throw exp.AuthException(
        'Sign-in failed: $e',
        exp.AuthExceptionType.signInFailed,
        context: 'signIn',
        serviceType: BackupServiceType.google_drive,
      );
    }
  }

  @override
  Future<GoogleUserObject?> requestScope(GoogleUserObject current) async {
    try {
      final account = await (await googleServiceInstance).authenticate(
        scopeHint: GoogleDriveAuthStrategy.requestedScopes,
      );
      final authHeaders = await account.authorizationClient.authorizationHeaders(
        GoogleDriveAuthStrategy.requestedScopes,
        promptIfNecessary: true,
      );

      if (authHeaders == null) {
        await (await googleServiceInstance).disconnect();
        return null;
      }

      return current.copyWith(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        accessToken: authHeaders['Authorization']?.replaceFirst('Bearer ', ''),
        refreshedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<GoogleUserObject?> refresh(GoogleUserObject current) async {
    await googleServiceInstance; // ensure initialized

    try {
      final authHeaders = await (await googleServiceInstance).authorizationClient.authorizationHeaders(
        GoogleDriveAuthStrategy.requestedScopes,
        promptIfNecessary: true,
      );

      if (authHeaders == null) return null;

      return current.copyWith(
        accessToken: authHeaders['Authorization']?.replaceFirst('Bearer ', ''),
        refreshedAt: DateTime.now(),
      );
    } on exp.AuthException {
      rethrow;
    } catch (e) {
      throw exp.AuthException(
        'Reauthentication failed: $e',
        exp.AuthExceptionType.signInFailed,
        context: 'reauthenticateIfNeeded',
        serviceType: BackupServiceType.google_drive,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await (await googleServiceInstance).signOut();
  }

  @override
  Future<void> disconnect() async {
    await (await googleServiceInstance).disconnect();
  }
}

/// Linux path: no OS account, so the app runs the OAuth2 flow itself in the
/// system browser (see [GoogleDesktopOAuthService]) and keeps the resulting
/// refresh token in secure storage.
///
/// Unlike `google_sign_in`, nothing here renews a token behind the scenes — a
/// Google desktop access token lives one hour — so [refresh] is what keeps
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
  /// account, the same as the mobile flow does.
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
