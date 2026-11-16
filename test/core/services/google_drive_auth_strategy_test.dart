import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/backup_exceptions/backup_exception.dart' as exp;
import 'package:storypad/core/objects/google_user_object.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/backups/google_desktop_oauth_service.dart';
import 'package:storypad/core/services/backups/google_drive_auth_strategy.dart';
import 'package:storypad/core/services/backups/google_drive_cloud_service.dart';

class _FakeTokenStore implements GoogleDesktopTokenStore {
  GoogleDesktopToken? token;
  int writes = 0;

  _FakeTokenStore([this.token]);

  @override
  Future<GoogleDesktopToken?> read() async => token;

  @override
  Future<void> write(GoogleDesktopToken value) async {
    token = value;
    writes++;
  }

  @override
  Future<void> clear() async => token = null;
}

class _FakeUserStore implements GoogleDesktopUserStore {
  GoogleUserObject? user;

  _FakeUserStore([this.user]);

  @override
  Future<GoogleUserObject?> read() async => user;

  @override
  Future<void> write(GoogleUserObject value) async => user = value;

  @override
  Future<void> clear() async => user = null;
}

class _FakeOAuth implements GoogleOAuthClient {
  _FakeOAuth({this.isConfigured = true, this.renewal, this.signedInToken, this.signInError});

  @override
  final bool isConfigured;

  GoogleDesktopToken? renewal;
  GoogleDesktopToken? signedInToken;
  GoogleOAuthException? signInError;

  int refreshCalls = 0;
  int authenticateCalls = 0;
  int revokeCalls = 0;

  @override
  Future<GoogleDesktopToken> authenticate() async {
    authenticateCalls++;
    if (signInError != null) throw signInError!;
    return signedInToken ?? _token(access: 'fresh-access');
  }

  @override
  Future<GoogleDesktopToken?> refresh({required GoogleDesktopToken token}) async {
    refreshCalls++;
    return renewal;
  }

  @override
  Future<GoogleUserInfo> fetchUserInfo(String accessToken) async =>
      const GoogleUserInfo(id: 'user-1', email: 'someone@example.com', name: 'Someone', picture: 'p.png');

  @override
  Future<void> revoke(String token) async => revokeCalls++;
}

GoogleDesktopToken _token({String access = 'access', bool expired = false}) => GoogleDesktopToken(
  accessToken: access,
  refreshToken: 'refresh',
  expiresAt: expired
      ? DateTime.now().subtract(const Duration(minutes: 5))
      : DateTime.now().add(const Duration(hours: 1)),
);

GoogleUserObject _user({String access = 'stored-access'}) => GoogleUserObject(
  id: 'user-1',
  email: 'someone@example.com',
  displayName: 'Someone',
  photoUrl: 'p.png',
  accessToken: access,
  refreshedAt: DateTime.now(),
  autoBackupEnabled: true,
);

