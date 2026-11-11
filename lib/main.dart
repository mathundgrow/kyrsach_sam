import 'package:file_picker/file_picker.dart'; // Импорт выбора папки
import 'package:flutter/material.dart';

import 'models/class_node.dart';
import 'services/project_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<ClassNode> _foundClasses = [];
  bool _isLoading = false;
  String _selectedPath = 'Папка не выбрана';

  // ТЕСТОВЫЙ МЕТОД: Выбор папки и сканирование
  Future<void> _pickAndScanFolder() async {
    
    // 1. Открываем диалог выбора папки
    String? selectedDirectory = await FilePicker.getDirectoryPath();

    if (selectedDirectory == null) {
      // Пользователь закрыл диалог, ничего не выбрал
      return;
    }

    // 2. Обновляем состояние (показываем загрузку)
    setState(() {
      _isLoading = true;
      _selectedPath = selectedDirectory;
      _foundClasses = []; // Очищаем предыдущий результат
    });

    print('--- ДИАГНОСТИКА ---');
    print('Выбрана папка: $selectedDirectory');

    // 3. Запускаем сканер
    final scanner = ProjectScanner();
    final (nodes, relations) = await scanner.scanProject(selectedDirectory);

    print('--- РЕЗУЛЬТАТ СКАНИРОВАНИЯ ---');
    print('Найдено классов: ${nodes.length}');
    for (var node in nodes) {
      print('Класс: ${node.name} | Файл: ${node.filePath}');
    }
    print('-----------------------------');

    // 4. Обновляем UI
    setState(() {
      _foundClasses = nodes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Тест сканера классов')),
        body: Column(
          children: [
            // Блок с кнопкой и текущим путем
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Выбранный путь: $_selectedPath'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickAndScanFolder,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Выбрать папку проекта'),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Список найденных классов
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _foundClasses.isEmpty
                  ? const Center(
                      child: Text('Классы не найдены. Выберите папку.'),
                    )
                  : ListView.builder(
                      itemCount: _foundClasses.length,
                      itemBuilder: (context, index) {
                        final cls = _foundClasses[index];
                        return ListTile(
                          leading: const Icon(Icons.class_),
                          title: Text(cls.name),
                          // Показываем только имя файла, чтобы не было слишком длинно
                          subtitle: Text(cls.filePath.split('/').last),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
