import 'dart:convert';

/// Text comes from the app's selected locale, never from the browser locale.
class OAuthCompletionText {
  const OAuthCompletionText({
    required this.receivedTitle,
    required this.receivedDetail,
    required this.deniedTitle,
    required this.deniedDetail,
    required this.close,
    required this.returnToApp,
    required this.help,
    required this.isRtl,
  });

  final String receivedTitle;
  final String receivedDetail;
  final String deniedTitle;
  final String deniedDetail;
  final String close;
  final String returnToApp;
  final String help;
  final bool isRtl;

  static const english = OAuthCompletionText(
    receivedTitle: 'Authorization received',
    receivedDetail: 'Return to PersiPad to finish signing in.',
    deniedTitle: 'Sign-in not completed',
    deniedDetail: 'Google did not complete authorization. Return to PersiPad and try again.',
    close: 'Close this tab',
    returnToApp: 'Return to PersiPad',
    help: 'If the browser stays open, use the back button or close this tab manually.',
    isRtl: false,
  );
}

class OAuthCompletionPage {
  /// Android's intent returns to the app without carrying the OAuth response.
  /// Browsers on other platforms can refuse window.close(), so help is visible.
  static String render({
    required bool authorizationReceived,
    required OAuthCompletionText text,
    String? androidPackage,
  }) {
    const escape = HtmlEscape();
    String safe(String value) => escape.convert(value);
    final title = safe(authorizationReceived ? text.receivedTitle : text.deniedTitle);
    final detail = safe(authorizationReceived ? text.receivedDetail : text.deniedDetail);
    final help = safe(text.help);
    final isAndroid = androidPackage != null && RegExp(r'^[a-zA-Z][a-zA-Z0-9_.]*$').hasMatch(androidPackage);
    final action = isAndroid
        ? '<a class="button" href="intent://oauth-return#Intent;scheme=$androidPackage;package=$androidPackage;end">${safe(text.returnToApp)}</a>'
        : '<button class="button" type="button" onclick="window.close()">${safe(text.close)}</button>';
    final icon = authorizationReceived ? '&#10003;' : '!';
    final direction = text.isRtl ? 'rtl' : 'ltr';
    final language = text.isRtl ? 'fa' : 'en';
    return '''<!doctype html>
<html lang="$language" dir="$direction">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>PersiPad</title>
<style>
:root{color-scheme:light dark;font-family:system-ui,-apple-system,"Segoe UI",sans-serif}
*{box-sizing:border-box}
body{min-height:100vh;min-height:100dvh;margin:0;display:grid;place-items:center;padding:24px 16px;background:#f5f3fb;color:#29243b}
main{width:min(100%,440px);padding:clamp(28px,7vw,44px);border:1px solid #e8e3f1;border-radius:28px;background:#fff;box-shadow:0 18px 50px rgba(51,35,82,.09);text-align:center}
.brand{color:#76629a;font-size:.85rem;font-weight:700;letter-spacing:.08em;direction:ltr}
.icon{display:grid;place-items:center;margin:28px auto 20px;width:68px;height:68px;border-radius:22px;background:#eee8f8;color:#6a4e99;font-size:2rem;font-weight:700}
h1{font-size:clamp(1.3rem,5vw,1.6rem);line-height:1.5;margin:0 0 12px}
p{line-height:1.8;margin:0;color:#625a70}
.button{display:block;width:100%;margin:28px 0 16px;padding:15px 20px;border:0;border-radius:14px;background:#7559a3;color:#fff;font:inherit;font-weight:700;text-decoration:none;cursor:pointer}
.button:focus-visible{outline:3px solid #b79fda;outline-offset:3px}
.help{font-size:.85rem;color:#766f80}
@media(prefers-color-scheme:dark){body{background:#191620;color:#f5f0fb}main{background:#262130;border-color:#3d3549}.brand{color:#cbb4e8}.icon{background:#3a2f4b;color:#d5c1ee}p{color:#c7bfce}.help{color:#aaa1b3}.button{background:#c5a7e8;color:#251a31}}
</style>
</head>
<body><main><div class="brand">PersiPad</div><div class="icon" aria-hidden="true">$icon</div><h1>$title</h1><p>$detail</p>$action<p class="help">$help</p></main></body>
</html>''';
  }
}
