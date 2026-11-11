import 'package:equatable/equatable.dart';

class RecentProject extends Equatable {
  final String name;
  final String path;
  final DateTime lastOpened;

  const RecentProject({
    required this.name,
    required this.path,
    required this.lastOpened,
  });

  // Превращаем в JSON для сохранения
  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'lastOpened': lastOpened.toIso8601String(),
  };

  // Достаем из JSON при загрузке
  factory RecentProject.fromJson(Map<String, dynamic> json) {
    return RecentProject(
      name: json['name'],
      path: json['path'],
      lastOpened: DateTime.parse(json['lastOpened']),
    );
  }

  @override
  List<Object?> get props => [name, path, lastOpened];
}