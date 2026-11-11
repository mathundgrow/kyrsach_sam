import 'dart:io';

import '../../models/class_node.dart';
import '../../models/class_relation.dart';
import 'language_parser.dart';

class PythonParser implements LanguageParser {
  @override
  String get languageName => 'Python';

  @override
  bool canParse(String filePath) => filePath.endsWith('.py');

  // ^\s* — означает, что слово class должно стоять в начале строки (с учетом отступов)
  final _classRegex = RegExp(
    r'^\s*class\s+([a-zA-Z_]\w*)\s*(?:\(([^)]*)\))?',
    multiLine: true,
  );

  // Ищем type hints, но только там, где есть имя переменной перед двоеточием: var_name: MyClass
  final _usageRegex = RegExp(r'\b\w+\s*:\s*([A-Z]\w*)');

  @override
  Future<List<ClassNode>> extractClasses(File file) async {
    final nodes = <ClassNode>[];

    try {
      final content = await file.readAsString();

      // Ищем все совпадения во всем файле
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
      // 1. Ищем объявление класса и его родителей
      final classMatch = _classRegex.firstMatch(line);
      if (classMatch != null) {
        currentClassName = classMatch.group(1)!;
        final parentsStr = classMatch.group(2);

        if (parentsStr != null) {
          final parents = parentsStr.split(',').map((e) => e.trim());
          for (final parent in parents) {
            if (parent.isEmpty) continue;
            // Убираем модули, если написано types.MyClass -> MyClass
            final cleanParent = parent.split('.').last.trim();
            if (knownClassNames.contains(cleanParent)) {
              relations.add(
                ClassRelation(
                  fromClassId: '${file.path}:$currentClassName',
                  toClassId: cleanParent,
                  type: 'inheritance',
                ),
              );
            }
          }
        }
      }
      // 2. Ищем использование классов (если мы внутри класса)
      else if (currentClassName != null) {
        final usageMatch = _usageRegex.firstMatch(line);
        if (usageMatch != null) {
          final usedType = usageMatch.group(1)!;
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
