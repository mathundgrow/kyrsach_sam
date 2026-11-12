import 'dart:io';

import '../models/class_node.dart';
import '../models/class_relation.dart';
import 'parsers/language_parser.dart';
import 'parsers/dart_parser.dart';
import 'parsers/python_parser.dart';
import 'parsers/csharp_parser.dart';

class ProjectScanner {
  final List<LanguageParser> _parsers = [
    DartParser(),
    PythonParser(),
    CSharpParser(),
  ];

  Future<(List<ClassNode>, List<ClassRelation>, int)> scanProject(
    String rootPath,
  ) async {
    final allNodes = <ClassNode>[];
    final allRelations = <ClassRelation>[];
    int filesCount = 0;

    final dir = Directory(rootPath);
    if (!await dir.exists()) return (allNodes, allRelations, filesCount);

    final filesToParse = <File>[];
    final parsersForFiles = <LanguageParser>[];
    final ignoredFolders = [
      '.venv',
      'venv',
      'node_modules',
      '.git',
      'build',
      '__pycache__',
    ];

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          // Проверяем, не лежит ли файл в мусорной папке
          bool isIgnored = false;
          for (final folder in ignoredFolders) {
            if (entity.path.contains('/$folder/') ||
                entity.path.contains('\\$folder\\')) {
              isIgnored = true;
              break;
            }
          }
          if (isIgnored) continue;

          // Игнорируем слишком большие файлы (больше 1 МБ)
          try {
            final size = await entity.length();
            if (size > 1024 * 1024) continue;
          } catch (_) {
            continue;
          }

          // Ищем подходящий парсер
          for (final parser in _parsers) {
            if (parser.canParse(entity.path)) {
              filesToParse.add(entity);
              parsersForFiles.add(parser);
              filesCount++;
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка при чтении директории: $e');
    }

    // ПРОХОД 1: Находим все классы
    for (int i = 0; i < filesToParse.length; i++) {
      final nodes = await parsersForFiles[i].extractClasses(filesToParse[i]);
      allNodes.addAll(nodes);
    }

    // Создаем словарь для связывания классов из разных файлов
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

      for (final rel in relations) {
        final realToId = classIdMap[rel.toClassId];
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

    // УДАЛЯЕМ ДУБЛИКАТЫ: используем Map, где ключ — это ID класса
    final uniqueNodesMap = <String, ClassNode>{};
    for (final node in allNodes) {
      uniqueNodesMap[node.id] = node;
    }
    final uniqueNodes = uniqueNodesMap.values.toList();

    print(
      'Сканирование завершено. Файлов: $filesCount, Классов: ${uniqueNodes.length}, Связей: ${allRelations.length}',
    );
    return (
      uniqueNodes,
      allRelations,
      filesCount,
    ); // Возвращаем очищенный список
  }
}
