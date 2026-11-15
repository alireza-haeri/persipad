import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
}
