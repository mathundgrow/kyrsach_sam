import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../models/class_node.dart';
import '../models/class_relation.dart';

class GraphViewWidget extends StatelessWidget {
  final List<ClassNode> nodes;
  final List<ClassRelation> relations;
  final Function(ClassNode) onNodeTap;
  final Set<String> anomalyNodeIds;
  final String? selectedNodeId;

  const GraphViewWidget({
    super.key,
    required this.nodes,
    required this.relations,
    required this.onNodeTap,
    required this.anomalyNodeIds,
    this.selectedNodeId,
  });

  Widget _buildNodeWidget(ClassNode classNode) {
    final isAnomaly = anomalyNodeIds.contains(classNode.id);
    final isSelected = classNode.id == selectedNodeId;

    // Определяем цвет узла
    Color nodeColor = const Color(0xFF6C5CE7); // Фиолетовый по умолчанию
    if (isAnomaly) nodeColor = const Color(0xFFE74C3C); // Красный, если аномалия
    if (isSelected) nodeColor = const Color(0xFF00B894); // Зеленый, если выбран

    return GestureDetector(
      onTap: () => onNodeTap(classNode),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 140,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: nodeColor,
            borderRadius: BorderRadius.circular(8),
            // Если выбран — делаем толстую белую рамку
            border: Border.all(
              color: isSelected ? Colors.white : (isAnomaly ? Colors.redAccent : Colors.white24),
              width: isSelected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                // Если выбран — добавляем яркое свечение
                color: isSelected ? Colors.greenAccent.withOpacity(0.6) : Colors.black.withOpacity(0.5),
                blurRadius: isSelected ? 15 : 4,
                offset: const Offset(2, 2),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAnomaly) ...[
                      const Icon(Icons.warning, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        classNode.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  classNode.language,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(child: Text('Нет классов для отображения', style: TextStyle(color: Colors.white)));
    }

    // Если связей нет, просто выводим сеткой
    if (relations.isEmpty) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: Center(
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: nodes.map((n) => _buildNodeWidget(n)).toList(),
          ),
        ),
      );
    }

    final Graph graph = Graph();
    final Map<String, Node> nodeMap = {};

    for (final classNode in nodes) {
      final node = Node.Id(classNode.id);
      nodeMap[classNode.id] = node;
      graph.addNode(node);
    }

    for (final relation in relations) {
      final fromNode = nodeMap[relation.fromClassId];
      final toNode = nodeMap[relation.toClassId];

      if (fromNode != null && toNode != null) {
        graph.addEdge(fromNode, toNode);
      }
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(2000),
        minScale: 0.1,
        maxScale: 3.0,
        child: GraphView(
          graph: graph,
          // ВОТ ОНО: Структурированный алгоритм Сугиямы (слоями слева направо)
          algorithm: SugiyamaAlgorithm(
            SugiyamaConfiguration()
              ..orientation = SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT
              ..nodeSeparation = 50
              ..levelSeparation = 100,
          ),
          builder: (Node node) {
            final classNode = nodes.firstWhere(
              (n) => n.id == node.key!.value,
              orElse: () => nodes.first,
            );
            return _buildNodeWidget(classNode);
          },
        ),
      ),
    );
  }
}