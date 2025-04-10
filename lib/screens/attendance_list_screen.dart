// screens/attendance_list_screen.dart
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

class AttendanceListScreen extends StatefulWidget {
  @override
  _AttendanceListScreenState createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  String? selectedDate;
  List<String> dates = [];
  List<Attendance> attendanceList = [];

  final AttendanceService service = AttendanceService();

  @override
  void initState() {
    super.initState();
    loadDates();
  }

  void loadDates() async {
    final loadedDates = await service.getAllDates();
    setState(() {
      dates = loadedDates;
      if (dates.isNotEmpty) selectedDate = dates.first;
    });
    if (dates.isNotEmpty) loadAttendanceForDate(dates.first);
  }

  void loadAttendanceForDate(String date) async {
    final data = await service.getAttendanceByDate(date);
    setState(() {
      attendanceList = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("View Attendance")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButton<String>(
              value: selectedDate,
              isExpanded: true,
              hint: Text("Select Date"),
              items: dates
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedDate = val;
                  });
                  loadAttendanceForDate(val);
                }
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: attendanceList.length,
              itemBuilder: (context, index) {
                final att = attendanceList[index];
                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text(att.name),
                  subtitle: Text("Roll No: ${att.rollNumber}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
