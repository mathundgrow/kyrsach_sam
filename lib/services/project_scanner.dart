import 'dart:io';

import 'package:code_graph/services/parsers/csharp_parser.dart';
import 'package:code_graph/services/parsers/python_parser.dart';

import '../models/class_node.dart';
import '../models/class_relation.dart';
import 'parsers/dart_parser.dart';
import 'parsers/language_parser.dart';

class ProjectScanner {
  final List<LanguageParser> _parsers = [
    DartParser(),
    PythonParser(),
    CSharpParser(),
  ];

  Future<(List<ClassNode>, List<ClassRelation>)> scanProject(
    String rootPath,
  ) async {
    final allNodes = <ClassNode>[];
    final allRelations = <ClassRelation>[];

    // 1. Собираем все файлы, которые умеем парсить
    final dir = Directory(rootPath);
    if (!await dir.exists()) return (allNodes, allRelations);

    final filesToParse = <File>[];
    final parsersForFiles = <LanguageParser>[];

    // Список папок, которые мы НЕ хотим сканировать (зависимости, кеш и т.д.)
    final ignoredPaths = [
      '/.venv/',
      '/venv/',
      '/node_modules/',
      '/.git/',
      '/build/',
      '/__pycache__/',
    ];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        // Если путь к файлу содержит игнорируемую папку — пропускаем его
        if (ignoredPaths.any((path) => entity.path.contains(path))) {
          continue;
        }
        for (final parser in _parsers) {
          if (parser.canParse(entity.path)) {
            filesToParse.add(entity);
            parsersForFiles.add(parser);
            break;
          }
        }
      }
    }

    // ПРОХОД 1: Находим все классы
    for (int i = 0; i < filesToParse.length; i++) {
      final nodes = await parsersForFiles[i].extractClasses(filesToParse[i]);
      allNodes.addAll(nodes);
    }

    // Создаем словарь: ИмяКласса -> Уникальный ID
    // Это нужно, чтобы связать классы из разных файлов
    final classIdMap = <String, String>{};
    final knownClassNames = <String>{};
    for (final node in allNodes) {
      classIdMap[node.name] = node.id;
      knownClassNames.add(node.name);
    }

    // ПРОХОД 2: Ищем связи
    for (int i = 0; i < filesToParse.length; i++) {
      final relations = await parsersForFiles[i].extractRelations(
        filesToParse[i],
        knownClassNames,
      );

      // Заменяем временные имена на реальные ID классов
      for (final rel in relations) {
        final realToId = classIdMap[rel.toClassId]; // Ищем ID по имени
        if (realToId != null) {
          allRelations.add(
            ClassRelation(
              fromClassId: rel.fromClassId,
              toClassId: realToId,
              type: rel.type,
            ),
          );
        }
      }
    }

    print(
      'Сканирование завершено. Классов: ${allNodes.length}, Связей: ${allRelations.length}',
    );
    return (allNodes, allRelations);
  }
}
