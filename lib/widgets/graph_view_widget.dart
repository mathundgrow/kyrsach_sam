import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/class_node.dart';
import '../models/class_relation.dart';

// ==================== ЦВЕТА И КОНСТАНТЫ ====================
const Color _abstractColor = Color(0xFFE67E22);
const Color _anomalyColor = Color(0xFFE74C3C);
const Color _ignoredAnomalyColor = Color(0xFF2E7D32);
const Color _selectedColor = Color(0xFFFFD54F);

// Обычные классы — нейтральные серые.
const Color _regularColor = Color(0xFF4A4A4D);

// Два направления связей выбранного класса.
const Color incomingRelationColor = Color(
  0xFF29B6F6,
); // используют/наследуют его
const Color outgoingRelationColor = Color(
  0xFF4CAF50,
); // он использует/наследует

const double _nodeWidth = 164;
const double _nodeHeight = 68;
const double _nodeGapX = 16;
const double _nodeGapY = 14;
const double _clusterPadding = 18;
const double _clusterHeaderHeight = 54;
const double _clusterGap = 26;
const double _canvasPadding = 24;

class GraphViewWidget extends StatelessWidget {
  final List<ClassNode> nodes;
  final List<ClassRelation> relations;
  final Function(ClassNode) onNodeTap;
  final Set<String> anomalyNodeIds;
  final Set<String> ignoredAnomalyIds;
  final String? selectedNodeId;

  // Ограничение на количество отрисованных виджетов. Остальные классы
  // не теряются: в шапке графа показывается, сколько скрыто.
  static const int maxRenderedNodes = 400;

  const GraphViewWidget({
    super.key,
    required this.nodes,
    required this.relations,
    required this.onNodeTap,
    required this.anomalyNodeIds,
    this.ignoredAnomalyIds = const {},
    this.selectedNodeId,
  });

