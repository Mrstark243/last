import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ScreenCaptureService {
  Timer? _captureTimer;
  final void Function(Uint8List) onScreenCaptured;
  final GlobalKey _globalKey = GlobalKey();
  bool _isCapturing = false;
  static const int _captureInterval = 500;
  static const MethodChannel _channel = MethodChannel('screen_capture_service');

  ScreenCaptureService({required this.onScreenCaptured});

  Future<bool> requestPermissions() async {
    try {
      // Get Android version
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (Platform.isAndroid) {
        if (sdkInt >= 33) {
          // Android 13+ permissions
          final photos = await Permission.photos.request();
          final videos = await Permission.videos.request();
          final mediaLocation = await Permission.accessMediaLocation.request();

          if (photos.isDenied || videos.isDenied || mediaLocation.isDenied) {
            print('Media permissions denied for Android 13+');
            return false;
          }
        } else {
          // Below Android 13
          final storage = await Permission.storage.request();
          if (storage.isDenied) {
            print('Storage permission denied');
            return false;
          }

          // For Android 11+ (API 30+), request all files access
          if (sdkInt >= 30) {
            if (!await Permission.manageExternalStorage.isGranted) {
              final status = await Permission.manageExternalStorage.request();
              if (status.isDenied) {
                print('Manage external storage permission denied');
                return false;
              }
            }
          }
        }

        // Request media projection permission through platform channel
        try {
          final bool hasProjectionPermission = await _channel.invokeMethod('requestMediaProjection');
          if (!hasProjectionPermission) {
            print('Media projection permission denied');
            return false;
          }
        } catch (e) {
          print('Error requesting media projection: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  void startCapturing() {
    if (_isCapturing) return;
    
    _captureTimer?.cancel();
    _isCapturing = true;
    
    _captureTimer = Timer.periodic(const Duration(milliseconds: _captureInterval), (timer) async {
      if (!_isCapturing) return;
      
      try {
        final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 0.5); // Reduced quality for better performance
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            onScreenCaptured(byteData.buffer.asUint8List());
          }
        }
      } catch (e) {
        print('Error capturing screen: $e');
        stopCapturing();
      }
    });
  }

  void stopCapturing() {
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  GlobalKey get globalKey => _globalKey;
}