void main() {
  group('GoogleDesktopAuthStrategy.restore', () {
    test('returns the stored account when its token is still valid', () async {
      final oauth = _FakeOAuth();
      final strategy = GoogleDesktopAuthStrategy(
        oauth: oauth,
        tokens: _FakeTokenStore(_token()),
        users: _FakeUserStore(_user()),
      );

      final restored = await strategy.restore();

      expect(restored?.email, 'someone@example.com');
      expect(oauth.refreshCalls, 0);
    });

    test('renews an expired token and persists the new one', () async {
      final tokens = _FakeTokenStore(_token(expired: true));
      final users = _FakeUserStore(_user());
      final oauth = _FakeOAuth(renewal: _token(access: 'renewed-access'));

      final restored = await GoogleDesktopAuthStrategy(oauth: oauth, tokens: tokens, users: users).restore();

      expect(oauth.refreshCalls, 1);
      expect(restored?.accessToken, 'renewed-access');
      expect(tokens.token?.accessToken, 'renewed-access');
      expect(users.user?.accessToken, 'renewed-access');
    });

    test('forgets everything when Google rejects the refresh token', () async {
      final tokens = _FakeTokenStore(_token(expired: true));
      final users = _FakeUserStore(_user());
      final oauth = _FakeOAuth(renewal: null);

      final restored = await GoogleDesktopAuthStrategy(oauth: oauth, tokens: tokens, users: users).restore();

      expect(restored, isNull);
      expect(tokens.token, isNull);
      expect(users.user, isNull);
    });

    test('returns null when only one of the two stored halves exists', () async {
      final strategy = GoogleDesktopAuthStrategy(
        oauth: _FakeOAuth(),
        tokens: _FakeTokenStore(),
        users: _FakeUserStore(_user()),
      );

      expect(await strategy.restore(), isNull);
    });
  });

  group('GoogleDesktopAuthStrategy.refresh', () {
    test('does not call Google while the access token is still valid', () async {
      final oauth = _FakeOAuth();
      final strategy = GoogleDesktopAuthStrategy(
        oauth: oauth,
        tokens: _FakeTokenStore(_token()),
        users: _FakeUserStore(_user()),
      );

      final refreshed = await strategy.refresh(_user());

      expect(refreshed?.accessToken, 'stored-access');
      expect(oauth.refreshCalls, 0);
    });

    test('refreshes an expired token', () async {
      final oauth = _FakeOAuth(renewal: _token(access: 'new-access'));
      final strategy = GoogleDesktopAuthStrategy(
        oauth: oauth,
        tokens: _FakeTokenStore(_token(expired: true)),
        users: _FakeUserStore(_user()),
      );

      final refreshed = await strategy.refresh(_user());

      expect(refreshed?.accessToken, 'new-access');
      expect(oauth.refreshCalls, 1);
    });

    test('returns null when there is no stored token at all', () async {
      final strategy = GoogleDesktopAuthStrategy(
        oauth: _FakeOAuth(),
        tokens: _FakeTokenStore(),
        users: _FakeUserStore(),
      );

      expect(await strategy.refresh(_user()), isNull);
    });
  });

  group('GoogleDesktopAuthStrategy.signIn', () {
    test('persists both the token and the account', () async {
      final tokens = _FakeTokenStore();
      final users = _FakeUserStore();
      final oauth = _FakeOAuth(signedInToken: _token(access: 'signed-in'));

      final user = await GoogleDesktopAuthStrategy(oauth: oauth, tokens: tokens, users: users).signIn();

      expect(user.email, 'someone@example.com');
      expect(user.accessToken, 'signed-in');
      expect(tokens.token?.accessToken, 'signed-in');
      expect(users.user?.id, 'user-1');
    });

    test('reports a missing client id as signInRequired, with the setup message intact', () async {
      final oauth = _FakeOAuth(
        isConfigured: false,
        signInError: const GoogleOAuthException('No Google OAuth client is configured.', error: 'not_configured'),
      );

      final future = GoogleDesktopAuthStrategy(
        oauth: oauth,
        tokens: _FakeTokenStore(),
        users: _FakeUserStore(),
      ).signIn();

      await expectLater(
        future,
        throwsA(
          isA<exp.AuthException>()
              .having((e) => e.type, 'type', exp.AuthExceptionType.signInRequired)
              .having((e) => e.message, 'message', contains('No Google OAuth client'))
              .having((e) => e.serviceType, 'serviceType', BackupServiceType.google_drive),
        ),
      );
    });

    test('reports a refused consent as a plain sign-in failure', () async {
      final oauth = _FakeOAuth(
        signInError: const GoogleOAuthException(
          'Google refused the authorization: access_denied',
          error: 'access_denied',
        ),
      );

      await expectLater(
        GoogleDesktopAuthStrategy(oauth: oauth, tokens: _FakeTokenStore(), users: _FakeUserStore()).signIn(),
        throwsA(isA<exp.AuthException>().having((e) => e.type, 'type', exp.AuthExceptionType.signInFailed)),
      );
    });
  });

  group('GoogleDesktopAuthStrategy.signOut / disconnect', () {
    test('signOut forgets both halves without calling Google', () async {
      final tokens = _FakeTokenStore(_token());
      final users = _FakeUserStore(_user());
      final oauth = _FakeOAuth();

      await GoogleDesktopAuthStrategy(oauth: oauth, tokens: tokens, users: users).signOut();

      expect(tokens.token, isNull);
      expect(users.user, isNull);
      expect(oauth.revokeCalls, 0);
    });

    test('disconnect revokes the grant at Google too', () async {
      final oauth = _FakeOAuth();
      final tokens = _FakeTokenStore(_token());

      await GoogleDesktopAuthStrategy(oauth: oauth, tokens: tokens, users: _FakeUserStore(_user())).disconnect();

      expect(oauth.revokeCalls, 1);
      expect(tokens.token, isNull);
    });
  });

  group('GoogleDriveCloudService', () {
    test('reports not configured when the build has no client id', () {
      final service = GoogleDriveCloudService(
        auth: GoogleDesktopAuthStrategy(oauth: _FakeOAuth(isConfigured: false)),
      );

      expect(service.isConfigured, isFalse);
    });

    test('reports configured when OAuth client id is present', () {
      final service = GoogleDriveCloudService(auth: GoogleDesktopAuthStrategy(oauth: _FakeOAuth()));

      expect(service.isConfigured, isTrue);
      expect(service.serviceType, BackupServiceType.google_drive);
    });
  });
}
