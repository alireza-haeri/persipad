import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:storypad/core/services/backups/google_connectivity_service.dart';
import 'package:storypad/core/services/backups/oauth_completion_page.dart';
import 'package:storypad/core/services/logger/app_logger.dart';
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

/// The OAuth surface [GoogleDesktopAuthStrategy] depends on, so the strategy can
/// be tested with a fake instead of a browser and a live Google project.
abstract class GoogleOAuthClient {
  /// False when this build has no client id — callers must show setup
  /// instructions rather than open a page Google will reject.
  bool get isConfigured;

  Future<GoogleDesktopToken> authenticate();

  Future<GoogleDesktopToken?> refresh({required GoogleDesktopToken token});

  Future<GoogleUserInfo> fetchUserInfo(String accessToken);

  /// Best-effort grant revocation (used when the user refuses a scope).
  Future<void> revoke(String token);
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
class GoogleDesktopOAuthService implements GoogleOAuthClient {
  static const String authorizeUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String userInfoUrl = 'https://www.googleapis.com/oauth2/v3/userinfo';
  static const String revokeUrl = 'https://oauth2.googleapis.com/revoke';

  /// One tag for the whole sign-in flow, so `bin/oauth_debug` (and
  /// `adb logcat -s flutter | grep google-oauth`) shows it in order: where it
  /// started, whether the browser opened, whether the redirect came back, and
  /// where the token request stopped. Never a code, token or client secret.
  static const String logTag = 'google-oauth';

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
  final http.Client _client;

  GoogleDesktopOAuthService({
    GoogleDesktopOAuthConfig? config,
    Future<bool> Function(String url)? openBrowser,
    http.Client? client,
  }) : config = config ?? GoogleDesktopOAuthConfig.fromEnvironment(),
       _openBrowser = openBrowser ?? UrlOpenerService.launchUrlString,
       _client = client ?? http.Client();

  /// Localized by the UI before opening the browser; reset when sign-in ends.
  static OAuthCompletionText? completionPageText;

  /// Set only on Android: the button returns to the matching installed flavor.
  static String? returnToAppPackage;

  @override
  bool get isConfigured => config.isConfigured;

  /// How long a token/userinfo request may take before it is reported as a
  /// connectivity problem. An unreachable host that black-holes packets would
  /// otherwise hang for minutes with no feedback at all.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// How long the sign-in page may stay open before the flow gives up. The
  /// browser has to reach Google, the user has to pick an account, and the
  /// redirect has to come back to 127.0.0.1 — five minutes is generous on
  /// purpose, and the timer only starts once a browser was actually opened.
  static const Duration redirectTimeout = Duration(minutes: 5);

  /// Never log transport exception text: it can contain URLs and credentials.
  /// Keep a coarse failure class and operation so diagnostics remain actionable.
  Future<http.Response> _send(String operation, Future<http.Response> Function() request) async {
    try {
      return await request().timeout(requestTimeout);
    } on io.TlsException {
      _logTransportFailure(operation, 'tls');
      throw GoogleOAuthException(_offlineMessage(operation, 'tls'), error: GoogleOAuthException.offline);
    } on io.SocketException catch (e) {
      final kind = e.message.toLowerCase().contains('host lookup') ? 'dns' : 'connection';
      _logTransportFailure(operation, kind);
      throw GoogleOAuthException(_offlineMessage(operation, kind), error: GoogleOAuthException.offline);
    } on http.ClientException catch (e) {
      final message = e.message.toLowerCase();
      final kind = message.contains('host lookup') ? 'dns' : message.contains('handshake') ? 'tls' : 'connection';
      _logTransportFailure(operation, kind);
      throw GoogleOAuthException(_offlineMessage(operation, kind), error: GoogleOAuthException.offline);
    } on TimeoutException {
      _logTransportFailure(operation, 'timeout');
      throw GoogleOAuthException(_offlineMessage(operation, 'timeout'), error: GoogleOAuthException.offline);
    }
  }

  /// Logs *what* failed and *where*, never the exception text: `package:http`
  /// quotes the request URI, and a token request's URI is a credential
  /// (RULES §2). The layer is what a diagnosis needs, and the connectivity probe
  /// measures it independently.
  static void _logTransportFailure(String operation, String kind) {
    AppLogger.warning('transport failure: $operation ($kind)', tag: logTag);
  }

