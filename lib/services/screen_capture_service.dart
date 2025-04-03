import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ScreenCaptureService {
  Timer? _captureTimer;
  final Function(Uint8List) onScreenCaptured;
  final GlobalKey globalKey = GlobalKey();
  bool _isCapturing = false;
  bool _isFirstCapture = true;
  static const int _captureInterval = 100; // Set to 100ms for smoother updates
  static const int _debounceDuration = 50; // Set to 50ms for better responsiveness
  static const double _captureScale = 0.7; // Keep 70% scale for better quality
  static const MethodChannel _channel = MethodChannel('screen_capture_service');
  Timer? _debounceTimer;
  int _lastCaptureTime = 0;
  static const int _minCaptureInterval = 50; // Minimum time between captures in ms
  bool _hasPermissions = false;
  
  // Platform channel for native screen capture
  static const platform = MethodChannel('com.example.pro3/screen_capture');
  
  ScreenCaptureService({required this.onScreenCaptured}) {
    // Initialize the platform channel
    platform.setMethodCallHandler(_handleMethod);
  }
  
  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onScreenCaptured':
        final String imagePath = call.arguments['imagePath'];
        final Uint8List imageBytes = await File(imagePath).readAsBytes();
        onScreenCaptured(imageBytes);
        // Clean up the temporary file
        await File(imagePath).delete();
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }
  
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Request screen capture permission
      final status = await Permission.storage.request();
      _hasPermissions = status.isGranted;
      
      if (_hasPermissions) {
        // Request media projection permission
        try {
          final bool? result = await platform.invokeMethod('requestMediaProjection');
          _hasPermissions = result ?? false;
        } catch (e) {
          print('Error requesting media projection: $e');
          _hasPermissions = false;
        }
      }
    } else {
      // For other platforms, just check storage permission
      final status = await Permission.storage.request();
      _hasPermissions = status.isGranted;
    }
    
    return _hasPermissions;
  }
  
  void startCapturing() {
    if (_isCapturing || !_hasPermissions) return;
    
    _isCapturing = true;
    
    // Start native screen capture
    platform.invokeMethod('startScreenCapture');
    
    // Set up a timer to request captures at regular intervals
    _captureTimer = Timer.periodic(Duration(milliseconds: _captureInterval), (timer) {
      if (_isCapturing) {
        _captureScreen();
      }
    });
  }
  
  void stopCapturing() {
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    
    // Stop native screen capture
    platform.invokeMethod('stopScreenCapture');
  }
  
  Future<void> _captureScreen() async {
    if (!_isCapturing) return;
    
    try {
      // Request a screen capture from the native side
      await platform.invokeMethod('captureScreen');
    } catch (e) {
      print('Error capturing screen: $e');
    }
  }
  
  void dispose() {
    stopCapturing();
  }
}