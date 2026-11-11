import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/project_bloc.dart';
import '../models/class_node.dart';
import '../widgets/graph_view_widget.dart';

class AnalysisPage extends StatefulWidget {
  final String projectPath;
  final String projectName;

  const AnalysisPage({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final double _leftPanelWidth = 275;
  final double _rightPanelWidth = 320;

  bool _isLeftPanelVisible = true;
  bool _isRightPanelVisible = true;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProjectBloc()..add(AnalyzeProject(widget.projectPath)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Анализ: ${widget.projectName}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Row(
          children: [
            // ================= ЛЕВАЯ ПАНЕЛЬ =================
            if (_isLeftPanelVisible)
              Container(
                width: _leftPanelWidth,
                color: const Color(0xFF252526),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                              left: 16.0,
                              top: 16.0,
                              bottom: 8.0,
                            ),
                            child: Text(
                              'Навигация',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          Expanded(
                            child: BlocBuilder<ProjectBloc, ProjectState>(
                              builder: (context, state) {
                                // Безопасно достаем статистику
                                int files = 0;
                                int classes = 0;
                                int relationsCount = 0;
                                int anomaliesCount = 0;
                                int health = 100;

                                if (state is ProjectLoaded) {
                                  files = state.filesCount;
                                  classes = state.nodes.length;
                                  relationsCount = state.relations.length;
                                  anomaliesCount = state.anomalyNodeIds.length;
                                  health = state.healthScore;
                                }

                                // Цвет здоровья
                                Color healthColor = Colors.green;
                                if (health < 80) healthColor = Colors.orange;
                                if (health < 50) healthColor = Colors.red;

                                return ListView(
                                  padding: const EdgeInsets.only(top: 8),
                                  children: [
                                    const ListTile(
                                      leading: Icon(
                                        Icons.hub,
                                        color: Colors.purpleAccent,
                                      ),
                                      title: Text(
                                        'Граф связей',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.link,
                                        color: Colors.white54,
                                      ),
                                      title: Text(
                                        'Связи ($relationsCount)',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.file_present,
                                        color: Colors.white54,
                                      ),
                                      title: Text(
                                        'Файлы ($files)',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.class_,
                                        color: Colors.white54,
                                      ),
                                      title: Text(
                                        'Классы ($classes)',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      leading: Icon(
                                        Icons.favorite,
                                        color: healthColor,
                                      ),
                                      title: Text.rich(
                                        TextSpan(
                                          text: 'Здоровье: ',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '$health/100',
                                              style: TextStyle(
                                                color: healthColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        overflow: TextOverflow.ellipsis, // На всякий случай, если экран будет совсем узким
                                      ),
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.warning,
                                        color: Colors.white54,
                                      ),
                                      title: Text(
                                        'Аномалии ($anomaliesCount)',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                      onTap: () {
                                        if (state is ProjectLoaded &&
                                            state.anomalyNodeIds.isNotEmpty) {
                                          _showAnomaliesDialog(context, state);
                                        } else if (state is ProjectLoaded) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Аномалий не найдено. Проект здоров!',
                                                  ),
                                                ),
                                              );
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PanelHandle(
                      isLeft: true,
                      isVisible: true,
                      onTap: () => setState(() => _isLeftPanelVisible = false),
                    ),
                  ],
                ),
              )
            else
              _PanelHandle(
                isLeft: true,
                isVisible: false,
                onTap: () => setState(() => _isLeftPanelVisible = true),
              ),

            // ================= ЦЕНТР (ГРАФ) =================
            Expanded(
              child: BlocBuilder<ProjectBloc, ProjectState>(
                builder: (context, state) {
                  if (state is ProjectLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ProjectLoaded) {
                    var displayNodes = state.nodes;

                    // Защита: если классов больше 300, принудительно скрываем "мертвые"
                    if (displayNodes.length > 300) {
                      final connectedIds = <String>{};
                      for (final rel in state.relations) {
                        connectedIds.add(rel.fromClassId);
                        connectedIds.add(rel.toClassId);
                      }
                      displayNodes = state.nodes
                          .where((n) => connectedIds.contains(n.id))
                          .toList();
                    }

                    // Если даже после фильтрации классов слишком много — предупреждаем
                    if (displayNodes.length > 300) {
                      return const Center(
                        child: Text(
                          'Слишком большой граф (более 300 связей).\nДля отображения выберите проект поменьше.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orange, fontSize: 18),
                        ),
                      );
                    }

                    if (displayNodes.isEmpty) {
                      return const Center(
                        child: Text(
                          'В проекте не найдено классов',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      );
                    }

                    return GraphViewWidget(
                      nodes: displayNodes,
                      relations: state.relations,
                      anomalyNodeIds: state.anomalyNodeIds,
                      selectedNodeId: state.selectedNode?.id,
                      onNodeTap: (node) {
                        context.read<ProjectBloc>().add(SelectNode(node));
                      },
                    );
                  }
                  if (state is ProjectError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ошибка: ${state.message}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

            // ================= ПРАВАЯ ПАНЕЛЬ =================
            if (_isRightPanelVisible)
              Container(
                width: _rightPanelWidth,
                color: const Color(0xFF252526),
                child: Row(
                  children: [
                    _PanelHandle(
                      isLeft: false,
                      isVisible: true,
                      onTap: () => setState(() => _isRightPanelVisible = false),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                              left: 16.0,
                              top: 16.0,
                              bottom: 8.0,
                            ),
                            child: Text(
                              'Информация',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          Expanded(
                            child: BlocBuilder<ProjectBloc, ProjectState>(
                              builder: (context, state) {
                                if (state is! ProjectLoaded)
                                  return const SizedBox();

                                final selectedNode = state.selectedNode;

                                if (selectedNode == null) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'Нажмите на класс на графе, чтобы увидеть детали.',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  );
                                }

                                return _buildNodeDetails(state, selectedNode);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              _PanelHandle(
                isLeft: false,
                isVisible: false,
                onTap: () => setState(() => _isRightPanelVisible = true),
              ),
          ],
        ),
      ),
    );
  }

  // Всплывающее окно со списком аномалий
  void _showAnomaliesDialog(BuildContext context, ProjectLoaded state) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF252526),
          title: const Text(
            'Аномалии (God Objects)',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: state.anomalyNodeIds.map((id) {
                final node = state.nodes.firstWhere((n) => n.id == id);
                final incoming = state.relations
                    .where((r) => r.toClassId == id)
                    .length;
                return ListTile(
                  leading: const Icon(Icons.warning, color: Colors.redAccent),
                  title: Text(
                    node.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Входящих зависимостей: $incoming',
                    style: const TextStyle(color: Colors.white54),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  // Карточка выбранного узла
  Widget _buildNodeDetails(ProjectLoaded state, ClassNode node) {
    final outgoing = state.relations
        .where((r) => r.fromClassId == node.id)
        .toList();
    final incoming = state.relations
        .where((r) => r.toClassId == node.id)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.code, size: 16, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              Text(
                node.language,
                style: const TextStyle(color: Colors.purpleAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Путь к файлу:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            node.filePath,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),

          if (state.anomalyNodeIds.contains(node.id)) ...[
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.redAccent),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.redAccent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Аномалия: слишком много зависимостей!',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Divider(color: Colors.white12, height: 32),

          Text(
            'Использует (${outgoing.length}):',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (outgoing.isEmpty)
            const Text('Нет', style: TextStyle(color: Colors.white54))
          else
            ...outgoing.map((r) {
              final target = state.nodes.firstWhere((n) => n.id == r.toClassId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '→ ${target.name}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }),

          const SizedBox(height: 24),

          Text(
            'Используют его (${incoming.length}):',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (incoming.isEmpty)
            const Text('Нет', style: TextStyle(color: Colors.white54))
          else
            ...incoming.map((r) {
              final source = state.nodes.firstWhere(
                (n) => n.id == r.fromClassId,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '← ${source.name}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PanelHandle extends StatefulWidget {
  final bool isLeft;
  final bool isVisible;
  final VoidCallback onTap;

  const _PanelHandle({
    required this.isLeft,
    required this.isVisible,
    required this.onTap,
  });

  @override
  State<_PanelHandle> createState() => _PanelHandleState();
}

class _PanelHandleState extends State<_PanelHandle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    IconData icon = widget.isLeft
        ? (widget.isVisible ? Icons.chevron_left : Icons.chevron_right)
        : (widget.isVisible ? Icons.chevron_right : Icons.chevron_left);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 16,
          color: _isHovered
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: _isHovered ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
