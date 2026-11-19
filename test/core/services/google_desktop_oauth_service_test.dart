import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storypad/core/services/backups/google_desktop_oauth_service.dart';

void main() {
  group('GoogleDesktopOAuthService.codeChallengeFor', () {
    test('matches the RFC 7636 appendix B test vector', () {
      // The RFC's own pair — if this drifts, Google rejects the flow with
      // invalid_grant and nobody can tell why.
      expect(
        GoogleDesktopOAuthService.codeChallengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('verifiers are url-safe and 43 chars', () {
      final verifier = GoogleDesktopOAuthService.generateCodeVerifier();
      expect(verifier.length, 43);
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(verifier), isTrue);
    });

    test('verifiers and states are unique', () {
      final verifiers = List.generate(50, (_) => GoogleDesktopOAuthService.generateCodeVerifier());
      expect(verifiers.toSet().length, verifiers.length);
      final states = List.generate(50, (_) => GoogleDesktopOAuthService.generateState());
      expect(states.toSet().length, states.length);
    });
  });

  group('GoogleDesktopOAuthService.buildAuthorizeUrl', () {
    final url = GoogleDesktopOAuthService.buildAuthorizeUrl(
      clientId: 'client-123.apps.googleusercontent.com',
      redirectUri: 'http://127.0.0.1:41234',
      codeChallenge: 'challenge',
      state: 'state-1',
    );

    test('targets Google with the loopback redirect', () {
      expect(url.host, 'accounts.google.com');
      expect(url.path, '/o/oauth2/v2/auth');
      expect(url.queryParameters['redirect_uri'], 'http://127.0.0.1:41234');
      expect(url.queryParameters['client_id'], 'client-123.apps.googleusercontent.com');
      expect(url.queryParameters['response_type'], 'code');
    });

    test('asks for an offline refresh token and PKCE', () {
      // Missing access_type=offline means sync silently stops after an hour.
      expect(url.queryParameters['access_type'], 'offline');
      expect(url.queryParameters['prompt'], contains('consent'));
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['code_challenge'], 'challenge');
      expect(url.queryParameters['state'], 'state-1');
    });

    test('requests only the appdata scope plus identity', () {
      final scopes = url.queryParameters['scope']!.split(' ');
      expect(scopes, contains('https://www.googleapis.com/auth/drive.appdata'));
      expect(scopes, contains('openid'));
      // A full `drive` scope would ask for far more than backups need.
      expect(scopes, isNot(contains('https://www.googleapis.com/auth/drive')));
    });
  });

  group('GoogleDesktopOAuthService.parseRedirectCode', () {
    test('returns the code when the state matches', () {
      final uri = Uri.parse('http://127.0.0.1:1234/?code=abc&state=xyz');
      expect(GoogleDesktopOAuthService.parseRedirectCode(uri, expectedState: 'xyz'), 'abc');
    });

    test('rejects a mismatched state (code injection by another local process)', () {
      final uri = Uri.parse('http://127.0.0.1:1234/?code=abc&state=attacker');
      expect(
        () => GoogleDesktopOAuthService.parseRedirectCode(uri, expectedState: 'xyz'),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'invalid_state')),
      );
    });

    test('surfaces a refused consent', () {
      final uri = Uri.parse('http://127.0.0.1:1234/?error=access_denied&state=xyz');
      expect(
        () => GoogleDesktopOAuthService.parseRedirectCode(uri, expectedState: 'xyz'),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'access_denied')),
      );
    });

    test('rejects a redirect with no code', () {
      final uri = Uri.parse('http://127.0.0.1:1234/?state=xyz');
      expect(
        () => GoogleDesktopOAuthService.parseRedirectCode(uri, expectedState: 'xyz'),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'no_code')),
      );
    });
  });

  group('GoogleDesktopOAuthService.parseTokenResponse', () {
    http.Response ok(Map<String, dynamic> body) => http.Response(jsonEncode(body), 200);

    test('reads the access token and expiry', () {
      final token = GoogleDesktopOAuthService.parseTokenResponse(
        ok({'access_token': 'at', 'refresh_token': 'rt', 'expires_in': 3599}),
      );

      expect(token.accessToken, 'at');
      expect(token.refreshToken, 'rt');
      expect(token.expiresAt.isAfter(DateTime.now()), isTrue);
      expect(token.isExpired, isFalse);
    });

    test('keeps the previous refresh token when Google omits it on refresh', () {
      final token = GoogleDesktopOAuthService.parseTokenResponse(
        ok({'access_token': 'at2', 'expires_in': 3599}),
        fallbackRefreshToken: 'rt-old',
      );

      expect(token.refreshToken, 'rt-old');
    });

    test('throws on a non-200', () {
      final response = http.Response('{"error":"invalid_client"}', 401);
      expect(() => GoogleDesktopOAuthService.parseTokenResponse(response), throwsA(isA<GoogleOAuthException>()));
    });

    test('throws when the body has no access token', () {
      expect(
        () => GoogleDesktopOAuthService.parseTokenResponse(ok({'expires_in': 3600})),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'no_access_token')),
      );
    });
  });

  group('GoogleDesktopToken', () {
    test('round-trips through JSON', () {
      final original = GoogleDesktopToken(
        accessToken: 'at',
        refreshToken: 'rt',
        expiresAt: DateTime.utc(2026, 11, 15, 12),
      );

      final restored = GoogleDesktopToken.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

      expect(restored.accessToken, 'at');
      expect(restored.refreshToken, 'rt');
      expect(restored.expiresAt, original.expiresAt);
    });

    test('reports a token expiring inside the safety margin as expired', () {
      final token = GoogleDesktopToken(
        accessToken: 'at',
        refreshToken: 'rt',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(token.isExpired, isTrue);
    });
  });

  group('GoogleDesktopOAuthConfig', () {
    test('is not configured when the dart-defines are empty', () {
      const config = GoogleDesktopOAuthConfig(clientId: '', clientSecret: '');
      expect(config.isConfigured, isFalse);
    });

    test('ignores whitespace-only values', () {
      const config = GoogleDesktopOAuthConfig(clientId: '  ', clientSecret: 'secret');
      expect(config.isConfigured, isFalse);
    });

    test('is configured with both values', () {
      const config = GoogleDesktopOAuthConfig(clientId: 'id', clientSecret: 'secret');
      expect(config.isConfigured, isTrue);
    });
  });

  group('GoogleDesktopOAuthService.authenticate', () {
    test('fails with a clear error instead of sending an empty client_id', () async {
      final service = GoogleDesktopOAuthService(
        config: const GoogleDesktopOAuthConfig(clientId: '', clientSecret: ''),
        openBrowser: (_) async => false,
      );

      // This is the Dropbox bug that produced `Invalid client_id: ""`: an empty
      // id was sent to the provider instead of being caught here.
      await expectLater(
        service.authenticate(),
        throwsA(isA<GoogleOAuthException>().having((e) => e.isNotConfigured, 'isNotConfigured', isTrue)),
      );
    });
  });

  // The phone bug these cover: Chrome was sent to
  // `http://127.0.0.1:<port>/?state=…&code=…` and the tab spun forever. The
  // listener used to be attached only after the "open browser" call returned, so a
  // redirect that arrived first waited in the accept backlog with nobody to serve
  // it — and a warm browser that is already signed in sends it immediately.
  group('GoogleDesktopOAuthService.authenticate loopback', () {
    const config = GoogleDesktopOAuthConfig(clientId: 'id', clientSecret: 'secret');
    final tokenBody = jsonEncode({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'expires_in': 3599,
    });

    /// Performs the redirect from *inside* the "open browser" call, exactly like a
    /// warm Chrome that is already signed in.
    ///
    /// A raw socket, not `HttpClient`: `flutter_test` installs an HttpOverrides
    /// that answers every request with 400, which would make this test lie about
    /// the very code path it is here to protect.
    Future<String> redirectFromInsideBrowser(
      String url, {
      String? overrideState,
      String? authorizationError,
    }) async {
      final authorizeUri = Uri.parse(url);
      final redirectUri = Uri.parse(authorizeUri.queryParameters['redirect_uri']!);
      final state = overrideState ?? authorizeUri.queryParameters['state']!;
      final query = authorizationError == null
          ? 'code=the-code&state=${Uri.encodeQueryComponent(state)}'
          : 'error=${Uri.encodeQueryComponent(authorizationError)}&state=${Uri.encodeQueryComponent(state)}';

      final socket = await Socket.connect(redirectUri.host, redirectUri.port);
      try {
        socket.write(
          'GET /?$query HTTP/1.1\r\n'
          'Host: ${redirectUri.host}:${redirectUri.port}\r\n'
          'Connection: close\r\n\r\n',
        );
        await socket.flush();
        return await socket.cast<List<int>>().transform(utf8.decoder).join();
      } finally {
        socket.destroy();
      }
    }

    GoogleDesktopOAuthService serviceWith(Future<bool> Function(String url) openBrowser) => GoogleDesktopOAuthService(
      config: config,
      client: MockClient((request) async => http.Response(tokenBody, 200)),
      openBrowser: openBrowser,
    );

    test('serves the redirect even when it arrives before the browser call returns', () async {
      String? page;
      final service = serviceWith((url) async {
        page = await redirectFromInsideBrowser(url);
        return true;
      });

      final token = await service.authenticate();

      expect(token.accessToken, 'access-token');
      expect(token.refreshToken, 'refresh-token');
      // The tab must be answered while it is open, not when the app comes back.
      expect(page, startsWith('HTTP/1.1 200'));
      expect(page, contains('Authorization received'));
      expect(page, contains('Return to PersiPad to finish signing in.'));
      expect(page, isNot(contains('Signed in')));
    });

    test('an authorization denial is not shown as a successful sign-in', () async {
      String? page;
      final service = serviceWith((url) async {
        page = await redirectFromInsideBrowser(url, authorizationError: 'access_denied');
        return true;
      });

      await expectLater(
        service.authenticate(),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'access_denied')),
      );

      expect(page, startsWith('HTTP/1.1 200'));
      expect(page, contains('Sign-in not completed'));
      expect(page, isNot(contains('Signed in')));
    });

    test('a redirect with the wrong state is refused after being answered', () async {
      final service = serviceWith((url) async {
        await redirectFromInsideBrowser(url, overrideState: 'not-this-flow');
        return true;
      });

      await expectLater(
        service.authenticate(),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'invalid_state')),
      );
    });
  });

  // When the browser cannot reach the app's loopback server at all (a device that
  // freezes background apps, or a phone-side VPN owning the routing table), the tab
  // spins forever and the flow is a dead end. Pasting the address must finish it.
  group('GoogleDesktopOAuthService.authenticate manual fallback', () {
    const config = GoogleDesktopOAuthConfig(clientId: 'id', clientSecret: 'secret');
    final tokenBody = jsonEncode({'access_token': 'pasted-token', 'expires_in': 3599});

    tearDown(() => GoogleDesktopOAuthService.manualRedirectPrompt = null);

    GoogleDesktopOAuthService build({required void Function(String state) onOpened}) {
      return GoogleDesktopOAuthService(
        config: config,
        manualPromptDelay: Duration.zero,
        client: MockClient((request) async => http.Response(tokenBody, 200)),
        // The loopback is never contacted: this is the "browser could not reach
        // us" case, which is exactly when the fallback has to carry the flow.
        openBrowser: (url) async {
          onOpened(Uri.parse(url).queryParameters['state']!);
          return true;
        },
      );
    }

    test('a pasted address finishes the sign-in', () async {
      String? pasted;
      final service = build(onOpened: (state) => pasted = 'http://127.0.0.1:9/?code=pasted-code&state=$state');
      GoogleDesktopOAuthService.manualRedirectPrompt = (_) async => pasted;

      final token = await service.authenticate();

      expect(token.accessToken, 'pasted-token');
    });

    test('a pasted address without a code is refused with a specific error', () async {
      String? pasted;
      final service = build(onOpened: (state) => pasted = 'http://127.0.0.1:9/?state=$state');
      GoogleDesktopOAuthService.manualRedirectPrompt = (_) async => pasted;

      await expectLater(
        service.authenticate(),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'no_code')),
      );
    });

    test('a pasted address from another flow is refused by the state check', () async {
      final service = build(onOpened: (_) {});
      GoogleDesktopOAuthService.manualRedirectPrompt = (_) async => 'http://127.0.0.1:9/?code=old&state=another-flow';

      await expectLater(
        service.authenticate(),
        throwsA(isA<GoogleOAuthException>().having((e) => e.error, 'error', 'invalid_state')),
      );
    });
  });

  // The emulator bug these cover: with no working DNS the app reported
  // `ClientException with SocketException: Failed host lookup:
  // 'oauth2.googleapis.com' (OS Error: No address associated with hostname,
  // errno = 7)` verbatim, which points at the wrong thing entirely.
  group('GoogleDesktopOAuthService with no network', () {
    const config = GoogleDesktopOAuthConfig(clientId: 'id', clientSecret: 'secret');
    final token = GoogleDesktopToken(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    GoogleDesktopOAuthService serviceThatThrows(Object error) => GoogleDesktopOAuthService(
      config: config,
      openBrowser: (_) async => false,
      client: MockClient((request) async => throw error),
    );

    final Matcher isOffline = isA<GoogleOAuthException>()
        .having((e) => e.isOffline, 'isOffline', isTrue)
        .having((e) => e.isNotConfigured, 'isNotConfigured', isFalse)
        .having((e) => e.message, 'message', contains("Couldn't reach Google"));

    test('reports a dead host lookup while refreshing as offline, not as an OAuth error', () async {
      final service = serviceThatThrows(
        const SocketException(
          "Failed host lookup: 'oauth2.googleapis.com' (OS Error: No address associated with hostname, errno = 7)",
        ),
      );

      await expectLater(service.refresh(token: token), throwsA(isOffline));
    });

    test('reports a dropped connection (http.ClientException) as offline too', () async {
      final service = serviceThatThrows(http.ClientException('Connection closed before full header was received'));

      await expectLater(service.refresh(token: token), throwsA(isOffline));
    });

    test('reports an unreachable userinfo endpoint as offline as well', () async {
      final service = serviceThatThrows(const SocketException('Failed host lookup'));

      await expectLater(service.fetchUserInfo('access'), throwsA(isOffline));
    });

    test('still returns null (not an error) when Google says the refresh token is dead', () async {
      // `invalid_grant` means "sign in again" and must not be confused with a
      // transient network failure — that distinction is the whole point.
      final service = GoogleDesktopOAuthService(
        config: config,
        openBrowser: (_) async => false,
        client: MockClient((request) async => http.Response('{"error":"invalid_grant"}', 400)),
      );

      expect(await service.refresh(token: token), isNull);
    });

    test('still reports a real HTTP failure from userinfo as a userinfo error', () async {
      final service = GoogleDesktopOAuthService(
        config: config,
        openBrowser: (_) async => false,
        client: MockClient((request) async => http.Response('unauthorized', 401)),
      );

      await expectLater(
        service.fetchUserInfo('access'),
        throwsA(
          isA<GoogleOAuthException>()
              .having((e) => e.error, 'error', 'userinfo_failed')
              .having((e) => e.isOffline, 'isOffline', isFalse),
        ),
      );
    });
  });
}
