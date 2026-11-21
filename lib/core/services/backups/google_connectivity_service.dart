import 'dart:async';
import 'dart:io' as io;

/// Where a Google request actually stops.
///
/// The point of this enum is that "no internet" is not a diagnosis: a device can
/// have a working connection to everything except the name `oauth2.googleapis.com`,
/// and the user then sees the same "connection lost" line whether the problem is
/// DNS, a dead TCP path, a proxy doing TLS interception, or an HTTP block. Each
/// value below names one of those layers, so the log says which.
enum GoogleReachability {
  /// DNS, TCP, TLS and HTTP all answered (an HTTP status of any kind counts).
  ok,

  /// The name does not resolve at all — wrong resolver, offline, or a VPN that
  /// swallows DNS.
  dnsFailure,

  /// The name resolves to an address a resolver should never return for a public
  /// host (198.18.0.0/15 is the usual "fake IP" pool of Clash/mihomo-style
  /// proxies, plus the private/CGNAT/loopback ranges). This is the signature of
  /// a proxy answering DNS itself: browsers hiding behind the proxy's own secure
  /// DNS still work, every other app in the device dies.
  fakeDns,

  /// A real address, but nothing accepted a connection on 443.
  tcpBlocked,

  /// TCP connected but the TLS handshake failed — a proxy intercepting traffic,
  /// a captive portal, or a broken clock.
  tlsBlocked,

  /// TLS was fine but the HTTPS request did not produce a response.
  httpBlocked,
}

/// One probe result. Immutable and printable line by line, so a support log can
/// show exactly where the connection stopped without anyone re-running it.
class GoogleConnectivityResult {
  const GoogleConnectivityResult({
    required this.verdict,
    required this.host,
    required this.addresses,
    required this.steps,
    required this.isFakeDns,
  });

  final GoogleReachability verdict;
  final String host;

  /// Resolved addresses, in the resolver's order. Empty for a DNS failure.
  final List<String> addresses;

  /// Ordered, human-readable findings ("dns: …", "tcp: …", "tls: …", "http: …"),
  /// each with how long that layer took.
  final List<String> steps;

  /// True when at least one resolved address is in a fake-IP/private range, even
  /// if the connection still succeeded through a proxy.
  final bool isFakeDns;

  bool get isOk => verdict == GoogleReachability.ok;

  /// One line for the log, safe to store: no tokens, no codes, no user data.
  String get summary =>
      'verdict=${verdict.name} host=$host addresses=${addresses.isEmpty ? 'none' : addresses.join(',')}';

  /// What the user can actually do, or null when there is nothing to fix. This
  /// is deliberately about the *device/proxy*, because no app-side retry can
  /// repair a resolver that hands out fake addresses.
  String? get advice {
    switch (verdict) {
      case GoogleReachability.ok:
        return null;
      case GoogleReachability.dnsFailure:
        return 'The device cannot resolve $host. Give the emulator/device a real resolver '
            '(bin/build_apk --install --avd=<name> --dns-server=8.8.8.8) or fix the host DNS.';
      case GoogleReachability.fakeDns:
        return 'This device resolves Google to a proxy "fake IP". Exclude Google from the proxy\'s '
            'fake-IP DNS (fake-ip-filter: ["+.googleapis.com", "+.google.com"]) or give the '
            'emulator a real resolver (--dns-server=8.8.8.8). Browsers can still work because they '
            'use their own secure DNS; apps cannot.';
      case GoogleReachability.tcpBlocked:
        return 'Nothing accepted a TCP connection to $host:443. Check the proxy/VPN routing for the '
            'emulator (a TUN device on the host is not automatically shared with the guest).';
      case GoogleReachability.tlsBlocked:
        return 'TCP works but TLS fails: a proxy is intercepting HTTPS or the device clock is wrong.';
      case GoogleReachability.httpBlocked:
        return 'TLS works but the HTTP request produced no response — retry; if it repeats, look at '
            'the proxy\'s rules for this host.';
    }
  }
}

/// Measures the four layers between this device and Google's OAuth endpoints.
///
/// Nothing here touches credentials: it opens a TCP socket, a TLS socket and one
/// anonymous HTTPS GET, and reports where the chain broke. It is meant to run
/// when a sign-in fails (and in the background when one starts), so the log
/// answers "DNS? TCP? TLS? HTTP?" instead of leaving it to guesswork.
class GoogleConnectivityService {
  GoogleConnectivityService._();

  /// The names a Google Drive sign-in touches: token exchange, userinfo/Drive API,
  /// and the consent page the browser opens.
  static const List<String> hosts = ['oauth2.googleapis.com', 'www.googleapis.com', 'accounts.google.com'];

  static const Duration defaultTimeout = Duration(seconds: 5);

