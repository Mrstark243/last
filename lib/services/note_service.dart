import 'dart:convert';
import 'dart:io';

class NoteService {
  // List to store all connected student WebSocket connections
  static List<WebSocket> connectedStudents = [];

  // Add a new student's WebSocket to the list
  static void addStudentSocket(WebSocket socket) {
    connectedStudents.add(socket);
    print('Student connected: ${socket.hashCode}');
  }

  // Remove a student's WebSocket from the list
  static void removeStudentSocket(WebSocket socket) {
    connectedStudents.remove(socket);
    print('Student disconnected: ${socket.hashCode}');
  }

  // Broadcast a note to all connected students
  static void sendNoteToAll(String note) {
    final message = jsonEncode({'type': 'note', 'data': note});
    for (var socket in connectedStudents) {
      try {
        socket.add(message);
        print('Note sent to student: ${socket.hashCode}');
      } catch (e) {
        print('Error sending note to student: $e');
      }
    }
  }
}
