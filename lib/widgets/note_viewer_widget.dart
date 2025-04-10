import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../models/note_model.dart';

class NoteViewerWidget extends StatelessWidget {
  final List<NoteModel> notes;

  const NoteViewerWidget({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(child: Text("No notes received yet."));
    }

    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isPDF = note.filePath.toLowerCase().endsWith('.pdf');

        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            leading: Icon(
              isPDF ? Icons.picture_as_pdf : Icons.text_snippet,
              color: isPDF ? Colors.red : Colors.white,
            ),
            title:
                Text(note.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              'Received: ${note.receivedAt}',
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () async {
              if (await File(note.filePath).exists()) {
                OpenFile.open(note.filePath);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("File not found")),
                );
              }
            },
          ),
        );
      },
    );
  }
}
