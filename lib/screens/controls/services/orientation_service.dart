import 'package:flutter/services.dart';

class OrientationService {
  /// Switch to landscape mode for robot control
  static void switchToLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Switch to portrait mode for Bluetooth connection
  static void switchToPortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// Restore all orientations when leaving the screen
  static void restoreAllOrientations() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
