import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:storypad/core/services/url_opener_service.dart';

/// Where the desktop client credentials come from.
///
/// Google identifies an OAuth client by a `client_id` (plus, for "Desktop app"
/// clients, a `client_secret` that is *not* a real secret — Google ships it in
/// every installed app by design, exactly like Dropbox's app key). The phone
/// build avoids this question entirely because `google_sign_in` borrows the OS
/// account: Play Services already knows which app is asking. A Linux build has
/// no such account integration, so the app has to present its own client id.
///
/// Empty values are a *supported state*: [isConfigured] is false and the UI
/// explains how to set them up. Sending an empty `client_id` to Google (or
/// Dropbox) yields a dead end like `Invalid client_id: ""`.
class GoogleDesktopOAuthConfig {
  final String clientId;
  final String clientSecret;

  const GoogleDesktopOAuthConfig({required this.clientId, required this.clientSecret});

  bool get isConfigured => clientId.trim().isNotEmpty && clientSecret.trim().isNotEmpty;

  /// Reads the `--dart-define`s that `bin/dev` passes from the (gitignored)
  /// private keys file — see `bin/setup_sync`.
  factory GoogleDesktopOAuthConfig.fromEnvironment() => const GoogleDesktopOAuthConfig(
    clientId: String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID'),
    clientSecret: String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET'),
  );
}

/// One Google account's tokens.
///
/// Deliberately a plain class with hand-written JSON instead of a
/// `json_serializable` model: adding a field to a generated model means
/// regenerating and committing `*.g.dart`, and this object gains fields
/// whenever OAuth details change.
class GoogleDesktopToken {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  const GoogleDesktopToken({required this.accessToken, required this.refreshToken, required this.expiresAt});

  /// Treat the token as stale slightly before Google does, so a backup that is
  /// in flight when it expires can still be retried with a fresh one.
  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toIso8601String(),
  };

  factory GoogleDesktopToken.fromJson(Map<String, dynamic> json) => GoogleDesktopToken(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String?,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );

  GoogleDesktopToken copyWith({String? accessToken, String? refreshToken, DateTime? expiresAt}) => GoogleDesktopToken(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
  );
}

/// Runs Google's OAuth2 authorization-code flow for **installed (desktop) apps**
/// on the loopback interface: the system browser is opened, Google redirects to
/// `http://127.0.0.1:{ephemeral port}` where a short-lived local HTTP server
/// picks the code up, and the code is exchanged for an access token plus a
/// refresh token. No embedded webview, no backend, no new dependency — the same
/// shape as [DropboxOAuthService] and the reason this file uses `dart:io`
/// directly instead of `googleapis_auth`.
///
/// Google accepts *any* loopback port for a "Desktop app" client, so unlike
/// Dropbox there is nothing to register beyond the client itself — the server
/// binds port 0 and tells Google the port it got.
class GoogleDesktopOAuthService {
  static const String authorizeUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String userInfoUrl = 'https://www.googleapis.com/oauth2/v3/userinfo';

