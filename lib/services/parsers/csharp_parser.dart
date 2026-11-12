import 'dart:io';

import '../../models/class_node.dart';
import '../../models/class_relation.dart';
import 'language_parser.dart';

class CSharpParser implements LanguageParser {
  @override
  String get languageName => 'C#';

  @override
  bool canParse(String filePath) => filePath.endsWith('.cs');

  // Ищем классы и интерфейсы. Интерфейс считаем абстрактным типом.
  final _typeRegex = RegExp(
    r'^\s*(?:public|private|protected|internal)?\s*(?:(?:static|abstract|sealed|partial)\s+)*(class|interface)\s+([a-zA-Z_]\w*)(?:\s*:\s*([a-zA-Z_0-9,\s\.<>]+))?',
    multiLine: true,
  );

  final _usageRegex = RegExp(r'\b([A-Z]\w*)\s+[a-zA-Z_]\w*\s*(?:;|\{)');

  bool _isAbstractMatch(RegExpMatch match) {
    return match.group(1) == 'interface' ||
        RegExp(r'\babstract\b').hasMatch(match.group(0)!);
  }

  @override
  Future<List<ClassNode>> extractClasses(File file) async {
    final nodes = <ClassNode>[];

    try {
      final content = await file.readAsString();

      final matches = _typeRegex.allMatches(content);

      for (final match in matches) {
        final className = match.group(2)!;
        final classIndex = match.start + match.group(0)!.indexOf(className);
        final line =
            '\n'.allMatches(content.substring(0, classIndex)).length + 1;
        nodes.add(
          ClassNode(
            id: '${file.path}:$className',
            name: className,
            filePath: file.path,
            line: line,
            language: languageName,
            isAbstract: _isAbstractMatch(match),
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
      // 1. Ищем класс/интерфейс и наследование
      final classMatch = _typeRegex.firstMatch(line);
      if (classMatch != null) {
        currentClassName = classMatch.group(2)!;
        final basesStr = classMatch.group(3);

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