  // Для больших проектов сначала показываем самое важное:
  // аномалии, исключённые аномалии, абстракции, затем более связанные классы.
  List<ClassNode> _limitNodes() {
    if (nodes.length <= maxRenderedNodes) return nodes;

    final degree = <String, int>{};
    for (final relation in relations) {
      degree[relation.fromClassId] = (degree[relation.fromClassId] ?? 0) + 1;
      degree[relation.toClassId] = (degree[relation.toClassId] ?? 0) + 1;
    }

    int priority(ClassNode node) {
      if (anomalyNodeIds.contains(node.id)) return 0;
      if (ignoredAnomalyIds.contains(node.id)) return 1;
      if (node.isAbstract) return 2;
      return 3;
    }

    final ordered = [...nodes]
      ..sort((a, b) {
        final byPriority = priority(a).compareTo(priority(b));
        if (byPriority != 0) return byPriority;

        final byDegree = (degree[b.id] ?? 0).compareTo(degree[a.id] ?? 0);
        if (byDegree != 0) return byDegree;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ordered.take(maxRenderedNodes).toList();
  }

  List<_GraphCluster> _buildClusters(List<ClassNode> visibleNodes) {
    final anomalies = <ClassNode>[];
    final ignored = <ClassNode>[];
    final abstracts = <ClassNode>[];
    final regular = <ClassNode>[];

    for (final node in visibleNodes) {
      if (anomalyNodeIds.contains(node.id)) {
        anomalies.add(node);
      } else if (ignoredAnomalyIds.contains(node.id)) {
        ignored.add(node);
      } else if (node.isAbstract) {
        abstracts.add(node);
      } else {
        regular.add(node);
      }
    }

    int byName(ClassNode a, ClassNode b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    anomalies.sort(byName);
    ignored.sort(byName);
    abstracts.sort(byName);
    regular.sort(byName);

    return [
      if (anomalies.isNotEmpty)
        _GraphCluster(
          title: 'Аномалии',
          subtitle: 'много входящих зависимостей',
          icon: Icons.warning_amber_rounded,
          color: _anomalyColor,
          nodes: anomalies,
        ),
      if (ignored.isNotEmpty)
        _GraphCluster(
          title: 'Исключённые аномалии',
          subtitle: 'отмечены как допустимые',
          icon: Icons.verified,
          color: _ignoredAnomalyColor,
          nodes: ignored,
        ),
      if (abstracts.isNotEmpty)
        _GraphCluster(
          title: 'Абстракции',
          subtitle: 'абстрактные классы и интерфейсы',
          icon: Icons.account_tree,
          color: _abstractColor,
          nodes: abstracts,
        ),
      if (regular.isNotEmpty)
        _GraphCluster(
          title: 'Обычные классы',
          subtitle: 'без активных аномалий',
          icon: Icons.class_,
          color: Colors.blueGrey,
          nodes: regular,
        ),
    ];
  }

  int _columnsFor(int count) {
    if (count <= 4) return 2;
    if (count <= 12) return 3;
    if (count <= 30) return 4;
    if (count <= 60) return 5;
    return 6;
  }

  List<_ClusterLayout> _layoutClusters(List<_GraphCluster> clusters) {
    final result = <_ClusterLayout>[];
    var top = _canvasPadding;

    for (final cluster in clusters) {
      final columns = _columnsFor(cluster.nodes.length);
      final rows = (cluster.nodes.length / columns).ceil();
      final width =
          columns * _nodeWidth +
          (columns - 1) * _nodeGapX +
          _clusterPadding * 2;
      final height =
          _clusterHeaderHeight +
          rows * _nodeHeight +
          (rows - 1) * _nodeGapY +
          _clusterPadding;

      final rect = Rect.fromLTWH(_canvasPadding, top, width, height);
      final nodeRects = <Rect>[];

      for (var i = 0; i < cluster.nodes.length; i++) {
        final column = i % columns;
        final row = i ~/ columns;
        nodeRects.add(
          Rect.fromLTWH(
            rect.left + _clusterPadding + column * (_nodeWidth + _nodeGapX),
            rect.top + _clusterHeaderHeight + row * (_nodeHeight + _nodeGapY),
            _nodeWidth,
            _nodeHeight,
          ),
        );
      }

      result.add(
        _ClusterLayout(cluster: cluster, rect: rect, nodeRects: nodeRects),
      );
      top += height + _clusterGap;
    }

    return result;
  }

  Widget _buildNodeWidget(
    ClassNode classNode, {
    required bool isIncoming,
    required bool isOutgoing,
  }) {
    final isAnomaly = anomalyNodeIds.contains(classNode.id);
    final isIgnoredAnomaly =
        !isAnomaly && ignoredAnomalyIds.contains(classNode.id);
    final isSelected = classNode.id == selectedNodeId;

    // Роль класса (аномалия / абстракция / обычный) задаёт цвет по умолчанию.
    // Если класс связан с выбранным, его заливка показывает направление связи:
    // голубой — использует выбранный, зелёный — используется выбранным.
    Color fillColor = _regularColor;
    Gradient? fillGradient;
    Color borderColor = Colors.white24;
    IconData? roleIcon;

    if (classNode.isAbstract) {
      fillColor = _abstractColor;
      borderColor = Colors.orangeAccent;
      roleIcon = Icons.account_tree;
    }
    if (isIgnoredAnomaly) {
      fillColor = _ignoredAnomalyColor;
      borderColor = Colors.greenAccent;
      roleIcon = Icons.verified;
    }
    if (isAnomaly) {
      fillColor = _anomalyColor;
      borderColor = Colors.redAccent;
      roleIcon = Icons.warning_amber_rounded;
    }

    final bothDirections = isIncoming && isOutgoing;
    if (!isSelected && bothDirections) {
      // Класс связан с выбранным в обе стороны — показываем оба цвета.
      fillGradient = const LinearGradient(
        colors: [incomingRelationColor, outgoingRelationColor],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
      borderColor = Colors.white70;
    } else if (!isSelected && isIncoming) {
      fillColor = incomingRelationColor;
      borderColor = incomingRelationColor;
    } else if (!isSelected && isOutgoing) {
      fillColor = outgoingRelationColor;
      borderColor = outgoingRelationColor;
    }

    if (isSelected) {
      borderColor = _selectedColor;
    }

    final roleColor = isSelected
        ? _selectedColor
        : isIncoming
        ? incomingRelationColor
        : isOutgoing
        ? outgoingRelationColor
        : Colors.black;
    final hasGlow = isSelected || isIncoming || isOutgoing;

    final subtitle = isAnomaly
        ? '${classNode.language} · аномалия'
        : isIgnoredAnomaly
        ? '${classNode.language} · допущено'
        : classNode.isAbstract
        ? '${classNode.language} · abstract'
        : classNode.language;

    return GestureDetector(
      onTap: () => onNodeTap(classNode),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          key: ValueKey('graph-node-${classNode.id}'),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fillGradient == null ? fillColor : null,
            gradient: fillGradient,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: borderColor, width: isSelected ? 3 : 1),
            boxShadow: [
              BoxShadow(
                color: roleColor.withValues(
                  alpha: isSelected ? 0.55 : (hasGlow ? 0.4 : 0.45),
                ),
                blurRadius: hasGlow ? 14 : 4,
                offset: hasGlow ? Offset.zero : const Offset(2, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (roleIcon != null) ...[
                          Icon(roleIcon, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            classNode.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.my_location,
                    size: 12,
                    color: _selectedColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(
        child: Text(
          'Нет классов для отображения',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Связанные с выбранным классы. Учитываем и использование, и наследование:
    // входящие — классы, которые используют/наследуют выбранный,
    // исходящие — классы, которые выбранный использует/наследует.
    final incomingUsageIds = <String>{};
    final outgoingUsageIds = <String>{};
    if (selectedNodeId != null) {
      for (final relation in relations) {
        if (relation.fromClassId == relation.toClassId) continue;
        if (relation.toClassId == selectedNodeId) {
          incomingUsageIds.add(relation.fromClassId);
        }
        if (relation.fromClassId == selectedNodeId) {
          outgoingUsageIds.add(relation.toClassId);
        }
      }
      incomingUsageIds.remove(selectedNodeId);
      outgoingUsageIds.remove(selectedNodeId);
    }

    final visibleNodes = _limitNodes();
    final hiddenByLimit = nodes.length - visibleNodes.length;
    final clusters = _buildClusters(visibleNodes);
    final layouts = _layoutClusters(clusters);

    final positions = <String, Rect>{};
    for (final layout in layouts) {
      for (var i = 0; i < layout.cluster.nodes.length; i++) {
        positions[layout.cluster.nodes[i].id] = layout.nodeRects[i];
      }
    }

    var canvasWidth = 600.0;
    for (final layout in layouts) {
      canvasWidth = math.max(canvasWidth, layout.rect.right);
    }
    final canvasHeight = layouts.isEmpty
        ? 400.0
        : layouts.last.rect.bottom + _canvasPadding;
    canvasWidth += _canvasPadding;

    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          _GraphLegendBar(hasSelection: selectedNodeId != null),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(600),
                    minScale: 0.05,
                    maxScale: 2.5,
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GraphEdgesPainter(
                                relations: relations,
                                positions: positions,
                                selectedNodeId: selectedNodeId,
                              ),
                            ),
                          ),
                          for (final layout in layouts)
                            Positioned.fromRect(
                              rect: layout.rect,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: layout.cluster.color.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: layout.cluster.color.withValues(
                                        alpha: 0.32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          for (final layout in layouts)
                            Positioned(
                              left: layout.rect.left + _clusterPadding,
                              top: layout.rect.top + 12,
                              width: layout.rect.width - _clusterPadding * 2,
                              child: _ClusterHeader(cluster: layout.cluster),
                            ),
                          for (final layout in layouts)
                            for (
                              var i = 0;
                              i < layout.cluster.nodes.length;
                              i++
                            )
                              Positioned.fromRect(
                                rect: layout.nodeRects[i],
                                child: _buildNodeWidget(
                                  layout.cluster.nodes[i],
                                  isIncoming: incomingUsageIds.contains(
                                    layout.cluster.nodes[i].id,
                                  ),
                                  isOutgoing: outgoingUsageIds.contains(
                                    layout.cluster.nodes[i].id,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hiddenByLimit > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252526).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orangeAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'Показаны $maxRenderedNodes из '
                        '${nodes.length} классов',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== МОДЕЛИ РАСКЛАДКИ ====================
class _GraphCluster {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<ClassNode> nodes;

  const _GraphCluster({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.nodes,
  });
}

class _ClusterLayout {
  final _GraphCluster cluster;
  final Rect rect;
  final List<Rect> nodeRects;

  const _ClusterLayout({
    required this.cluster,
    required this.rect,
    required this.nodeRects,
  });
}

class _ClusterHeader extends StatelessWidget {
  final _GraphCluster cluster;

  const _ClusterHeader({required this.cluster});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(cluster.icon, color: cluster.color, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${cluster.title} (${cluster.nodes.length})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            cluster.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ==================== ЛЕГЕНДА ====================
class _GraphLegendBar extends StatelessWidget {
  final bool hasSelection;

  const _GraphLegendBar({required this.hasSelection});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _LegendSwatch(color: _regularColor, text: 'обычный класс'),
          const _LegendSwatch(color: _abstractColor, text: 'абстракция'),
          const _LegendSwatch(color: _anomalyColor, text: 'аномалия'),
          const _LegendSwatch(
            color: _ignoredAnomalyColor,
            text: 'исключённая аномалия',
          ),
          if (hasSelection) ...[
            const _LegendOutline(
              color: _selectedColor,
              text: 'выбранный класс',
            ),
            const _LegendSwatch(
              color: incomingRelationColor,
              text: 'используют / наследуют его',
            ),
            const _LegendSwatch(
              color: outgoingRelationColor,
              text: 'он использует / наследует',
            ),
            const _LegendSwatch(
              gradient: LinearGradient(
                colors: [incomingRelationColor, outgoingRelationColor],
              ),
              text: 'связь в обе стороны',
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final String text;

  const _LegendSwatch({required this.text, this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _LegendOutline extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendOutline({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
        ),
      ],
    );
  }
}

// ==================== РЁБРА ГРАФА ====================
class _GraphEdgesPainter extends CustomPainter {
  final List<ClassRelation> relations;
  final Map<String, Rect> positions;
  final String? selectedNodeId;

  const _GraphEdgesPainter({
    required this.relations,
    required this.positions,
    required this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = <String>{};
    final selected = selectedNodeId;

    for (final relation in relations) {
      final fromRect = positions[relation.fromClassId];
      final toRect = positions[relation.toClassId];
      if (fromRect == null || toRect == null) continue;

      final key =
          '${relation.fromClassId}|${relation.toClassId}|${relation.type}';
      if (!drawn.add(key)) continue;

      final isInheritance = relation.type == 'inheritance';

      Color color;
      if (selected == null) {
        // Без выбранного класса рёбра скрыты, чтобы не засорять граф.
        continue;
      } else {
        // С выбранным классом показываем только его собственные связи:
        // входящие — голубые, исходящие — зелёные.
        final isIncoming = relation.toClassId == selected;
        final isOutgoing = relation.fromClassId == selected;
        if (!isIncoming && !isOutgoing) continue;

        color = isIncoming ? incomingRelationColor : outgoingRelationColor;
      }

      // В модели наследование хранится как ребёнок -> родитель.
      // Рисуем наоборот: от родителя к ребёнку.
      final startRect = isInheritance ? toRect : fromRect;
      final endRect = isInheritance ? fromRect : toRect;

      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;

      final start = _edgePoint(startRect, endRect.center);
      final end = _edgePoint(endRect, startRect.center);

      if (isInheritance) {
        canvas.drawLine(start, end, paint);
      } else {
        _drawDashedLine(canvas, start, end, paint);
      }

      _drawArrow(canvas, end, start, paint.color);
    }
  }

  Offset _edgePoint(Rect rect, Offset target) {
    final center = rect.center;
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;

    if (dx.abs() * rect.height > dy.abs() * rect.width) {
      return Offset(dx >= 0 ? rect.right : rect.left, center.dy);
    }
    return Offset(center.dx, dy >= 0 ? rect.bottom : rect.top);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return;

    final direction = delta / length;
    const dash = 5.0;
    const gap = 4.0;
    var offset = 0.0;

    while (offset < length) {
      final segmentEnd = math.min(offset + dash, length);
      canvas.drawLine(
        start + direction * offset,
        start + direction * segmentEnd,
        paint,
      );
      offset += dash + gap;
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset from, Color color) {
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    const arrowSize = 6.0;

    final left = Offset(
      tip.dx - arrowSize * math.cos(angle - math.pi / 6),
      tip.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    final right = Offset(
      tip.dx - arrowSize * math.cos(angle + math.pi / 6),
      tip.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_GraphEdgesPainter oldDelegate) => true;
}
