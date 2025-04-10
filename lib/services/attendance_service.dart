// services/attendance_service.dart
import '../db/database_helper.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final dbHelper = DatabaseHelper();

  Future<void> markAttendance(List<Attendance> list) async {
    for (final att in list) {
      await dbHelper.insertAttendance(att);
    }
  }

  Future<List<Attendance>> getAttendanceByDate(String date) async {
    return await dbHelper.getAttendanceByDate(date);
  }

  Future<List<String>> getAllDates() async {
    return await dbHelper.getAllAttendanceDates();
  }
}