  /// Probes [host] and returns where it stopped. Never throws: a probe that
  /// cannot even report is useless, so failures become a verdict.
  static Future<GoogleConnectivityResult> check({
    String host = 'oauth2.googleapis.com',
    Duration timeout = defaultTimeout,
  }) async {
    final steps = <String>[];
    var stopwatch = Stopwatch()..start();
    final addresses = <io.InternetAddress>[];

    try {
      addresses.addAll(await io.InternetAddress.lookup(host).timeout(timeout));
    } on io.SocketException catch (error) {
      steps.add('dns: failed after ${_ms(stopwatch)} (${_reason(error)})');
    } on TimeoutException {
      steps.add('dns: timed out after ${_ms(stopwatch)}');
    } catch (error) {
      steps.add('dns: failed after ${_ms(stopwatch)} (${error.runtimeType})');
    }

    if (addresses.isEmpty) {
      return GoogleConnectivityResult(
        verdict: GoogleReachability.dnsFailure,
        host: host,
        addresses: const [],
        steps: steps,
        isFakeDns: false,
      );
    }

    final resolved = addresses.map((address) => address.address).toList();
    final suspicious = addresses.where(isSuspiciousAddress).toList();
    steps.add('dns: ${resolved.join(', ')} in ${_ms(stopwatch)}');
    if (suspicious.isNotEmpty) {
      steps.add('dns: ${suspicious.first.address} is in a proxy/private range, not a real Google address');
    }

    final target = addresses.first;
    stopwatch = Stopwatch()..start();
    try {
      final socket = await io.Socket.connect(target, 443, timeout: timeout);
      steps.add('tcp: connected to ${target.address}:443 in ${_ms(stopwatch)}');
      socket.destroy();
    } catch (error) {
      steps.add('tcp: failed after ${_ms(stopwatch)} (${_reason(error)})');
      return GoogleConnectivityResult(
        verdict: suspicious.isNotEmpty ? GoogleReachability.fakeDns : GoogleReachability.tcpBlocked,
        host: host,
        addresses: resolved,
        steps: steps,
        isFakeDns: suspicious.isNotEmpty,
      );
    }

    stopwatch = Stopwatch()..start();
    try {
      final secure = await io.SecureSocket.connect(host, 443, timeout: timeout);
      steps.add('tls: handshake ok in ${_ms(stopwatch)}');
      secure.destroy();
    } catch (error) {
      steps.add('tls: failed after ${_ms(stopwatch)} (${error.runtimeType})');
      return GoogleConnectivityResult(
        verdict: GoogleReachability.tlsBlocked,
        host: host,
        addresses: resolved,
        steps: steps,
        isFakeDns: suspicious.isNotEmpty,
      );
    }

    stopwatch = Stopwatch()..start();
    final client = io.HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse('https://$host/')).timeout(timeout);
      final response = await request.close().timeout(timeout);
      steps.add('http: ${response.statusCode} in ${_ms(stopwatch)}');
      await response.drain<void>();
    } catch (error) {
      steps.add('http: failed after ${_ms(stopwatch)} (${error.runtimeType})');
      return GoogleConnectivityResult(
        verdict: GoogleReachability.httpBlocked,
        host: host,
        addresses: resolved,
        steps: steps,
        isFakeDns: suspicious.isNotEmpty,
      );
    } finally {
      client.close(force: true);
    }

    return GoogleConnectivityResult(
      verdict: GoogleReachability.ok,
      host: host,
      addresses: resolved,
      steps: steps,
      isFakeDns: suspicious.isNotEmpty,
    );
  }

  /// True for an address a public host should never resolve to.
  ///
  /// The ranges are the ones that actually show up on developer machines:
  /// * `198.18.0.0/15` — the benchmarking range, but it is what Clash/mihomo
  ///   "fake-IP" DNS hands out (typically `198.18.0.x`),
  /// * `100.64.0.0/10` — CGNAT, used by some VPN/Tailscale setups,
  /// * `10/8`, `172.16/12`, `192.168/16`, `127/8`, `169.254/16`, `0/8`,
  /// * IPv6 loopback, unique-local (`fc00::/7`) and link-local (`fe80::/10`),
  ///   including IPv4-mapped forms of the above.
  static bool isSuspiciousAddress(io.InternetAddress address) => isSuspiciousRawAddress(address.rawAddress);

  /// The same check on raw bytes, so it is testable without a resolver.
  static bool isSuspiciousRawAddress(List<int> raw) {
    if (raw.length == 4) return _isSuspiciousIpv4(raw);
    if (raw.length != 16) return false;

    // IPv4-mapped (::ffff:a.b.c.d) and IPv4-compatible addresses.
    final isMapped = raw.sublist(0, 10).every((byte) => byte == 0) && raw[10] == 0xff && raw[11] == 0xff;
    if (isMapped) return _isSuspiciousIpv4(raw.sublist(12));

    final isLoopback = raw.sublist(0, 15).every((byte) => byte == 0) && raw[15] == 1;
    if (isLoopback) return true;

    final isUniqueLocal = (raw[0] & 0xfe) == 0xfc; // fc00::/7
    final isLinkLocal = raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80; // fe80::/10
    final isUnspecified = raw.every((byte) => byte == 0);

    return isUniqueLocal || isLinkLocal || isUnspecified;
  }

  static bool _isSuspiciousIpv4(List<int> raw) {
    final a = raw[0];
    final b = raw[1];

    if (a == 0) return true; // 0.0.0.0/8
    if (a == 10) return true; // 10/8
    if (a == 127) return true; // loopback
    if (a == 169 && b == 254) return true; // link-local
    if (a == 172 && b >= 16 && b <= 31) return true; // 172.16/12
    if (a == 192 && b == 168) return true; // 192.168/16
    if (a == 100 && b >= 64 && b <= 127) return true; // 100.64/10 (CGNAT / VPN)
    if (a == 198 && (b == 18 || b == 19)) return true; // 198.18/15 (fake-IP pools)
    return false;
  }

  static String _ms(Stopwatch stopwatch) => '${stopwatch.elapsedMilliseconds}ms';

  static String _reason(Object error) {
    if (error is io.SocketException) {
      return error.osError?.message ?? error.message;
    }
    return error.runtimeType.toString();
  }
}
