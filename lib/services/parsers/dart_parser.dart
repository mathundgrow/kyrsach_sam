import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../../models/class_node.dart';
import '../../models/class_relation.dart';
import 'language_parser.dart';

class DartParser implements LanguageParser {
  @override
  String get languageName => 'Dart';

  @override
  bool canParse(String filePath) => filePath.endsWith('.dart');

  @override
  Future<List<ClassNode>> extractClasses(File file) async {
    final nodes = <ClassNode>[];
    try {
      final content = await file.readAsString();
      final parseResult = parseString(
        content: content,
        throwIfDiagnostics: false,
      );

      for (final declaration in parseResult.unit.declarations) {
        if (declaration is ClassDeclaration) {
          nodes.add(
            ClassNode(
              id: '${file.path}:${declaration.namePart.typeName.lexeme}',
              name: declaration.namePart.typeName.lexeme,
              filePath: file.path,
              language: languageName,
            ),
          );
        }
      }
    } catch (e) {
      print('Ошибка парсинга классов в ${file.path}: $e');
    }
    return nodes;
  }

  @override
  Future<List<ClassRelation>> extractRelations(
    File file,
    Set<String> knownClassNames,
  ) async {
    final relations = <ClassRelation>[];
    try {
      final content = await file.readAsString();
      final parseResult = parseString(
        content: content,
        throwIfDiagnostics: false,
      );

      for (final declaration in parseResult.unit.declarations) {
        if (declaration is ClassDeclaration) {
          final fromClassName = declaration.namePart.typeName.lexeme;
          final fromClassId = '${file.path}:$fromClassName';

          // 1. ИЩЕМ НАСЛЕДОВАНИЕ (extends / implements / with)
          final superTypes = <String>[];
          if (declaration.extendsClause != null) {
            superTypes.add(declaration.extendsClause!.superclass.name.lexeme);
          }
          if (declaration.implementsClause != null) {
            for (final type in declaration.implementsClause!.interfaces) {
              superTypes.add(type.name.lexeme);
            }
          }
          if (declaration.withClause != null) {
            for (final type in declaration.withClause!.mixinTypes) {
              superTypes.add(type.name.lexeme);
            }
          }

          for (final superType in superTypes) {
            if (knownClassNames.contains(superType)) {
              relations.add(
                ClassRelation(
                  fromClassId: fromClassId,
                  toClassId: _findIdByName(
                    superType,
                  ), // Найдем ID целевого класса
                  type: 'inheritance',
                ),
              );
            }
          }

          // 2. ИЩЕМ ИСПОЛЬЗОВАНИЕ (поля класса, например: MyOtherClass myVar;)
          for (final member in declaration.body.members ?? <ClassMember>[]) {
            if (member is FieldDeclaration) {
              final type = member.fields.type?.toSource();
              if (type != null && knownClassNames.contains(type)) {
                relations.add(
                  ClassRelation(
                    fromClassId: fromClassId,
                    toClassId: _findIdByName(type),
                    type: 'usage',
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка парсинга связей в ${file.path}: $e');
    }
    return relations;
  }

  // Вспомогательный метод, чтобы не дублировать код поиска ID
  String _findIdByName(String name) {
    // Временный костыль, ID мы пересоберем в сканере
    return name;
  }
}