  static String _offlineMessage(String operation, String kind) => "Couldn't reach Google ($operation: $kind).";

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

  @override
  Future<void> revoke(String token) async {
    try {
      await _client.post(Uri.parse(revokeUrl), body: {'token': token}).timeout(requestTimeout);
    } catch (_) {
      // Revocation is a courtesy, not a requirement: the local tokens are
      // forgotten either way. A blocked network must not fail sign-out.
    }
  }

  /// Full interactive flow. Throws [GoogleOAuthException] on a missing
  /// configuration, a cancelled/denied consent, a timeout, or any HTTP failure.
  @override
  Future<GoogleDesktopToken> authenticate() async {
    if (!config.isConfigured) {
      AppLogger.warning('authenticate: no OAuth client is configured for this build', tag: logTag);
      throw const GoogleOAuthException(
        'No Google OAuth client is configured for this build.',
        error: 'not_configured',
      );
    }

    AppLogger.info('authenticate: start', tag: logTag);
    // Fire-and-forget: the probe takes a few seconds and must never delay the
    // browser, but its lines are what turn "no internet" into a named layer.
    unawaited(_logConnectivity('on start'));

    final codeVerifier = generateCodeVerifier();
    final state = generateState();

    // Port 0 = let the OS pick a free port. Google's loopback redirect treats
    // the port as a wildcard for desktop clients, so this needs no registration
    // and cannot collide with another instance.
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);

    // The listener is attached **before** the browser opens, and that order is the
    // whole point: the redirect can arrive while the tab is still loading (a warm
    // Chrome, or a Google account that is already signed in and only needs a tap).
    // When it lands before `listen` is attached, the connection sits in the accept
    // backlog unanswered — the phone shows a spinner that never finishes while this
    // method waits for a redirect the browser already sent. Moving the await below
    // `_openBrowser` also means the 5-minute timer only starts once a browser exists.
    final completer = Completer<Uri>();
    final subscription = _listenForRedirect(server, completer);
    AppLogger.info('loopback: listening on 127.0.0.1:${server.port}', tag: logTag);

    try {
      final redirectUri = 'http://127.0.0.1:${server.port}';

      final url = buildAuthorizeUrl(
        clientId: config.clientId,
        redirectUri: redirectUri,
        codeChallenge: codeChallengeFor(codeVerifier),
        state: state,
      );

      final opened = await _openBrowser(url.toString());
      AppLogger.info('browser: opened=$opened', tag: logTag);
      if (!opened) {
        throw const GoogleOAuthException(
          'Could not open a browser for the Google sign-in page.',
          error: 'browser_unavailable',
        );
      }

      final redirect = await completer.future.timeout(
        redirectTimeout,
        onTimeout: () => throw const GoogleOAuthException(
          'Timed out waiting for the Google sign-in to finish in the browser.',
          error: 'timeout',
        ),
      );

      final code = parseRedirectCode(redirect, expectedState: state);
      AppLogger.info('redirect: authorization code received (${code.length} chars, value never logged)', tag: logTag);

      return await _exchangeCode(code: code, codeVerifier: codeVerifier, redirectUri: redirectUri);
    } on GoogleOAuthException catch (error) {
      AppLogger.warning('authenticate: failed (${error.error}) — re-probing the network', tag: logTag);
      // A sign-in fails precisely when the network is the suspect, so the probe is
      // repeated *after* the failure: it shows the state at the moment it broke,
      // not only what it was when the browser opened.
      unawaited(_logConnectivity('after failure'));
      rethrow;
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  /// Answers every loopback request until the redirect with a `code` (or an
  /// `error`) arrives, then completes [completer].
  ///
  /// Nothing secret is logged: whether the query had a code is useful when the
  /// flow appears stuck, the code itself is a credential (RULES §2).
  StreamSubscription<io.HttpRequest> _listenForRedirect(io.HttpServer server, Completer<Uri> completer) {
    return server.listen((request) async {
      final hasCode = request.uri.queryParameters.containsKey('code');
      final hasError = request.uri.queryParameters.containsKey('error');
      AppLogger.info(
        'loopback: request (code: $hasCode, error: $hasError, alreadyCompleted: ${completer.isCompleted})',
        tag: logTag,
      );

      request.response
        ..statusCode = io.HttpStatus.ok
        ..headers.contentType = io.ContentType.html
        ..write(_completionPage(authorizationReceived: hasCode && !hasError));
      await request.response.close();

      // Browsers ask for /favicon.ico unprompted; that must not consume the code.
      if ((hasCode || hasError) && !completer.isCompleted) completer.complete(request.uri);
    });
  }

  /// The probe that is currently running, if any.
  ///
  /// A sign-in starts a probe and a *failing* sign-in queues another one; without
  /// this chain the two would interleave their lines and make the log unreadable —
  /// and the post-failure probe would report an older state than it claims.
  static Future<void>? _probeInFlight;

  /// Logs one four-layer probe per Google host. Never throws: a diagnostic that
  /// can break the flow it is diagnosing is worse than no diagnostic.
  static Future<void> _logConnectivity(String phase) async {
    final previous = _probeInFlight;
    final current = _runProbes(phase, previous);
    _probeInFlight = current;
    try {
      await current;
    } finally {
      if (identical(_probeInFlight, current)) _probeInFlight = null;
    }
  }

  static Future<void> _runProbes(String phase, Future<void>? previous) async {
    // A probe the caller never awaited can still fail; that must not kill this one.
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // ignore
      }
    }

