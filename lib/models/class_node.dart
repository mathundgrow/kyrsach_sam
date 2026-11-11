import 'package:equatable/equatable.dart';

class ClassNode extends Equatable {
  final String id; // Уникальный ID (например, путь к файлу + имя класса)
  final String name; // Имя класса
  final String filePath; // Где находится
  final String language; // dart, csharp, python

  const ClassNode({
    required this.id,
    required this.name,
    required this.filePath,
    required this.language,
  });

  @override
  List<Object?> get props => [id, name, filePath, language];
}