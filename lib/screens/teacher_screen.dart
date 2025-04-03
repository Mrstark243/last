import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/painting.dart';
import 'package:pro3/services/socket_service.dart';
import 'package:pro3/services/screen_capture_service.dart';
import 'package:pro3/services/foreground_service.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  final SocketService _socketService = SocketService();
  late final ScreenCaptureService _screenCaptureService;
  final GlobalKey _globalKey = GlobalKey();
  bool _isServerRunning = false;
  bool _isCapturing = false;
  String? _ipAddress;
  String? _errorMessage;
  Timer? _captureTimer;
  int _frameCount = 0;
  DateTime _lastCaptureTime = DateTime.now();
  static const Duration captureInterval = Duration(milliseconds: 100); // 10 FPS
  double _currentFps = 0.0;
  int _totalBytesSent = 0;
  DateTime _lastStatsTime = DateTime.now();
  bool _isCompressing = false;
  static const int maxImageSize = 1024 * 1024; // 1MB max image size
  bool _hasPermissions = false;
  bool _isForegroundServiceRunning = false;
  static const platform = MethodChannel('com.example.pro3/screen_capture');
  String _status = 'Not started';

  @override
  void initState() {
    super.initState();
    _screenCaptureService = ScreenCaptureService(
      onScreenCaptured: _handleScreenCapture,
    );
    _getIpAddress();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool hasPermission = await platform.invokeMethod('requestMediaProjection');
      if (hasPermission) {
        setState(() {
          _status = 'Permission granted';
        });
      } else {
        setState(() {
          _status = 'Permission denied';
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
      });
    }
  }

  void _handleScreenCapture(Uint8List imageBytes) {
    if (!_isServerRunning || _isCompressing) return;
    
    try {
      _isCompressing = true;
      
      if (imageBytes.length <= maxImageSize) {
        _socketService.sendImage(imageBytes);
        _totalBytesSent += imageBytes.length;
        
        // Update stats every second
        _frameCount++;
        final now = DateTime.now();
        if (now.difference(_lastStatsTime).inSeconds >= 1) {
          final elapsed = now.difference(_lastStatsTime).inMilliseconds / 1000.0;
          _currentFps = _frameCount / elapsed;
          final bytesPerSecond = _totalBytesSent / elapsed;
          
          print('Stats - FPS: ${_currentFps.toStringAsFixed(2)}, '
              'Data Rate: ${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s');
          
          if (mounted) {
            setState(() {
              _frameCount = 0;
              _lastStatsTime = now;
            });
          }
        }
      } else {
        print('Captured image too large: ${imageBytes.length} bytes');
      }
    } catch (e) {
      print('Error handling screen capture: $e');
      _stopCapturing();
      if (mounted) {
        _showErrorSnackBar('Error handling screen capture: $e');
      }
    } finally {
      _isCompressing = false;
    }
  }

  Future<void> _getIpAddress() async {
    final ip = await _socketService.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _ipAddress = ip;
      });
    }
  }

  Future<void> _startScreenCapture() async {
    try {
      // Start foreground service
      await ForegroundService.startForegroundService();
      setState(() {
        _isForegroundServiceRunning = true;
      });
      
      // Start screen capture
      final bool success = await platform.invokeMethod('startScreenCapture');
      if (success) {
        setState(() {
          _isCapturing = true;
          _status = 'Screen capture active';
        });
      } else {
        setState(() {
          _status = 'Failed to start screen capture';
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
      });
    }
  }
  
  Future<void> _stopScreenCapture() async {
    try {
      // Stop screen capture
      final bool success = await platform.invokeMethod('stopScreenCapture');
      if (success) {
        setState(() {
          _isCapturing = false;
          _status = 'Screen capture stopped';
        });
      }
      
      // Stop foreground service
      await ForegroundService.stopForegroundService();
      setState(() {
        _isForegroundServiceRunning = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
      });
    }
  }

  void _stopCapturing() {
    if (_captureTimer != null) {
      _captureTimer!.cancel();
      _captureTimer = null;
    }
    _isCapturing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _globalKey,
      appBar: AppBar(
        title: const Text('Teacher Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _status,
              style: TextStyle(
                color: _isCapturing ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(_isCapturing ? Icons.stop : Icons.play_arrow),
              label: Text(_isCapturing ? 'Stop Capture' : 'Start Capture'),
              onPressed: _isCapturing ? _stopScreenCapture : _startScreenCapture,
            ),
            if (_isForegroundServiceRunning)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Screen capture is running in the background',
                  style: TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _stopScreenCapture();
    _socketService.stopServer();
    
    // Stop the foreground service if it's running
    if (_isForegroundServiceRunning) {
      ForegroundService.stopForegroundService();
    }
    
    super.dispose();
  }
}