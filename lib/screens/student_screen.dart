import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../widgets/note_viewer_widget.dart';
import '../models/note_model.dart';

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
  List<Map<String, dynamic>> _receivedNotes = [];

  @override
  void initState() {
    super.initState();
    _loadSavedNotes();
  }

  Future<void> _connectToServer() async {
    if (_isReconnecting) return;

    try {
      setState(() {
        _status = 'Connecting...';
        _isReconnecting = true;
      });

      _socket = await Socket.connect('192.168.43.251', 5000);
      setState(() {
        _isConnected = true;
        _status = 'Connected';
        _isReconnecting = false;
      });

      _listenToServer();
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
        _isConnected = false;
        _isReconnecting = false;
      });
      _scheduleReconnect();
    }
  }

  void _listenToServer() {
    _socket?.listen(
      (data) async {
        if (_isNoteData(data)) {
          _handleNoteData(data);
        } else {
          _handleScreenImageData(data);
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

  bool _isNoteData(List<int> data) {
    try {
      final decodedString = utf8.decode(data);
      return decodedString.contains('"type":"note"');
    } catch (_) {
      return false;
    }
  }

  void _handleNoteData(List<int> data) async {
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded['type'] == 'note') {
        final fileName = decoded['fileName'];
        final fileBytes = base64Decode(decoded['fileBytes']);

        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(fileBytes);

        setState(() {
          _receivedNotes.add({'name': fileName, 'path': file.path});
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Received and saved note: $fileName')),
        );
      }
    } catch (e) {
      print('Failed to decode note: $e');
    }
  }

  void _handleScreenImageData(List<int> data) async {
    _buffer.addAll(data);
    while (_buffer.length >= 4) {
      final ByteData byteData =
          ByteData.view(Uint8List.fromList(_buffer).buffer);
      final int imageSize = byteData.getInt32(0, Endian.big);

      if (imageSize <= 0 || imageSize > 10 * 1024 * 1024) {
        print('Invalid image size: $imageSize');
        _buffer.clear();
        return;
      }

      final int totalSize = 4 + imageSize;
      if (_buffer.length < totalSize) return;

      final Uint8List imageData =
          Uint8List.fromList(_buffer.sublist(4, totalSize));
      _buffer.removeRange(0, totalSize);

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

  Future<void> _loadSavedNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync();
    final notes = files.whereType<File>().where((file) {
      final name = file.path.split('/').last.toLowerCase();
      return name.endsWith('.pdf') || name.endsWith('.txt');
    }).map((file) {
      return {'name': file.path.split('/').last, 'path': file.path};
    }).toList();

    setState(() {
      _receivedNotes = notes;
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
      backgroundColor: const Color(0xFFF3F2FF),
      appBar: AppBar(
        title: const Text('Student View'),
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
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
                fontSize: 16,
              ),
            ),
          ),
          if (!_isConnected)
            ElevatedButton(
              onPressed: _connectToServer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("Connect to Teacher"),
            ),
          if (_receivedNotes.isNotEmpty)
            Expanded(
              flex: 1,
              child: NoteViewerWidget(
                notes: _receivedNotes
                    .map((note) => NoteModel(
                          title: note['name'],
                          filePath: note['path'],
                          receivedAt: File(note['path']).lastModifiedSync(),
                        ))
                    .toList(),
              ),
            ),
          Expanded(
            flex: 2,
            child: _screenImage == null
                ? const Center(child: Text("No screen shared yet."))
                : Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: RawImage(
                      image: _screenImage,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
