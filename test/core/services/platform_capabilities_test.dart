import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/platform_capabilities.dart';

// Linux is the only platform we actively ship, and it is also the one that can
// silently lose features: `google_sign_in` has no Linux implementation, so the
// Drive tile used to offer a sign-in that could never succeed, and appearing to
// have no cloud sync at all. These tests pin the matrix down.
void main() {
  bool onAndroid(BackupServiceType type) {
    return PlatformCapabilities.cloudSync(type: type, isLinux: false, isIOS: false, isMacOS: false);
  }

  bool onLinux(BackupServiceType type) {
    return PlatformCapabilities.cloudSync(type: type, isLinux: true, isIOS: false, isMacOS: false);
  }

  bool onIOS(BackupServiceType type) {
    return PlatformCapabilities.cloudSync(type: type, isLinux: false, isIOS: true, isMacOS: false);
  }

  bool onMacOS(BackupServiceType type) {
    return PlatformCapabilities.cloudSync(type: type, isLinux: false, isIOS: false, isMacOS: true);
  }

  group('PlatformCapabilities.cloudSync on android', () {
    test('supports drive, dropbox and nextcloud', () {
      expect(onAndroid(BackupServiceType.google_drive), isTrue);
      expect(onAndroid(BackupServiceType.dropbox), isTrue);
      expect(onAndroid(BackupServiceType.nextcloud), isTrue);
    });

    test('does not support icloud', () {
      expect(onAndroid(BackupServiceType.icloud), isFalse);
    });
  });

  group('PlatformCapabilities.cloudSync on linux', () {
    test('cannot sign in to google drive', () {
      // google_sign_in has no Linux implementation: the registered Drive service
      // is a stub whose signIn() always returns false.
      expect(onLinux(BackupServiceType.google_drive), isFalse);
    });

    test('cannot use icloud', () {
      expect(onLinux(BackupServiceType.icloud), isFalse);
    });

    test('can use dropbox through loopback oauth', () {
      expect(onLinux(BackupServiceType.dropbox), isTrue);
    });

    test('can use nextcloud over webdav', () {
      expect(onLinux(BackupServiceType.nextcloud), isTrue);
    });

    test('always keeps at least one working sync backend', () {
      final usable = BackupServiceType.values.where(onLinux).toList();

      expect(
        usable,
        isNotEmpty,
        reason: 'Linux is our primary target; losing every sync option would make it unusable',
      );
      expect(usable, contains(BackupServiceType.nextcloud));
    });
  });

  group('PlatformCapabilities.cloudSync on apple platforms', () {
    test('ios supports every service', () {
      for (final type in BackupServiceType.values) {
        expect(onIOS(type), isTrue, reason: 'missing ${type.id} on iOS');
      }
    });

    test('macos supports every service', () {
      for (final type in BackupServiceType.values) {
        expect(onMacOS(type), isTrue, reason: 'missing ${type.id} on macOS');
      }
    });
  });
}
