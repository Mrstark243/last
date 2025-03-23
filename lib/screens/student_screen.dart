import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  late SocketService _socketService;
  bool _isConnected = false;
  Uint8List? _currentImage;
  final String _teacherIpAddress = '192.168.43.106';

  @override
  void initState() {
    super.initState();
    _socketService = SocketService(
      onImageReceived: (imageBytes) {
        setState(() {
          _currentImage = imageBytes;
        });
      },
    );
  }

  Future<void> _toggleConnection() async {
    if (!_isConnected) {
      try {
        final success = await _socketService.connectToServer(_teacherIpAddress);
        if (success) {
          setState(() {
            _isConnected = true;
          });
        } else {
          _showError('Failed to connect to teacher');
        }
      } catch (e) {
        print('Connection error: $e');
        _showError('Failed to connect to teacher');
      }
    } else {
      _socketService.disconnect();
      setState(() {
        _isConnected = false;
        _currentImage = null;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Screen'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(_isConnected ? Icons.logout : Icons.login),
                  label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    backgroundColor: _isConnected ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _toggleConnection,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _currentImage != null
                  ? Image.memory(
                      _currentImage!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.high,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text('Error loading image'),
                        );
                      },
                    )
                  : const Center(
                      child: Text('No screen sharing active'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}