import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/platform_capabilities.dart';

void main() {
  // Linux is the only platform we actively ship, and it is also the one that
  // silently loses features: `google_sign_in` has no Linux implementation, so
  // the Drive tile used to offer a sign-in that could never succeed. These
  // tests pin the matrix down so a future refactor can't quietly take a working
  // sync backend away from Linux.
  group('PlatformCapabilities.cloudSync', () {
    bool availableOn({
      required BackupServiceType type,
      bool linux = false,
      bool ios = false,
      bool macos = false,
    }) {
      return PlatformCapabilities.cloudSync(
        type: type,
        isLinux: linux,
        isIOS: ios,
        isMacOS: macos,
      );
    }

    test('android can use every non-Apple service', () {
      for (final type in [
        BackupServiceType.google_drive,
        BackupServiceType.dropbox,
        BackupServiceType.nextcloud,
      ]) {
        expect(availableOn(type: type), isTrue, reason: '${type.id} on android');
      }
      expect(availableOn(type: BackupServiceType.icloud), isFalse, reason: 'icloud on android');
    });

    test('apple platforms can use everything, including icloud', () {
      for (final type in BackupServiceType.values) {
        expect(availableOn(type: type, ios: true), isTrue, reason: '${type.id} on iOS');
        expect(availableOn(type: type, macos: true), isTrue, reason: '${type.id} on macOS');
      }
    });

    test('linux cannot sign in to google drive', () {
      // google_sign_in has no Linux implementation: the registered Drive
      // service is a stub whose signIn() always returns false.
      expect(availableOn(type: BackupServiceType.google_drive, linux: true), isFalse);
    });

    test('linux cannot use icloud', () {
      expect(availableOn(type: BackupServiceType.icloud, linux: true), isFalse);
    });

    test('linux can use dropbox (loopback OAuth) and nextcloud (WebDAV)', () {
      expect(availableOn(type: BackupServiceType.dropbox, linux: true), isTrue);
      expect(availableOn(type: BackupServiceType.nextcloud, linux: true), isTrue);
    });

    test('linux always keeps at least one working sync backend', () {
      final usable = BackupServiceType.values
          .where((type) => availableOn(type: type, linux: true))
          .toList();

      expect(
        usable,
        isNotEmpty,
        reason: 'Linux is our primary target; losing every cloud sync option would make it unusable',
      );
      expect(usable, contains(BackupServiceType.nextcloud));
    });

    test('every platform keeps at least one working sync backend', () {
      final platforms = {
        'android': (linux: false, ios: false, macos: false),
        'linux': (linux: true, ios: false, macos: false),
        'ios': (linux: false, ios: true, macos: false),
        'macos': (linux: false, ios: false, macos: true),
      };

      for (final entry in platforms.entries) {
        final flags = entry.value;
        final usable = BackupServiceType.values
            .where(
              (type) => availableOn(
                type: type,
                linux: flags.linux,
                ios: flags.ios,
                macos: flags.macos,
              ),
            )
            .toList();

        expect(usable, isNotEmpty, reason: 'no cloud sync backend available on ${entry.key}');
      }
    });
  });
}
