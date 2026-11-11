import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/recent_project.dart';
import '../services/storage_service.dart';
import 'analysis_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final StorageService _storage = StorageService();
  List<RecentProject> _recentProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentProjects();
  }

  Future<void> _loadRecentProjects() async {
    final projects = await _storage.getRecentProjects();
    if (!mounted) return; // Защита от обновления закрытого экрана
    setState(() {
      _recentProjects = projects;
      _isLoading = false;
    });
  }

  // Переход к анализу проекта
  Future<void> _openProject(String path) async {
    final projectName = p.basename(path); // Берем имя папки как название проекта
    final newProject = RecentProject(
      name: projectName,
      path: path,
      lastOpened: DateTime.now(),
    );

    // Сохраняем в историю
    await _storage.addRecentProject(newProject);

    if (!mounted) return;

    // Переходим на экран анализа
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                AnalysisPage(projectPath: path, projectName: projectName),
          ),
        )
        .then((_) => _loadRecentProjects()); // Обновляем историю при возврате
  }

  // Метод для удаления проекта
  Future<void> _removeProject(String path) async {
    await _storage.removeRecentProject(path);
    _loadRecentProjects(); // Обновляем список на экране
  }

  // Открытие системного проводника
  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null) {
      await _openProject(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ЛЕВАЯ ПАНЕЛЬ: История проектов
          Container(
            width: 300,
            decoration: const BoxDecoration(
              color: Color(0xFF252526),
              border: Border(right: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Ранее открытые',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _recentProjects.isEmpty
                          ? const Center(
                              child: Text(
                                'История пуста',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _recentProjects.length,
                              itemBuilder: (context, index) {
                                final project = _recentProjects[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.folder,
                                    color: Colors.purpleAccent,
                                  ),
                                  title: Text(
                                    project.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    project.path,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _openProject(project.path),
                                  // Кнопка удаления
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white54,
                                      size: 18,
                                    ),
                                    tooltip: 'Удалить из истории',
                                    onPressed: () => _removeProject(project.path),
                                    hoverColor: Colors.red.withValues(alpha: 0.2),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          
          // ПРАВАЯ ЧАСТЬ: Приветствие
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Графовый ИИ Анализатор',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Анализ архитектуры вашего проекта.\nПостроение графа классов и связей.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _pickFolder,
                    icon: const Icon(Icons.folder_open, size: 28),
                    label: const Text(
                      'Открыть проект',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}