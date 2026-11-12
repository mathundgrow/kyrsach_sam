import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_project.dart';

class StorageService {
  static const _key = 'recent_projects';
  static const _ignoredPrefix = 'ignored_anomalies:';

  // Получить список ранее открытых
  Future<List<RecentProject>> getRecentProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => RecentProject.fromJson(e)).toList();
  }

  // Добавить проект в историю (и обновить время, если он там уже есть)
  Future<void> addRecentProject(RecentProject project) async {
    final projects = await getRecentProjects();

    // Удаляем старую запись с таким же путем
    projects.removeWhere((p) => p.path == project.path);

    // Добавляем в начало (самый новый)
    projects.insert(0, project);

    // Оставляем только 10 последних, чтобы не засорять память
    if (projects.length > 10) {
      projects.removeRange(10, projects.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(projects.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  // Удалить проект из истории по его пути
  Future<void> removeRecentProject(String path) async {
    final projects = await getRecentProjects();

    // Удаляем проект с таким путем
    projects.removeWhere((p) => p.path == path);

    // Сохраняем обновленный список
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(projects.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  // ==================== ИСКЛЮЧЁННЫЕ АНОМАЛИИ ====================
  // Для каждого проекта храним свой набор ID классов, которые
  // пользователь признал допустимыми ("это не аномалия").

  Future<Set<String>> getIgnoredAnomalies(String projectPath) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_ignoredPrefix$projectPath');
    if (jsonString == null) return <String>{};

    try {
      final List<dynamic> ids = jsonDecode(jsonString);
      return ids.map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveIgnoredAnomalies(String projectPath, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(ids.toList());
    await prefs.setString('$_ignoredPrefix$projectPath', jsonString);
  }
}
