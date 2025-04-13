// screens/connected_students_sheet.dart
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import 'package:intl/intl.dart';

class ConnectedStudentsSheet extends StatelessWidget {
  final List<Map<String, String>>
      connectedStudents; // [{'name': 'John', 'roll': '101'}]

  const ConnectedStudentsSheet({super.key, required this.connectedStudents});

  void _markAttendance(BuildContext context) async {
    final service = AttendanceService();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final records = connectedStudents.map((student) {
      return Attendance(
        name: student['name'] ?? '',
        rollNumber: student['roll'] ?? '',
        date: date,
      );
    }).toList();

    await service.markAttendance(records);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Attendance marked for ${records.length} students')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const Text("Connected Students",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: connectedStudents.length,
                itemBuilder: (context, index) {
                  final student = connectedStudents[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(student['name'] ?? ''),
                    subtitle: Text("Roll No: ${student['roll'] ?? ''}"),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () => _markAttendance(context),
              child: const Text("Mark Attendance"),
            )
          ],
        ),
      ),
    );
  }
}
