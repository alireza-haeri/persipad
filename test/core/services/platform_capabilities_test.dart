import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/backups/backup_service_type.dart';
import 'package:storypad/core/services/platform_capabilities.dart';

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

  group('PlatformCapabilities.cloudSync', () {
    test('supports Google Drive across android, linux, ios, and macos', () {
      expect(onAndroid(BackupServiceType.google_drive), isTrue);
      expect(onLinux(BackupServiceType.google_drive), isTrue);
      expect(onIOS(BackupServiceType.google_drive), isTrue);
      expect(onMacOS(BackupServiceType.google_drive), isTrue);
    });

    test('always keeps at least one working sync backend on linux', () {
      final usable = BackupServiceType.values.where(onLinux).toList();

      expect(usable, isNotEmpty);
      expect(usable, contains(BackupServiceType.google_drive));
    });
  });

  group('PlatformCapabilities.firebase', () {
    test('linux has no firebase options and must not read them', () {
      expect(PlatformCapabilities.firebase(isLinux: true), isFalse);
    });

    test('other platforms have firebase options', () {
      expect(PlatformCapabilities.firebase(isLinux: false), isTrue);
    });
  });

  group('PlatformCapabilities.storeUpdates', () {
    test('is limited to the platforms that own a store (android/ios)', () {
      expect(PlatformCapabilities.storeUpdates(isAndroid: true, isIOS: false), isTrue);
      expect(PlatformCapabilities.storeUpdates(isAndroid: false, isIOS: true), isTrue);
      expect(PlatformCapabilities.storeUpdates(isAndroid: false, isIOS: false), isFalse);
    });
  });

  group('PlatformCapabilities.videoPlayback', () {
    test('has no native backend on linux or windows', () {
      expect(PlatformCapabilities.videoPlayback(isLinux: true, isWindows: false), isFalse);
      expect(PlatformCapabilities.videoPlayback(isLinux: false, isWindows: true), isFalse);
    });

    test('works on android, ios, macos and web', () {
      expect(PlatformCapabilities.videoPlayback(isLinux: false, isWindows: false), isTrue);
    });
  });
}
