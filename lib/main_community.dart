import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:storypad/core/services/platform_capabilities.dart';
import 'firebase_options/community.dart' deferred as community;
import 'main.dart' deferred as source;

Future<void> main() async {
  await community.loadLibrary();
  await source.loadLibrary();

  return source.main(firebaseOptions: _firebaseOptions());
}

/// Returns the Firebase config for this platform, or null when there is none.
///
/// `DefaultFirebaseOptions.currentPlatform` does not return null for a missing
/// platform — it *throws* `UnsupportedError`. FlutterFire never generated a Linux
/// config, and Firebase isn't linked there at all (`FirebaseInitializer` returns
/// early), so reading that getter eagerly used to crash the app before `runApp`
/// on the desktop. The try/catch also covers any other platform whose config was
/// never generated.
FirebaseOptions? _firebaseOptions() {
  if (!PlatformCapabilities.firebaseOnThisDevice) return null;

  try {
    return community.DefaultFirebaseOptions.currentPlatform;
  } catch (_) {
    return null;
  }
}
