import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';

class SocketService {
  HttpServer? _server;
  IOWebSocketChannel? _channel;
  final void Function(Uint8List)? onImageReceived;
  final int port = 5000;
  final List<WebSocket> _connectedClients = [];

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

      _server!.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        print('Client connected');
        _connectedClients.add(webSocket);
        
        webSocket.listen(
          (data) {
            // Handle incoming messages if needed
          },
          onDone: () {
            print('Client disconnected');
            _connectedClients.remove(webSocket);
          },
          onError: (error) {
            print('Error: $error');
            _connectedClients.remove(webSocket);
          },
        );
      });

      return true;
    } catch (e) {
      print('Error starting server: $e');
      return false;
    }
  }

  void stopServer() {
    for (var client in _connectedClients) {
      client.close();
    }
    _connectedClients.clear();
    _server?.close();
    _server = null;
  }

  Future<bool> connectToServer(String serverIp) async {
    try {
      final wsUrl = 'ws://$serverIp:$port';
      _channel = IOWebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        (data) {
          if (data is List<int>) {
            onImageReceived?.call(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          print('Connection error: $error');
        },
        onDone: () {
          print('Connection closed');
        },
      );

      return true;
    } catch (e) {
      print('Error connecting to server: $e');
      return false;
    }
  }

  void sendImage(Uint8List imageBytes) {
    for (var client in _connectedClients) {
      try {
        client.add(imageBytes);
      } catch (e) {
        print('Error sending image to client: $e');
        _connectedClients.remove(client);
      }
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
} 