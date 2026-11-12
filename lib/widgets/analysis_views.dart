import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../blocs/project_bloc.dart';
import '../models/class_node.dart';
import '../services/editor_service.dart';

// Открывает файл класса в VS Code. Если редактор не найден,
// показываем подсказку пользователю.
Future<void> _openClassInVSCode(BuildContext context, ClassNode node) async {
  final opened = await EditorService().openClassInVSCode(node);
  if (!context.mounted || opened) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Не удалось открыть VS Code. Проверьте, что он установлен '
        'и доступна команда code.',
      ),
    ),
  );
}

// ==================== ВКЛАДКА "ФАЙЛЫ" ====================
class FilesView extends StatefulWidget {
  final ProjectLoaded state;

  const FilesView({super.key, required this.state});

  @override
  State<FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends State<FilesView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.filesQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    context.read<ProjectBloc>().add(SearchFiles(value));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final allFiles = state.classesByFile;
    final files = state.filteredClassesByFile.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final hasQuery = state.filesQuery.trim().isNotEmpty;

    if (allFiles.isEmpty) {
      return const _EmptyView(
        icon: Icons.folder_off,
        text: 'Файлы с классами не найдены',
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ViewHeader(
            icon: Icons.folder,
            title: 'Файлы проекта (${allFiles.length})',
            subtitle: 'Классы сгруппированы по исходным файлам',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _search,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Поиск по имени файла',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Colors.white54,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Очистить',
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF252526),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.purpleAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (files.isEmpty)
            _InfoBox(
              text: 'Ничего не найдено по запросу «${state.filesQuery}».',
            )
          else
            ...files.map(
              (entry) =>
                  _FileTile(path: entry.key, classesCount: entry.value.length),
            ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final String path;
  final int classesCount;

  const _FileTile({required this.path, required this.classesCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: const Icon(Icons.description, color: Colors.white54),
        title: Text(
          p.basename(path),
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$classesCount кл.',
            style: const TextStyle(color: Colors.purpleAccent, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ==================== ВКЛАДКА "СТРУКТУРА" ====================
class StructureView extends StatelessWidget {
  final ProjectLoaded state;

  const StructureView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final groups = state.hierarchyGroups;
    final standalone = state.standaloneClasses;

    if (groups.isEmpty && standalone.isEmpty) {
      return const _EmptyView(
        icon: Icons.account_tree,
        text: 'Классы не найдены',
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _ViewHeader(
            icon: Icons.account_tree,
            title: 'Структура классов',
            subtitle:
                'Дерево наследования: базовые классы и их реализации. '
                'Нажмите на класс или значок ↗, чтобы открыть его в VS Code.',
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            const _InfoBox(
              text:
                  'Наследование между классами не найдено. '
                  'Все классы показаны ниже.',
            )
          else
            ...groups.map((group) => _HierarchyCard(group: group)),
          if (standalone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Без наследования (${standalone.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: standalone
                  .map((node) => _ClassChip(node: node))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HierarchyCard extends StatelessWidget {
  final HierarchyGroup group;

  const _HierarchyCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () => _openClassInVSCode(context, group.root),
            leading: Icon(
              group.root.isAbstract ? Icons.account_tree : Icons.folder_open,
              color: group.root.isAbstract
                  ? Colors.orange
                  : Colors.purpleAccent,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    group.root.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (group.root.isAbstract) ...[
                  const SizedBox(width: 8),
                  const _TypeBadge(text: 'abstract', color: Colors.orange),
                ],
              ],
            ),
            subtitle: Text(
              'Потомков: ${group.descendantsCount} · ${group.root.language} '
              '· строка ${group.root.line}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.open_in_new,
                size: 16,
                color: Colors.white38,
              ),
              onPressed: () => _openClassInVSCode(context, group.root),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...group.items.skip(1).map((item) {
            final node = item.node;
            return InkWell(
              onTap: () => _openClassInVSCode(context, node),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0 + item.depth * 18,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        node.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (node.isAbstract) ...[
                      const SizedBox(width: 6),
                      const _TypeBadge(text: 'abstract', color: Colors.orange),
                    ],
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.open_in_new,
                      size: 13,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final ClassNode node;

  const _ClassChip({required this.node});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openClassInVSCode(context, node),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                node.isAbstract ? Icons.account_tree : Icons.class_,
                size: 12,
                color: node.isAbstract ? Colors.orange : Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                node.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new, size: 11, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TypeBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}

// ==================== ВКЛАДКА "ЗДОРОВЬЕ" ====================
class HealthView extends StatelessWidget {
  final ProjectLoaded state;

  const HealthView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final score = state.healthScore;
    final color = _scoreColor(score);

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _ViewHeader(
            icon: Icons.favorite,
            title: 'Здоровье проекта',
            subtitle: 'Детальный отчёт по архитектурным показателям',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  '$score / 100',
                  style: TextStyle(
                    color: color,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _healthLabel(score),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _PenaltyRow(
                  label: 'База',
                  value: '+100',
                  valueColor: Colors.green,
                ),
                _PenaltyRow(
                  label:
                      'Аномалии (${state.anomalyNodeIds.length} × 5, '
                      'макс. ${ProjectLoaded.maxAnomalyPenalty})',
                  value: '-${state.anomalyPenalty}',
                  valueColor: Colors.redAccent,
                ),
                _PenaltyRow(
                  label:
                      'Изолированные (${state.isolatedNodeIds.length} из '
                      '${state.nodes.length}, '
                      'макс. ${ProjectLoaded.maxIsolatedPenalty})',
                  value: '-${state.isolatedPenalty}',
                  valueColor: Colors.orange,
                ),
                _PenaltyRow(
                  label:
                      'Исключённые аномалии '
                      '(${state.ignoredAnomalyNodes.length})',
                  value: 'не влияют',
                  valueColor: Colors.green,
                ),
                const Divider(color: Colors.white12, height: 24),
                _PenaltyRow(
                  label: 'Итог',
                  value: '$score',
                  valueColor: color,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Формула: 100 − (аномалии × 5, максимум 35) − '
            '(доля изолированных классов × 20).\n'
            'Изолированные классы почти не влияют на большой проект: '
            'важна их доля, а не количество.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Аномалии, отмеченные пользователем как допустимые, '
            'не уменьшают оценку. Оценка не может быть ниже 0.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PenaltyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _PenaltyRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: bold ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ВКЛАДКА "АНОМАЛИИ" ====================
class AnomaliesView extends StatelessWidget {
  final ProjectLoaded state;
  final Function(ClassNode) onNodeTap;
  final Function(ClassNode) onToggleIgnore;

  const AnomaliesView({
    super.key,
    required this.state,
    required this.onNodeTap,
    required this.onToggleIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final active = state.anomalyNodes;
    final ignored = state.ignoredAnomalyNodes;

    if (state.allAnomalyNodeIds.isEmpty) {
      return const _EmptyView(
        icon: Icons.check_circle_outline,
        text: 'Аномалий не найдено.\nПроект архитектурно здоров!',
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ViewHeader(
            icon: Icons.warning_amber,
            title: 'Аномалии (${active.length})',
            subtitle:
                'God Object — класс, который используют более 5 разных '
                'классов (6 и больше, наследование не считается). Если так '
                'задумано, отметьте его как «Не аномалия» — выбор '
                'сохранится для этого проекта.',
            iconColor: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          if (active.isEmpty)
            const _InfoBox(
              text:
                  'Активных аномалий нет: все найденные классы '
                  'отмечены как допустимые.',
            )
          else
            ...active.map(
              (node) => _AnomalyTile(
                node: node,
                incoming: state.incomingCount(node.id),
                ignored: false,
                onTap: () => onNodeTap(node),
                onToggle: () => onToggleIgnore(node),
              ),
            ),
          if (ignored.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Исключённые из анализа (${ignored.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...ignored.map(
              (node) => _AnomalyTile(
                node: node,
                incoming: state.incomingCount(node.id),
                ignored: true,
                onTap: () => onNodeTap(node),
                onToggle: () => onToggleIgnore(node),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  final ClassNode node;
  final int incoming;
  final bool ignored;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _AnomalyTile({
    required this.node,
    required this.incoming,
    required this.ignored,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ignored
              ? Colors.white12
              : Colors.redAccent.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          ignored ? Icons.check_circle : Icons.warning,
          color: ignored ? Colors.green : Colors.redAccent,
        ),
        title: Text(
          node.name,
          style: TextStyle(
            color: ignored ? Colors.white54 : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Входящих зависимостей: $incoming · ${node.language}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: onToggle,
          style: TextButton.styleFrom(
            foregroundColor: ignored ? Colors.green : Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            ignored ? 'Вернуть' : 'Не аномалия',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ==================== ОБЩИЕ ЭЛЕМЕНТЫ ====================
class _ViewHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const _ViewHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = Colors.purpleAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyView({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 80) return Colors.green;
  if (score >= 50) return Colors.orange;
  return Colors.red;
}

String _healthLabel(int score) {
  if (score >= 80) return 'Хорошее состояние';
  if (score >= 50) return 'Есть проблемы';
  return 'Критическое состояние';
}
