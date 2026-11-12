import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/project_bloc.dart';
import '../models/class_node.dart';
import '../models/class_relation.dart';
import '../services/export_service.dart';
import '../widgets/analysis_views.dart';
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

  final ExportService _exportService = ExportService();

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
          actions: [
            BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                final loaded = state is ProjectLoaded ? state : null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: loaded == null
                        ? null
                        : () => _exportReport(loaded),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Экспорт'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                    ),
                  ),
                );
              },
            ),
          ],
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
                                if (state is! ProjectLoaded) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                // Безопасно достаем статистику
                                final files = state.filesCount;
                                final classes = state.nodes.length;
                                final relationsCount = state.relations.length;
                                final anomaliesCount =
                                    state.anomalyNodeIds.length;
                                final health = state.healthScore;

                                // Цвет здоровья
                                Color healthColor = Colors.green;
                                if (health < 80) healthColor = Colors.orange;
                                if (health < 50) healthColor = Colors.red;

                                return ListView(
                                  padding: const EdgeInsets.only(top: 8),
                                  children: [
                                    _navTile(
                                      context: context,
                                      current: state.section,
                                      target: AnalysisSection.graph,
                                      icon: Icons.hub,
                                      title: 'Граф связей',
                                    ),
                                    _navTile(
                                      context: context,
                                      current: state.section,
                                      target: AnalysisSection.structure,
                                      icon: Icons.account_tree,
                                      title: 'Структура классов',
                                    ),
                                    _navTile(
                                      context: context,
                                      current: state.section,
                                      target: AnalysisSection.files,
                                      icon: Icons.file_present,
                                      title: 'Файлы ($files)',
                                    ),
                                    _navTile(
                                      context: context,
                                      current: state.section,
                                      target: AnalysisSection.health,
                                      icon: Icons.favorite,
                                      title: 'Здоровье: $health/100',
                                      iconColor: healthColor,
                                      titleColor: healthColor,
                                    ),
                                    _navTile(
                                      context: context,
                                      current: state.section,
                                      target: AnalysisSection.anomalies,
                                      icon: Icons.warning,
                                      title: 'Аномалии ($anomaliesCount)',
                                      iconColor: anomaliesCount > 0
                                          ? Colors.redAccent
                                          : Colors.white54,
                                    ),
                                    ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.link,
                                        color: Colors.white38,
                                        size: 20,
                                      ),
                                      title: Text(
                                        'Связи ($relationsCount)',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.class_,
                                        color: Colors.white38,
                                        size: 20,
                                      ),
                                      title: Text(
                                        'Классы ($classes)',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const Divider(
                                      color: Colors.white12,
                                      height: 24,
                                    ),
                                    SwitchListTile(
                                      value: state.hideIsolated,
                                      onChanged: (_) => context
                                          .read<ProjectBloc>()
                                          .add(ToggleHideIsolated()),
                                      title: const Text(
                                        'Скрывать изолированные',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${state.isolatedNodeIds.length} без связей',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                      secondary: const Icon(
                                        Icons.visibility_off,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
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
                    // Переключение центральной панели по выбранному разделу
                    switch (state.section) {
                      case AnalysisSection.structure:
                        return StructureView(state: state);
                      case AnalysisSection.files:
                        return FilesView(state: state);
                      case AnalysisSection.health:
                        return HealthView(state: state);
                      case AnalysisSection.anomalies:
                        return AnomaliesView(
                          state: state,
                          onNodeTap: (node) {
                            // Выбираем класс и возвращаемся к графу
                            context.read<ProjectBloc>()
                              ..add(SelectNode(node))
                              ..add(const SelectSection(AnalysisSection.graph));
                          },
                          onToggleIgnore: (node) {
                            context.read<ProjectBloc>().add(
                              ToggleAnomalyIgnored(node),
                            );
                          },
                        );
                      case AnalysisSection.graph:
                        break;
                    }

                    // Ограничение количества узлов выполняет сам граф:
                    // он показывает секции по типам и сообщает, сколько
                    // классов скрыто, вместо пустого экрана.

                    if (state.graphNodes.isEmpty) {
                      return Center(
                        child: Text(
                          state.hideIsolated
                              ? 'Все классы скрыты фильтром '
                                    '«Скрывать изолированные»'
                              : 'В проекте не найдено классов',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      );
                    }

                    return GraphViewWidget(
                      nodes: state.graphNodes,
                      relations: state.relations,
                      anomalyNodeIds: state.anomalyNodeIds,
                      ignoredAnomalyIds: state.ignoredAnomalyIds,
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
                                if (state is! ProjectLoaded) {
                                  return const SizedBox();
                                }

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

                                return _buildNodeDetails(
                                  context,
                                  state,
                                  selectedNode,
                                );
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

  // Экспорт отчёта в текстовый файл
  Future<void> _exportReport(ProjectLoaded state) async {
    try {
      final content = state.buildTextReport(widget.projectName);
      final path = await _exportService.saveTextReport(
        '${widget.projectName}_report.txt',
        content,
      );

      if (!mounted || path == null) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Отчёт сохранён: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось сохранить отчёт: $e')));
    }
  }

  // Пункт навигации в левой панели
  Widget _navTile({
    required BuildContext context,
    required AnalysisSection current,
    required AnalysisSection target,
    required IconData icon,
    required String title,
    Color iconColor = Colors.purpleAccent,
    Color? titleColor,
  }) {
    final isActive = current == target;

    return ListTile(
      dense: true,
      selected: isActive,
      selectedTileColor: Colors.white.withValues(alpha: 0.06),
      leading: Icon(
        icon,
        color: isActive ? iconColor : Colors.white54,
        size: 22,
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isActive ? (titleColor ?? Colors.white) : Colors.white54,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      onTap: () {
        context.read<ProjectBloc>().add(SelectSection(target));
      },
    );
  }

  // Небольшой цветной бейдж в карточке класса
  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11)),
    );
  }

  // Карточка выбранного узла
  Widget _buildNodeDetails(
    BuildContext context,
    ProjectLoaded state,
    ClassNode node,
  ) {
    final outgoing = state.relations
        .where((r) => r.fromClassId == node.id)
        .toList();
    final incoming = state.relations
        .where((r) => r.toClassId == node.id)
        .toList();

    final parent = state.parentOf(node.id);
    final children = state.childrenCount(node.id);
    final isIgnoredAnomaly =
        state.allAnomalyNodeIds.contains(node.id) &&
        state.ignoredAnomalyIds.contains(node.id);

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
          if (node.isAbstract || children > 0 || parent != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (node.isAbstract) _badge('abstract', Colors.orange),
                if (children > 0)
                  _badge('наследников: $children', Colors.purpleAccent),
                if (parent != null)
                  _badge('наследует: ${parent.name}', Colors.lightBlueAccent),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Путь к файлу:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            node.filePath,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
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

          if (isIgnoredAnomaly) ...[
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.withValues(alpha: 0.6)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Аномалия исключена пользователем: считается '
                      'допустимой и не влияет на оценку.',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Divider(color: Colors.white12, height: 32),

          // ================= ИИ-ПОМОЩНИК =================
          const Row(
            children: [
              Icon(Icons.smart_toy, color: Colors.purpleAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'ИИ-помощник',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.purpleAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              state.aiAdviceFor(node),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 32),

          Text(
            'Использует (${outgoing.length}):',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildRelationList(context, state, outgoing, outgoing: true),

          const SizedBox(height: 24),

          Text(
            'Используют его (${incoming.length}):',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildRelationList(context, state, incoming, outgoing: false),
        ],
      ),
    );
  }

  // Кликабельный список связей: клик выбирает класс на графе
  Widget _buildRelationList(
    BuildContext context,
    ProjectLoaded state,
    List<ClassRelation> relations, {
    required bool outgoing,
  }) {
    if (relations.isEmpty) {
      return const Text('Нет', style: TextStyle(color: Colors.white54));
    }

    final nodesById = {for (final n in state.nodes) n.id: n};

    return Column(
      children: relations.map((relation) {
        final target =
            nodesById[outgoing ? relation.toClassId : relation.fromClassId];
        if (target == null) return const SizedBox.shrink();

        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            // Выбираем класс и показываем его на графе
            context.read<ProjectBloc>()
              ..add(SelectNode(target))
              ..add(const SelectSection(AnalysisSection.graph));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: target.name,
                          style: const TextStyle(
                            color: Colors.purpleAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text: '  ${relation.type}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  outgoing ? Icons.arrow_forward : Icons.arrow_back,
                  size: 14,
                  color: outgoing
                      ? outgoingRelationColor
                      : incomingRelationColor,
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
