import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SocketService {
  static const int port = 5000;
  static const Duration connectionTimeout = Duration(seconds: 5);
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 5;
  static const int maxImageSize = 1024 * 1024; // 1MB max image size
  static const platform = MethodChannel('com.example.pro3/screen_capture');

  HttpServer? _server;
  IOWebSocketChannel? _channel;
  bool _isServerRunning = false;
  bool _isConnected = false;
  String? _serverIp;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final _imageController = StreamController<Uint8List>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  ServerSocket? _serverSocket;
  Socket? _client;
  bool _isCapturing = false;
  Timer? _captureTimer;
  String? _lastError;

  Stream<Uint8List> get imageStream => _imageController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<String> get errorStream => _errorController.stream;

  SocketService() {
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    _connectionStatusController.stream.listen((isConnected) {
      if (isConnected) {
        _startHeartbeat();
      } else {
        _stopHeartbeat();
      }
    });
  }

  Future<String?> getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        _serverIp = wifiIP;
        return wifiIP;
      }
      
      // Fallback to getting all network interfaces
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _serverIp = addr.address;
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting IP address: $e');
    }
    return null;
  }

  Future<bool> startServer() async {
    if (_isServerRunning) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;
      print('Server listening on port $port');
      
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((WebSocket ws) {
            _handleNewConnection(ws);
          });
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
        }
      });

      return true;
    } catch (e) {
      print('Error starting server: $e');
      _errorController.add('Failed to start server: $e');
      return false;
    }
  }

  void _handleNewConnection(WebSocket ws) {
    print('Client connected');
    _channel = IOWebSocketChannel(ws);
    _isConnected = true;
    _connectionStatusController.add(true);
    _reconnectAttempts = 0;

    _channel!.stream.listen(
      (data) {
        if (data is Uint8List) {
          _handleImageData(data);
        } else if (data == 'ping') {
          _channel?.sink.add('pong');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _errorController.add('Connection error: $error');
        _handleDisconnection();
      },
      onDone: () {
        print('Client disconnected');
        _handleDisconnection();
      },
    );
  }

  void _handleImageData(Uint8List data) {
    if (data.length <= maxImageSize) {
      _imageController.add(data);
    } else {
      print('Received image too large: ${data.length} bytes');
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _connectionStatusController.add(false);
    _channel?.sink.close();
    _channel = null;
  }

  Future<bool> connectToServer(String ipAddress) async {
    if (_isConnected) return true;

    try {
      print('Connecting to server at ws://$ipAddress:$port');
      
      final uri = Uri.parse('ws://$ipAddress:$port');
      final socket = await WebSocket.connect(uri.toString())
          .timeout(connectionTimeout);
      
      _channel = IOWebSocketChannel(socket);
      _isConnected = true;
      _connectionStatusController.add(true);
      _reconnectAttempts = 0;
      
      _channel!.stream.listen(
        (data) {
          if (data is Uint8List) {
            _handleImageData(data);
          } else if (data == 'pong') {
            // Handle pong response if needed
          }
        },
        onError: (error) {
          print('Connection error: $error');
          _errorController.add('Connection error: $error');
          _scheduleReconnect(ipAddress);
        },
        onDone: () {
          print('Connection closed');
          _handleDisconnection();
          _scheduleReconnect(ipAddress);
        },
      );

      return true;
    } catch (e) {
      print('Connection error: $e');
      _errorController.add('Connection error: $e');
      _scheduleReconnect(ipAddress);
      return false;
    }
  }

  void _scheduleReconnect(String ipAddress) {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('Max reconnection attempts reached');
      _errorController.add('Failed to connect after $maxReconnectAttempts attempts');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectAttempts++;
      print('Attempting to reconnect... (Attempt $_reconnectAttempts of $maxReconnectAttempts)');
      connectToServer(ipAddress);
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('ping');
        } catch (e) {
          print('Error sending heartbeat: $e');
          timer.cancel();
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void sendImage(Uint8List imageBytes) {
    if (!_isConnected || _channel == null) {
      print('Cannot send image: not connected');
      return;
    }

    try {
      if (imageBytes.length <= maxImageSize) {
        _channel!.sink.add(imageBytes);
      } else {
        print('Image too large to send: ${imageBytes.length} bytes');
      }
    } catch (e) {
      print('Error sending image: $e');
      _errorController.add('Error sending image: $e');
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _handleDisconnection();
  }

  void stopServer() {
    disconnect();
    _server?.close();
    _server = null;
    _isServerRunning = false;
  }

  void dispose() {
    stopServer();
    _imageController.close();
    _connectionStatusController.close();
    _errorController.close();
  }

  Future<void> startCapturing() async {
    if (_isCapturing) return;

    try {
      _isCapturing = true;
      _captureTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _captureScreen();
      });
    } catch (e) {
      _handleError('Failed to start capturing: $e');
      _isCapturing = false;
    }
  }

  Future<void> stopCapturing() async {
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  Future<void> _captureScreen() async {
    if (!_isCapturing || _channel == null) return;

    try {
      final String? imagePath = await platform.invokeMethod('captureScreen');
      if (imagePath != null) {
        final Uint8List imageBytes = await File(imagePath).readAsBytes();
        _channel!.sink.add(imageBytes);
        await File(imagePath).delete();
      }
    } catch (e) {
      _handleError('Failed to capture screen: $e');
    }
  }

  void _handleError(String error) {
    print('Error: $error');
    _lastError = error;
    _errorController.add(error);
    _connectionStatusController.add(false);
  }
}