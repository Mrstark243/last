import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  HttpServer? _server;
  WebSocket? _serverWebSocket;
  IOWebSocketChannel? _clientChannel;
  final void Function(Uint8List)? onImageReceived;
  final int port = 5000;
  bool _isConnected = false;

  SocketService({this.onImageReceived});

  Future<String?> getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      return await info.getWifiIP();
    } catch (e) {
      print('Error getting IP address: $e');
      return null;
    }
  }

  Future<bool> startServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Server listening on port $port');

      _server!.transform(WebSocketTransformer()).listen(
        (WebSocket webSocket) {
          print('Client connected');
          _serverWebSocket = webSocket;
          _isConnected = true;
          
          webSocket.listen(
            (data) {
              // Handle incoming messages if needed
              print('Received data from client: ${data.toString().substring(0, 50)}...');
            },
            onDone: () {
              print('Client disconnected');
              _serverWebSocket = null;
              _isConnected = false;
            },
            onError: (error) {
              print('Error: $error');
              _serverWebSocket = null;
              _isConnected = false;
            },
            cancelOnError: true,
          );
        },
        onDone: () {
          print('Server closed');
          _isConnected = false;
        },
        onError: (error) {
          print('Server error: $error');
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      print('Error starting server: $e');
      return false;
    }
  }

  void stopServer() {
    _serverWebSocket?.close();
    _serverWebSocket = null;
    _server?.close();
    _server = null;
    _isConnected = false;
  }

  Future<bool> connectToServer(String serverIp) async {
    try {
      final wsUrl = 'ws://$serverIp:$port';
      print('Connecting to server at $wsUrl');
      
      _clientChannel = IOWebSocketChannel.connect(wsUrl);
      
      _clientChannel!.stream.listen(
        (data) {
          if (data is List<int>) {
            onImageReceived?.call(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          print('Connection error: $error');
          _isConnected = false;
          _clientChannel?.sink.close();
          _clientChannel = null;
        },
        onDone: () {
          print('Connection closed');
          _isConnected = false;
          _clientChannel?.sink.close();
          _clientChannel = null;
        },
        cancelOnError: true,
      );

      _isConnected = true;
      return true;
    } catch (e) {
      print('Error connecting to server: $e');
      _isConnected = false;
      _clientChannel?.sink.close();
      _clientChannel = null;
      return false;
    }
  }

  void sendImage(Uint8List imageBytes) {
    if (_serverWebSocket != null && _isConnected) {
      try {
        _serverWebSocket!.add(imageBytes);
      } catch (e) {
        print('Error sending image: $e');
        _serverWebSocket?.close();
        _serverWebSocket = null;
        _isConnected = false;
      }
    }
  }

  void disconnect() {
    _clientChannel?.sink.close();
    _clientChannel = null;
    _isConnected = false;
    _serverWebSocket?.close();
    _serverWebSocket = null;
    _server?.close();
    _server = null;
  }

  bool get isConnected => _isConnected;
}