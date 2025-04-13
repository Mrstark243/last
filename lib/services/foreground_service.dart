import 'package:screen_brightness/screen_brightness.dart';

class ForegroundService {
  static bool _isRunning = false;
  static double? _originalBrightness;

  static Future<bool> startForegroundService() async {
    if (_isRunning) return true;

    try {
      // Store original brightness and set to maximum
      _originalBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);

      _isRunning = true;
      return true;
    } catch (e) {
      print('Error starting foreground service: $e');
      return false;
    }
  }

  static Future<void> stopForegroundService() async {
    if (!_isRunning) return;

    try {
      // Restore original brightness
      if (_originalBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
        _originalBrightness = null;
      }

      _isRunning = false;
    } catch (e) {
      print('Error stopping foreground service: $e');
    }
  }

  static bool get isRunning => _isRunning;
}
