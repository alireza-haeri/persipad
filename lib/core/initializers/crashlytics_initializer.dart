import 'package:flutter/foundation.dart';
import 'package:storypad/core/constants/app_constants.dart';

class CrashlyticsInitializer {
  static void call() {
    _listenToErrors();
    _listenToNonFlutterErrors();
  }

  static void _listenToErrors() {
    FlutterError.onError = (FlutterErrorDetails details) {
      kErrorReportingService.recordFlutterFatalError(details);
    };
  }

  static void _listenToNonFlutterErrors() {
    PlatformDispatcher.instance.onError = (error, stack) {
      kErrorReportingService.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
