class NoteModel {
  final String title;
  final String filePath;
  final DateTime receivedAt;

  NoteModel({
    required this.title,
    required this.filePath,
    required this.receivedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'filePath': filePath,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      title: map['title'],
      filePath: map['filePath'],
      receivedAt: DateTime.parse(map['receivedAt']),
    );
  }
}
