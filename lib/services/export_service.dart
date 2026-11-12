import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

// Сохранение отчёта на компьютер через системный диалог
class ExportService {
  Future<String?> saveTextReport(String fileName, String content) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Сохранить отчёт',
      fileName: fileName,
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(utf8.encode(content)),
    );

    if (uri == null) return null;

    // На macOS это обычный file:/// путь
    return uri.path.isNotEmpty ? uri.path : uri.toString();
  }
}
