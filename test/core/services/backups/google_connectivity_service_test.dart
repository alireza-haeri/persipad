import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/backups/google_connectivity_service.dart';

/// The sign-in failure this was written for reported "no internet" whether DNS,
/// TCP, TLS or HTTP broke. The one part of the probe that can be pinned down
/// without a network is the address classification — and that is exactly the
/// part that separates "your proxy answered with a fake IP" from "the whole
/// device is offline", so it is worth a test.
void main() {
  bool suspicious(String address) => GoogleConnectivityService.isSuspiciousAddress(InternetAddress(address));

  test('flags the address ranges a proxy or VPN hands out', () {
    const addresses = [
      '198.18.0.60', // Clash/mihomo fake-IP pool (198.18.0.0/15)
      '198.19.255.254',
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.1.10',
      '127.0.0.1',
      '169.254.1.1',
      '100.64.0.1', // CGNAT, some VPN/Tailscale setups
      '100.127.255.254',
      '0.0.0.0',
    ];

    for (final address in addresses) {
      expect(suspicious(address), isTrue, reason: address);
    }
  });

  test('does not flag real public addresses', () {
    const addresses = [
      '142.250.185.106', // google
      '172.217.16.14', // google
      '74.125.24.95', // google
      '216.58.200.42', // google
      '172.32.0.1', // just outside 172.16/12
      '100.63.255.254', // just below CGNAT
      '100.128.0.1', // just above CGNAT
      '198.20.0.1', // just outside 198.18/15
    ];

    for (final address in addresses) {
      expect(suspicious(address), isFalse, reason: address);
    }
  });

  test('handles IPv6 loopback, unique-local and link-local, including IPv4-mapped', () {
    expect(suspicious('::1'), isTrue);
    expect(suspicious('fc00::1'), isTrue);
    expect(suspicious('fd12:3456:789a::1'), isTrue);
    expect(suspicious('fe80::1'), isTrue);
    expect(suspicious('::'), isTrue);
    expect(suspicious('::ffff:198.18.0.1'), isTrue);
    expect(suspicious('::ffff:142.250.185.106'), isFalse);

    // A real Google AAAA record must stay "not suspicious".
    expect(suspicious('2607:f8b0:4005:80a::200e'), isFalse);
  });

  test('classifies raw bytes the same way for 4- and 16-byte addresses', () {
    expect(GoogleConnectivityService.isSuspiciousRawAddress([198, 18, 0, 60]), isTrue);
    expect(GoogleConnectivityService.isSuspiciousRawAddress([142, 250, 185, 106]), isFalse);
    const mappedFakeIp = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, 198, 18, 0, 60];
    expect(GoogleConnectivityService.isSuspiciousRawAddress(mappedFakeIp), isTrue);
    expect(GoogleConnectivityService.isSuspiciousRawAddress([1, 2, 3]), isFalse, reason: 'unknown length');
  });

  test('summary names the verdict and the address, and carries no secret', () {
    const result = GoogleConnectivityResult(
      verdict: GoogleReachability.fakeDns,
      host: 'oauth2.googleapis.com',
      addresses: ['198.18.0.60'],
      steps: ['dns: 198.18.0.60 in 3ms', 'tcp: failed after 5001ms (Connection refused)'],
      isFakeDns: true,
    );

    expect(result.summary, 'verdict=fakeDns host=oauth2.googleapis.com addresses=198.18.0.60');
    expect(result.isOk, isFalse);
    expect(result.advice, contains('fake-IP'));
  });

  test('every failing verdict has advice, and success has none', () {
    for (final verdict in GoogleReachability.values) {
      final result = GoogleConnectivityResult(
        verdict: verdict,
        host: 'oauth2.googleapis.com',
        addresses: const ['142.250.185.106'],
        steps: const [],
        isFakeDns: false,
      );

      if (verdict == GoogleReachability.ok) {
        expect(result.advice, isNull, reason: verdict.name);
      } else {
        expect(result.advice, isNotNull, reason: verdict.name);
        expect(result.advice, isNotEmpty, reason: verdict.name);
      }
    }
  });
}
