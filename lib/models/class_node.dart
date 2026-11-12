import 'package:equatable/equatable.dart';

class ClassNode extends Equatable {
  final String id; // Уникальный ID (например, путь к файлу + имя класса)
  final String name; // Имя класса
  final String filePath; // Где находится
  final int line; // Номер строки объявления класса
  final String language; // dart, csharp, python
  final bool isAbstract; // Абстрактный класс или интерфейс

  const ClassNode({
    required this.id,
    required this.name,
    required this.filePath,
    this.line = 1,
    required this.language,
    this.isAbstract = false,
  });

  @override
  List<Object?> get props => [id, name, filePath, line, language, isAbstract];
}
