import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  Socket? _socket;
  bool _isConnected = false;
  String _status = 'Not connected';
  ui.Image? _screenImage;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  List<int> _buffer = [];
  
  @override
  void initState() {
    super.initState();
    _connectToServer();
  }
  
  Future<void> _connectToServer() async {
    if (_isReconnecting) return;
    
    try {
      setState(() {
        _status = 'Connecting...';
        _isReconnecting = true;
      });
      
      _socket = await Socket.connect('192.168.34.144', 5000);
      setState(() {
        _isConnected = true;
        _status = 'Connected';
        _isReconnecting = false;
      });
      
      _listenForScreenCaptures();
    } catch (e) {
      print('Connection error: $e');
      setState(() {
        _status = 'Connection failed: $e';
        _isConnected = false;
        _isReconnecting = false;
      });
      _scheduleReconnect();
    }
  }
  
  void _listenForScreenCaptures() {
    _socket?.listen(
      (List<int> data) async {
        try {
          // Add new data to buffer
          _buffer.addAll(data);
          
          // Process complete messages from buffer
          while (_buffer.length >= 4) {
            // Read image size (first 4 bytes)
            final ByteData byteData = ByteData.view(Uint8List.fromList(_buffer).buffer);
            final int imageSize = byteData.getInt32(0, Endian.big);
            
            // Check if we have enough data for the complete image
            if (imageSize <= 0 || imageSize > 10 * 1024 * 1024) { // Max 10MB
              print('Invalid image size: $imageSize');
              _buffer.clear();
              return;
            }
            
            final int totalSize = 4 + imageSize;
            if (_buffer.length < totalSize) {
              // Wait for more data
              return;
            }
            
            // Extract image data
            final Uint8List imageData = Uint8List.fromList(_buffer.sublist(4, totalSize));
            
            // Remove processed data from buffer
            _buffer.removeRange(0, totalSize);
            
            // Decode and display image
            final image = img.decodeImage(imageData);
            if (image != null) {
              final bytes = await img.encodePng(image);
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              
              if (mounted) {
                setState(() {
                  _screenImage = frame.image;
                });
              }
            }
          }
        } catch (e) {
          print('Error processing screen capture: $e');
          _buffer.clear();
        }
      },
      onError: (error) {
        print('Socket error: $error');
        _handleDisconnect();
      },
      onDone: () {
        print('Socket closed');
        _handleDisconnect();
      },
    );
  }
  
  void _handleDisconnect() {
    if (!mounted) return;
    
    setState(() {
      _isConnected = false;
      _status = 'Disconnected';
    });
    
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isConnected && !_isReconnecting) {
        _connectToServer();
      }
    });
  }
  
  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student View'),
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: _isConnected ? null : _connectToServer,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _status,
              style: TextStyle(
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            child: _screenImage == null
                ? const Center(child: CircularProgressIndicator())
                : RawImage(
                    image: _screenImage,
                    fit: BoxFit.contain,
                  ),
          ),
        ],
      ),
    );
  }
}