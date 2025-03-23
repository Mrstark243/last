import 'package:flutter/material.dart';
import '../services/screen_capture_service.dart';
import '../services/socket_service.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  late ScreenCaptureService _screenCaptureService;
  late SocketService _socketService;
  bool _isSharing = false;
  String? _ipAddress;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService();
    _screenCaptureService = ScreenCaptureService(
      onScreenCaptured: (imageBytes) {
        _socketService.sendImage(imageBytes);
      },
    );
    _getIpAddress();
  }

  Future<void> _getIpAddress() async {
    final ip = await _socketService.getLocalIpAddress();
    setState(() {
      _ipAddress = ip;
    });
  }

  Future<void> _toggleSharing() async {
    if (!_isSharing) {
      if (await _screenCaptureService.requestPermissions()) {
        if (await _socketService.startServer()) {
          // Wait for a moment to ensure server is fully started
          await Future.delayed(const Duration(milliseconds: 500));
          
          _screenCaptureService.startCapturing();
          setState(() => _isSharing = true);
        } else {
          _showError('Failed to start server');
        }
      } else {
        _showError('Permission denied');
      }
    } else {
      _screenCaptureService.stopCapturing();
      _socketService.stopServer();
      setState(() => _isSharing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _screenCaptureService.stopCapturing();
    _socketService.stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Screen'),
        centerTitle: true,
      ),
      body: RepaintBoundary(
        key: _screenCaptureService.globalKey,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_ipAddress != null) ...[
                Text(
                  'Your IP Address:',
                  style: TextStyle(fontSize: 18),
                ),
                SelectableText(
                  _ipAddress!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: Container(
                  color: Colors.grey[200], 
                  child: Center(
                    child: Text(
                      _isSharing ? 'Screen Sharing Active' : 'Screen Sharing Area',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(_isSharing ? Icons.stop : Icons.play_arrow),
                label: Text(_isSharing ? 'Stop Sharing' : 'Start Sharing'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  backgroundColor: _isSharing ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _toggleSharing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}