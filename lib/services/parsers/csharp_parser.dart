import 'dart:io';

import '../../models/class_node.dart';
import '../../models/class_relation.dart';
import 'language_parser.dart';

class CSharpParser implements LanguageParser {
  @override
  String get languageName => 'C#';

  @override
  bool canParse(String filePath) => filePath.endsWith('.cs');

  // ^\s* — гарантирует, что мы ищем в начале строки
  final _classRegex = RegExp(
    r'^\s*(?:public|private|protected|internal)?\s*(?:static|abstract|sealed|partial)?\s*class\s+([a-zA-Z_]\w*)(?:\s*:\s*([a-zA-Z_0-9,\s\.]+))?',
    multiLine: true,
  );

  final _usageRegex = RegExp(r'\b([A-Z]\w*)\s+[a-zA-Z_]\w*\s*(?:;|\{)');

  @override
  Future<List<ClassNode>> extractClasses(File file) async {
    final nodes = <ClassNode>[];

    try {
      final content = await file.readAsString();

      final matches = _classRegex.allMatches(content);

      for (final match in matches) {
        final className = match.group(1)!;
        nodes.add(
          ClassNode(
            id: '${file.path}:$className',
            name: className,
            filePath: file.path,
            language: languageName,
          ),
        );
      }
    } catch (e) {
      print('Ошибка чтения файла ${file.path}: $e');
    }

    return nodes;
  }

  @override
  Future<List<ClassRelation>> extractRelations(
    File file,
    Set<String> knownClassNames,
  ) async {
    final relations = <ClassRelation>[];
    final content = await file.readAsString();
    final lines = content.split('\n');
    String? currentClassName;

    for (final line in lines) {
      // 1. Ищем класс и наследование
      final classMatch = _classRegex.firstMatch(line);
      if (classMatch != null) {
        currentClassName = classMatch.group(1)!;
        final basesStr = classMatch.group(2);

        if (basesStr != null) {
          final bases = basesStr.split(',').map((e) => e.trim());
          for (final base in bases) {
            // Отсекаем дженерики <T> и namespace (System.Web)
            final cleanBase = base.split('<').first.split('.').last.trim();
            if (knownClassNames.contains(cleanBase)) {
              relations.add(
                ClassRelation(
                  fromClassId: '${file.path}:$currentClassName',
                  toClassId: cleanBase,
                  type: 'inheritance',
                ),
              );
            }
          }
        }
      }
      // 2. Ищем использование внутри класса
      else if (currentClassName != null) {
        final usageMatches = _usageRegex.allMatches(line);
        for (final match in usageMatches) {
          final usedType = match.group(1)!;
          if (knownClassNames.contains(usedType) &&
              usedType != currentClassName) {
            relations.add(
              ClassRelation(
                fromClassId: '${file.path}:$currentClassName',
                toClassId: usedType,
                type: 'usage',
              ),
            );
          }
        }
      }
    }
    return relations;
  }
}
