import 'package:equatable/equatable.dart';

class ClassRelation extends Equatable {
  final String fromClassId; // Кто использует
  final String toClassId; // Кого используют
  final String type; // 'inheritance', 'dependency', 'usage'

  const ClassRelation({
    required this.fromClassId,
    required this.toClassId,
    this.type = 'dependency',
  });

  @override
  List<Object?> get props => [fromClassId, toClassId, type];
}
