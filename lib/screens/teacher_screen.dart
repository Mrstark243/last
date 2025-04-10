import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pro3/services/socket_service.dart';
import 'package:pro3/services/screen_capture_service.dart';
import 'package:pro3/services/foreground_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pro3/screens/connected_students_sheet.dart';
import 'package:pro3/screens/attendance_list_screen.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  final SocketService _socketService = SocketService();
  late final ScreenCaptureService _screenCaptureService;
  bool _isCapturing = false;
  bool _isForegroundServiceRunning = false;
  String _status = 'Not started';

  static const platform = MethodChannel('com.example.pro3/screen_capture');

  // Dummy connected students list (replace with actual data from UDP/WebSocket)
  final List<Map<String, String>> connectedStudents = [
    {'name': 'Alice', 'roll': '101'},
    {'name': 'Bob', 'roll': '102'},
  ];

  @override
  void initState() {
    super.initState();
    _screenCaptureService = ScreenCaptureService(
      onScreenCaptured: _handleScreenCapture,
    );
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool hasPermission =
          await platform.invokeMethod('requestMediaProjection');
      setState(() {
        _status = hasPermission ? 'Permission granted' : 'Permission denied';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
      });
    }
  }

  void _handleScreenCapture(Uint8List imageBytes) {
    _socketService.sendImage(imageBytes);
  }

  Future<void> _startScreenCapture() async {
    try {
      await ForegroundService.startForegroundService();
      final bool success = await platform.invokeMethod('startScreenCapture');
      if (success) {
        setState(() {
          _isCapturing = true;
          _isForegroundServiceRunning = true;
          _status = 'Screen capture active';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _stopScreenCapture() async {
    try {
      await platform.invokeMethod('stopScreenCapture');
      await ForegroundService.stopForegroundService();
      setState(() {
        _isCapturing = false;
        _isForegroundServiceRunning = false;
        _status = 'Screen capture stopped';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _uploadNote() async {
    const typeGroup = XTypeGroup(
      label: 'notes',
      extensions: ['pdf', 'txt'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      final Uint8List fileBytes = await file.readAsBytes();
      final String fileName = file.name;

      _socketService.sendNote(fileBytes, fileName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note "$fileName" sent to students'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openConnectedStudentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConnectedStudentsSheet(
        connectedStudents: connectedStudents,
      ),
    );
  }

  void _navigateToAttendanceList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendanceListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Screen'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_status,
                  style: TextStyle(
                      color: _isCapturing ? Colors.green : Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(_isCapturing ? Icons.stop : Icons.play_arrow),
                label: Text(_isCapturing ? 'Stop Capture' : 'Start Capture'),
                onPressed:
                    _isCapturing ? _stopScreenCapture : _startScreenCapture,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Note'),
                onPressed: _uploadNote,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.people),
                label: const Text('View Connected Students'),
                onPressed: _openConnectedStudentsSheet,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('View Attendance'),
                onPressed: _navigateToAttendanceList,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopScreenCapture();
    _socketService.stopServer();
    if (_isForegroundServiceRunning) {
      ForegroundService.stopForegroundService();
    }
    super.dispose();
  }
}
