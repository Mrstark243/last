import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final TextEditingController _ipController = TextEditingController();
  late SocketService _socketService;
  bool _isConnected = false;
  Uint8List? _currentImage;

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
      final ip = _ipController.text.trim();
      if (ip.isEmpty) {
        _showError('Please enter teacher\'s IP address');
        return;
      }

      if (await _socketService.connectToServer(ip)) {
        setState(() => _isConnected = true);
      } else {
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
    _ipController.dispose();
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
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher\'s IP Address',
                      hintText: 'Enter IP address (e.g., 192.168.1.100)',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isConnected,
                  ),
                ),
                const SizedBox(width: 16),
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
                    )
                  : const Center(
                      child: Text(
                        'Waiting for teacher\'s screen...',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
} 