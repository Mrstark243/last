import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/services.dart';

class SocketService {
  static const int port = 5000;
  static const Duration connectionTimeout = Duration(seconds: 5);
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 5;
  static const int maxImageSize = 1024 * 1024;
  static const platform = MethodChannel('com.example.pro3/screen_capture');

  HttpServer? _server;
  final List<IOWebSocketChannel> _students = [];

  IOWebSocketChannel? _channel;
  bool _isServerRunning = false;
  bool _isConnected = false;
  String? _serverIp;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isCapturing = false;
  Timer? _captureTimer;

  final _imageController = StreamController<Uint8List>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _noteController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Uint8List> get imageStream => _imageController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get noteStream => _noteController.stream;

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
      _errorController.add('Failed to start server: $e');
      return false;
    }
  }

  void _handleNewConnection(WebSocket ws) {
    final channel = IOWebSocketChannel(ws);
    _students.add(channel);
    print('Client connected: ${_students.length} students online');

    channel.stream.listen(
      (data) {
        _handleData(data);
      },
      onDone: () {
        _students.remove(channel);
        print('Client disconnected: ${_students.length} students remaining');
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
    );
  }

  void _handleData(dynamic data) {
    if (data is Uint8List) {
      // Default to image, fallback
      _imageController.add(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded['type'] == 'note') {
          _noteController.add({
            'fileName': decoded['fileName'],
            'fileBytes': base64Decode(decoded['fileBytes']),
          });
        } else if (decoded['type'] == 'ping') {
          _channel?.sink.add(jsonEncode({'type': 'pong'}));
        }
      } catch (e) {
        print('Failed to decode data: $e');
      }
    }
  }

  Future<bool> connectToServer(String ipAddress) async {
    if (_isConnected) return true;

    try {
      final uri = Uri.parse('ws://$ipAddress:$port');
      final socket =
          await WebSocket.connect(uri.toString()).timeout(connectionTimeout);

      _channel = IOWebSocketChannel(socket);
      _isConnected = true;
      _connectionStatusController.add(true);
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        _handleData,
        onError: (error) {
          _errorController.add('Connection error: $error');
          _scheduleReconnect(ipAddress);
        },
        onDone: () {
          _handleDisconnection();
          _scheduleReconnect(ipAddress);
        },
      );

      return true;
    } catch (e) {
      _errorController.add('Connection error: $e');
      _scheduleReconnect(ipAddress);
      return false;
    }
  }

  void _scheduleReconnect(String ipAddress) {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      _errorController
          .add('Failed to connect after $maxReconnectAttempts attempts');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectAttempts++;
      connectToServer(ipAddress);
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void sendImage(Uint8List imageBytes) {
    if (_students.isEmpty) return;

    for (final student in _students) {
      try {
        student.sink.add(imageBytes);
      } catch (e) {
        print('Failed to send image to student: $e');
      }
    }
  }

  void sendNote(Uint8List fileBytes, String fileName) {
    final data = jsonEncode({
      'type': 'note',
      'fileName': fileName,
      'fileBytes': base64Encode(fileBytes),
    });

    for (final student in _students) {
      try {
        student.sink.add(data);
      } catch (e) {
        print('Failed to send note: $e');
      }
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _handleDisconnection();
  }

  void _handleDisconnection() {
    _isConnected = false;
    _connectionStatusController.add(false);
    _channel?.sink.close();
    _channel = null;
  }

  void stopServer() {
    disconnect();
    _server?.close();
    _server = null;
    _isServerRunning = false;
    _students.clear();
  }

  void dispose() {
    stopServer();
    _imageController.close();
    _connectionStatusController.close();
    _errorController.close();
    _noteController.close();
  }
}