  /// `drive.appdata` is the same scope the mobile build uses: backups live in
  /// the app's private appDataFolder, invisible in the user's Drive, so the
  /// existing `GoogleDriveCloudService` file layout is unchanged.
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/drive.appdata',
    'openid',
    'email',
    'profile',
  ];

  final GoogleDesktopOAuthConfig config;
  final Future<bool> Function(String url) _openBrowser;

  GoogleDesktopOAuthService({GoogleDesktopOAuthConfig? config, Future<bool> Function(String url)? openBrowser})
    : config = config ?? GoogleDesktopOAuthConfig.fromEnvironment(),
      _openBrowser = openBrowser ?? UrlOpenerService.launchUrlString;

  /// RFC 7636 §4.1 verifier: 43–128 chars from the unreserved set. 32 random
  /// bytes base64url-encoded is 43 chars, which is the sweet spot every
  /// implementation uses.
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// RFC 7636 §4.2 S256 challenge. Pure over its input, so it is unit-tested
  /// against the RFC's own test vector.
  static String codeChallengeFor(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Unguessable CSRF token echoed back through the redirect. Without it, any
  /// local process could hit the loopback port and inject its own code.
  static String generateState() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256))).replaceAll('=', '');
  }

  static Uri buildAuthorizeUrl({
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    List<String> scopes = scopes,
  }) {
    return Uri.parse(authorizeUrl).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': scopes.join(' '),
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
        // Without offline access Google issues an access token only, which
        // expires in an hour and cannot be renewed without another human
        // interaction — i.e. automatic backups would stop.
        'access_type': 'offline',
        // `consent` is what actually returns a refresh token on repeat
        // authorizations; `select_account` lets the user pick among accounts.
        'prompt': 'consent select_account',
        'include_granted_scopes': 'true',
      },
    );
  }

  /// Extracts the authorization code from the loopback redirect, rejecting a
  /// mismatched [expectedState] and Google's own `error=` responses.
  static String parseRedirectCode(Uri redirectUri, {required String expectedState}) {
    final error = redirectUri.queryParameters['error'];
    if (error != null) {
      throw GoogleOAuthException('Google refused the authorization: $error', error: error);
    }

    final state = redirectUri.queryParameters['state'];
    if (state != expectedState) {
      throw const GoogleOAuthException(
        'OAuth state mismatch — the redirect did not come from the request this app started.',
        error: 'invalid_state',
      );
    }

    final code = redirectUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const GoogleOAuthException('The Google redirect did not include an authorization code.', error: 'no_code');
    }

    return code;
  }

  /// Parses a token endpoint response. `expires_in` is seconds-from-now and
  /// `refresh_token` is only present on a fresh authorization (or when Google
  /// rotates it), hence [fallbackRefreshToken].
  static GoogleDesktopToken parseTokenResponse(http.Response response, {String? fallbackRefreshToken}) {
    if (response.statusCode != 200) {
      throw GoogleOAuthException(
        'Google token request failed (${response.statusCode}): ${response.body}',
        error: 'token_request_failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String?;
    if (accessToken == null) {
      throw const GoogleOAuthException('Google token response had no access_token.', error: 'no_access_token');
    }

    return GoogleDesktopToken(
      accessToken: accessToken,
      refreshToken: body['refresh_token'] as String? ?? fallbackRefreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: (body['expires_in'] as int?) ?? 3600)),
    );
  }

  /// Full interactive flow. Throws [GoogleOAuthException] on a missing
  /// configuration, a cancelled/denied consent, a timeout, or any HTTP failure.
  Future<GoogleDesktopToken> authenticate() async {
    if (!config.isConfigured) {
      throw const GoogleOAuthException(
        'No Google OAuth client is configured for this build.',
        error: 'not_configured',
      );
    }

    final codeVerifier = generateCodeVerifier();
    final state = generateState();

    // Port 0 = let the OS pick a free port. Google's loopback redirect treats
    // the port as a wildcard for desktop clients, so this needs no registration
    // and cannot collide with another instance.
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    try {
      final redirectUri = 'http://127.0.0.1:${server.port}';

      final url = buildAuthorizeUrl(
        clientId: config.clientId,
        redirectUri: redirectUri,
        codeChallenge: codeChallengeFor(codeVerifier),
        state: state,
      );

      final opened = await _openBrowser(url.toString());
      if (!opened) {
        throw const GoogleOAuthException(
          'Could not open a browser for the Google sign-in page.',
          error: 'browser_unavailable',
        );
      }

      final redirect = await _awaitRedirect(server);
      final code = parseRedirectCode(redirect, expectedState: state);

      return await _exchangeCode(code: code, codeVerifier: codeVerifier, redirectUri: redirectUri);
    } finally {
      await server.close(force: true);
    }
  }

  Future<Uri> _awaitRedirect(io.HttpServer server) async {
    final completer = Completer<Uri>();

    final subscription = server.listen((request) async {
      if (completer.isCompleted) {
        request.response.statusCode = io.HttpStatus.notFound;
        await request.response.close();
        return;
      }

      // Browsers ask for /favicon.ico unprompted; that must not consume the code.
      if (request.uri.queryParameters.containsKey('code') ||
          request.uri.queryParameters.containsKey('error')) {
        request.response
          ..statusCode = io.HttpStatus.ok
          ..headers.contentType = io.ContentType.html
          ..write(_completionPage());
        await request.response.close();
        if (!completer.isCompleted) completer.complete(request.uri);
        return;
      }

      request.response
        ..statusCode = io.HttpStatus.ok
        ..headers.contentType = io.ContentType.html
        ..write(_completionPage());
      await request.response.close();
    });

    try {
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw const GoogleOAuthException(
          'Timed out waiting for the Google sign-in to finish in the browser.',
          error: 'timeout',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  /// Shown in the browser tab once the redirect lands. Plain and unbranded on
  /// purpose: it is the only HTML this app serves.
  String _completionPage() =>
      '<!doctype html><meta charset="utf-8"><title>StoryPad</title>'
      '<body style="font-family:sans-serif;text-align:center;padding-top:4em">'
      '<h2>Signed in</h2><p>You can close this tab and return to StoryPad.</p></body>';

  Future<GoogleDesktopToken> _exchangeCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final response = await http.post(
      Uri.parse(tokenUrl),
      body: {
        'code': code,
        'client_id': config.clientId,
        'client_secret': config.clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': codeVerifier,
      },
    );

    return parseTokenResponse(response);
  }

  /// Silent renewal — no browser, no user. Returns null only when Google says
  /// the refresh token itself is dead (`invalid_grant`), so callers can tell
  /// "needs a new interactive sign-in" apart from a transient failure.
  Future<GoogleDesktopToken?> refresh({required GoogleDesktopToken token}) async {
    final refreshToken = token.refreshToken;
    if (refreshToken == null) return null;

    final response = await http.post(
      Uri.parse(tokenUrl),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': config.clientId,
        'client_secret': config.clientSecret,
      },
    );

    if (response.statusCode == 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['error'] == 'invalid_grant') return null;
    }

    return parseTokenResponse(response, fallbackRefreshToken: refreshToken);
  }

  /// The account's identity, used for the same footer/avatar the mobile build
  /// shows (and for `GoogleUserObject.id`, which sync state is keyed on).
  Future<GoogleUserInfo> fetchUserInfo(String accessToken) async {
    final response = await http.get(
      Uri.parse(userInfoUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw GoogleOAuthException(
        'Could not read the Google account (${response.statusCode}): ${response.body}',
        error: 'userinfo_failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return GoogleUserInfo(
      id: (body['sub'] ?? body['id']) as String,
      email: body['email'] as String? ?? '',
      name: body['name'] as String?,
      picture: body['picture'] as String?,
    );
  }
}

class GoogleUserInfo {
  final String id;
  final String email;
  final String? name;
  final String? picture;

  const GoogleUserInfo({required this.id, required this.email, this.name, this.picture});
}

/// Carries an OAuth `error` code so the UI can react to the specific case
/// (e.g. `not_configured` → show setup instructions instead of an alert).
class GoogleOAuthException implements Exception {
  final String message;
  final String? error;

  const GoogleOAuthException(this.message, {this.error});

  bool get isNotConfigured => error == 'not_configured';

  @override
  String toString() => 'GoogleOAuthException($error): $message';
}
