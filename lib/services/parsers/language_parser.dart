import 'dart:io';
import '../../models/class_node.dart';
import '../../models/class_relation.dart';

abstract class LanguageParser {
  String get languageName;
  bool canParse(String filePath);

  // Первый проход: просто найти классы в файле
  Future<List<ClassNode>> extractClasses(File file);

  // Второй проход: найти связи. Передаем имена всех известных классов.
  Future<List<ClassRelation>> extractRelations(File file, Set<String> knownClassNames);
}