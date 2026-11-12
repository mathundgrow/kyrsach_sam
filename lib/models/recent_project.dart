import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

// В истории храним ТОЛЬКО путь к проекту.
// Никакие классы, связи и графы не сохраняются: при открытии всё
// сканируется заново.
class RecentProject extends Equatable {
  final String path;

  const RecentProject({required this.path});

  // Имя папки всегда можно получить из пути
  String get name => p.basename(path);

  Map<String, dynamic> toJson() => {'path': path};

  factory RecentProject.fromJson(Map<String, dynamic> json) {
    return RecentProject(path: json['path'] as String);
  }

  @override
  List<Object?> get props => [path];
}