    for (final host in GoogleConnectivityService.hosts) {
      try {
        final result = await GoogleConnectivityService.check(host: host);
        for (final step in result.steps) {
          AppLogger.info('connectivity[$phase] $host $step', tag: logTag);
        }
        AppLogger.info('connectivity[$phase] ${result.summary}', tag: logTag);
        final advice = result.advice;
        if (advice != null) AppLogger.warning('connectivity[$phase] advice: $advice', tag: logTag);
      } catch (error) {
        AppLogger.warning('connectivity[$phase] $host probe failed (${error.runtimeType})', tag: logTag);
      }
    }
  }

  /// Shown in the browser tab once the redirect lands. Receiving an authorization
  /// code is not the same as completing sign-in: token exchange and user-info
  /// requests still happen in the app, so the page must not claim that the user is
  /// signed in yet. A denied/cancelled redirect gets a distinct, truthful message.
  String _completionPage({required bool authorizationReceived}) {
    return OAuthCompletionPage.render(
      authorizationReceived: authorizationReceived,
      text: completionPageText ?? OAuthCompletionText.english,
      androidPackage: returnToAppPackage,
    );
  }

  Future<GoogleDesktopToken> _exchangeCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final response = await _send(
      'token exchange',
      () => _client.post(
        Uri.parse(tokenUrl),
        body: {
          'code': code,
          'client_id': config.clientId,
          'client_secret': config.clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': codeVerifier,
        },
      ),
    );

    AppLogger.info('exchange: HTTP ${response.statusCode}', tag: logTag);
    return parseTokenResponse(response);
  }

  /// Silent renewal — no browser, no user. Returns null only when Google says
  /// the refresh token itself is dead (`invalid_grant`), so callers can tell
  /// "needs a new interactive sign-in" apart from a transient failure.
  @override
  Future<GoogleDesktopToken?> refresh({required GoogleDesktopToken token}) async {
    final refreshToken = token.refreshToken;
    if (refreshToken == null) return null;

    final response = await _send(
      'token refresh',
      () => _client.post(
        Uri.parse(tokenUrl),
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': config.clientId,
          'client_secret': config.clientSecret,
        },
      ),
    );

    if (response.statusCode == 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['error'] == 'invalid_grant') return null;
    }

    return parseTokenResponse(response, fallbackRefreshToken: refreshToken);
  }

  /// The account's identity, used for the same footer/avatar the mobile build
  /// shows (and for `GoogleUserObject.id`, which sync state is keyed on).
  @override
  Future<GoogleUserInfo> fetchUserInfo(String accessToken) async {
    final response = await _send(
      'account info',
      () => _client.get(
        Uri.parse(userInfoUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    AppLogger.info('userinfo: HTTP ${response.statusCode}', tag: logTag);

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
  /// The device could not reach Google at all (DNS failure, no route, timeout).
  /// Distinct from every other code because the fix is on the network — or the
  /// emulator's DNS — not in the OAuth flow.
  static const String offline = 'offline';

  final String message;
  final String? error;

  const GoogleOAuthException(this.message, {this.error});

  bool get isNotConfigured => error == 'not_configured';

  bool get isOffline => error == offline;

  @override
  String toString() => 'GoogleOAuthException($error): $message';
}
