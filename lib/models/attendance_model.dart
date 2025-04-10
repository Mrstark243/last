// models/attendance_model.dart
class Attendance {
  final String name;
  final String rollNumber;
  final String date;

  Attendance({
    required this.name,
    required this.rollNumber,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'roll_number': rollNumber,
      'date': date,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      name: map['name'],
      rollNumber: map['roll_number'],
      date: map['date'],
    );
  }
}
