import 'dart:isolate';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../models/class_node.dart';
import '../models/class_relation.dart';
import '../services/project_scanner.dart';
import '../services/storage_service.dart';

// --- РАЗДЕЛЫ ЦЕНТРАЛЬНОЙ ПАНЕЛИ ---
enum AnalysisSection { graph, structure, files, health, anomalies }

// --- ВСПОМОГАТЕЛЬНЫЕ МОДЕЛИ ДЛЯ ДЕРЕВА НАСЛЕДОВАНИЯ ---
class HierarchyItem {
  final ClassNode node;
  final int depth;

  const HierarchyItem({required this.node, required this.depth});
}

class HierarchyGroup {
  final ClassNode root;
  final List<HierarchyItem> items;

  const HierarchyGroup({required this.root, required this.items});

  int get descendantsCount => items.length - 1;
}

// Сортировка: сначала абстрактные, потом по имени
int _compareNodes(ClassNode a, ClassNode b) {
  if (a.isAbstract != b.isAbstract) return a.isAbstract ? -1 : 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

// Сканирование запускается из отдельной функции, чтобы замыкание
// не захватывало BLoC и его внутренние объекты (их нельзя передать в изолят).
Future<(List<ClassNode>, List<ClassRelation>, int)> _scanInIsolate(
  String path,
) {
  return Isolate.run(() => ProjectScanner().scanProject(path));
}

// --- СОБЫТИЯ (Events) ---
abstract class ProjectEvent extends Equatable {
  const ProjectEvent();
  @override
  List<Object?> get props => [];
}

class AnalyzeProject extends ProjectEvent {
  final String path;
  const AnalyzeProject(this.path);
  @override
  List<Object?> get props => [path];
}

class SelectNode extends ProjectEvent {
  final ClassNode? node;
  const SelectNode(this.node);
  @override
  List<Object?> get props => [node];
}

// Переключение раздела в левой панели
class SelectSection extends ProjectEvent {
  final AnalysisSection section;
  const SelectSection(this.section);
  @override
  List<Object?> get props => [section];
}

// Переключатель "Скрывать изолированные классы"
class ToggleHideIsolated extends ProjectEvent {}

// Поиск по файлам на вкладке "Файлы"
class SearchFiles extends ProjectEvent {
  final String query;
  const SearchFiles(this.query);
  @override
  List<Object?> get props => [query];
}

// Пометить аномалию как допустимую / вернуть обратно
class ToggleAnomalyIgnored extends ProjectEvent {
  final ClassNode node;
  const ToggleAnomalyIgnored(this.node);
  @override
  List<Object?> get props => [node];
}

// --- СОСТОЯНИЯ (States) ---
abstract class ProjectState extends Equatable {
  const ProjectState();
  @override
  List<Object?> get props => [];
}

class ProjectInitial extends ProjectState {}

class ProjectLoading extends ProjectState {}

class ProjectError extends ProjectState {
  final String message;
  const ProjectError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProjectLoaded extends ProjectState {
  final List<ClassNode> nodes;
  final List<ClassRelation> relations;
  final int filesCount;
  final ClassNode? selectedNode;

  // Все найденные аномалии (до исключения пользователем)
  final Set<String> allAnomalyNodeIds;

  // Аномалии, которые пользователь признал допустимыми
  final Set<String> ignoredAnomalyIds;

  // Активные аномалии (все минус исключённые)
  final Set<String> anomalyNodeIds;

  final Set<String> isolatedNodeIds;
  final int healthScore;

  // Состояние навигации и фильтрации
  final AnalysisSection section;
  final bool hideIsolated;
  final String filesQuery;

  const ProjectLoaded({
    required this.nodes,
    required this.relations,
    required this.filesCount,
    this.selectedNode,
    this.allAnomalyNodeIds = const {},
    this.ignoredAnomalyIds = const {},
    this.anomalyNodeIds = const {},
    this.isolatedNodeIds = const {},
    this.healthScore = 100,
    this.section = AnalysisSection.graph,
    this.hideIsolated = false,
    this.filesQuery = '',
  });

  // Удобное копирование состояния без ручного перечисления всех полей
  ProjectLoaded copyWith({
    List<ClassNode>? nodes,
    List<ClassRelation>? relations,
    int? filesCount,
    ClassNode? selectedNode,
    bool resetSelectedNode = false,
    Set<String>? allAnomalyNodeIds,
    Set<String>? ignoredAnomalyIds,
    Set<String>? anomalyNodeIds,
    Set<String>? isolatedNodeIds,
    int? healthScore,
    AnalysisSection? section,
    bool? hideIsolated,
    String? filesQuery,
  }) {
    return ProjectLoaded(
      nodes: nodes ?? this.nodes,
      relations: relations ?? this.relations,
      filesCount: filesCount ?? this.filesCount,
      selectedNode: resetSelectedNode
          ? null
          : (selectedNode ?? this.selectedNode),
      allAnomalyNodeIds: allAnomalyNodeIds ?? this.allAnomalyNodeIds,
      ignoredAnomalyIds: ignoredAnomalyIds ?? this.ignoredAnomalyIds,
      anomalyNodeIds: anomalyNodeIds ?? this.anomalyNodeIds,
      isolatedNodeIds: isolatedNodeIds ?? this.isolatedNodeIds,
      healthScore: healthScore ?? this.healthScore,
      section: section ?? this.section,
      hideIsolated: hideIsolated ?? this.hideIsolated,
      filesQuery: filesQuery ?? this.filesQuery,
    );
  }

  // --- ГОТОВЫЕ ДАННЫЕ ДЛЯ UI (вся логика здесь, в BLoC) ---

  // Классы, сгруппированные по файлам
  Map<String, List<ClassNode>> get classesByFile {
    final grouped = <String, List<ClassNode>>{};
    for (final node in nodes) {
      grouped.putIfAbsent(node.filePath, () => <ClassNode>[]).add(node);
    }
    return grouped;
  }

  // То же, но с учётом поиска только по имени файла на вкладке "Файлы"
  Map<String, List<ClassNode>> get filteredClassesByFile {
    final query = filesQuery.trim().toLowerCase();
    if (query.isEmpty) return classesByFile;
    return {
      for (final entry in classesByFile.entries)
        if (p.basename(entry.key).toLowerCase().contains(query))
          entry.key: entry.value,
    };
  }

  // Активные аномалии (God Objects)
  List<ClassNode> get anomalyNodes {
    return nodes.where((n) => anomalyNodeIds.contains(n.id)).toList();
  }

  // Аномалии, исключённые пользователем (показываются отдельным списком)
  List<ClassNode> get ignoredAnomalyNodes {
    return nodes
        .where(
          (n) =>
              ignoredAnomalyIds.contains(n.id) &&
              allAnomalyNodeIds.contains(n.id),
        )
        .toList();
  }

  // Все классы-абстракции
  List<ClassNode> get abstractClasses {
    return nodes.where((n) => n.isAbstract).toList();
  }

  // Классы, у которых нет ни одной связи
  List<ClassNode> get isolatedNodes {
    return nodes.where((n) => isolatedNodeIds.contains(n.id)).toList();
  }

  // Сколько разных классов используют этот класс (usage-связи)
  int incomingCount(String nodeId) {
    final sources = <String>{};
    for (final r in relations) {
      if (r.type == 'usage' &&
          r.toClassId == nodeId &&
          r.fromClassId != nodeId) {
        sources.add(r.fromClassId);
      }
    }
    return sources.length;
  }

  // Штрафы для отчёта по здоровью.
  // Аномалии штрафуются умеренно (5 баллов, не больше 35),
  // изолированные — пропорционально их доле (не больше 20).
  static const int maxAnomalyPenalty = 35;
  static const int maxIsolatedPenalty = 20;

  // God Object: класс используют больше 5 разных классов (6+).
  static const int maxIncomingUsage = 5;

  int get anomalyPenalty =>
      math.min(anomalyNodeIds.length * 5, maxAnomalyPenalty);

  int get isolatedPenalty {
    if (nodes.isEmpty) return 0;
    final share = isolatedNodeIds.length / nodes.length;
    return (share * maxIsolatedPenalty).round();
  }

  // --- ИЕРАРХИЯ НАСЛЕДОВАНИЯ ---

  // Ребёнок -> первый родитель (для раскладки и дерева)
  Map<String, String> get inheritanceParentIds {
    final parentByChild = <String, String>{};
    for (final rel in relations) {
      if (rel.type == 'inheritance') {
        parentByChild.putIfAbsent(rel.fromClassId, () => rel.toClassId);
      }
    }
    return parentByChild;
  }

  // Родитель -> список детей
  Map<String, List<ClassNode>> get inheritanceChildren {
    final byId = {for (final n in nodes) n.id: n};
    final grouped = <String, List<ClassNode>>{};

    for (final rel in relations) {
      if (rel.type != 'inheritance') continue;
      final child = byId[rel.fromClassId];
      if (child == null || !byId.containsKey(rel.toClassId)) continue;

      final list = grouped.putIfAbsent(rel.toClassId, () => <ClassNode>[]);
      if (!list.any((n) => n.id == child.id)) list.add(child);
    }
    return grouped;
  }

  ClassNode? parentOf(String nodeId) {
    final parentId = inheritanceParentIds[nodeId];
    if (parentId == null) return null;
    for (final node in nodes) {
      if (node.id == parentId) return node;
    }
    return null;
  }

  int childrenCount(String nodeId) {
    return inheritanceChildren[nodeId]?.length ?? 0;
  }

  // Деревья наследования: базовый класс -> все потомки
  List<HierarchyGroup> get hierarchyGroups {
    final byId = {for (final n in nodes) n.id: n};
    final children = inheritanceChildren;
    final parents = inheritanceParentIds;
    final visited = <String>{};
    final groups = <HierarchyGroup>[];

    void walk(ClassNode node, int depth, List<HierarchyItem> items) {
      if (visited.contains(node.id)) return;
      visited.add(node.id);
      items.add(HierarchyItem(node: node, depth: depth));

      for (final child in children[node.id] ?? const <ClassNode>[]) {
        walk(child, depth + 1, items);
      }
    }

    // Корни: есть дети, но нет известного родителя
    final roots = nodes.where((n) {
      final hasChildren = (children[n.id] ?? const <ClassNode>[]).isNotEmpty;
      final parentId = parents[n.id];
      return hasChildren && (parentId == null || !byId.containsKey(parentId));
    }).toList()..sort(_compareNodes);

    for (final root in roots) {
      final items = <HierarchyItem>[];
      walk(root, 0, items);
      if (items.length > 1) {
        groups.add(HierarchyGroup(root: root, items: items));
      }
    }

    // Страховка от циклов: группы, которые не дошли от корней
    for (final node in nodes) {
      if (visited.contains(node.id)) continue;
      if ((children[node.id] ?? const <ClassNode>[]).isEmpty) continue;

      final items = <HierarchyItem>[];
      walk(node, 0, items);
      if (items.length > 1) {
        groups.add(HierarchyGroup(root: node, items: items));
      }
    }

    groups.sort((a, b) => _compareNodes(a.root, b.root));
    return groups;
  }

  // Классы, не попавшие ни в одно дерево наследования
  List<ClassNode> get standaloneClasses {
    final covered = <String>{};
    for (final group in hierarchyGroups) {
      for (final item in group.items) {
        covered.add(item.node.id);
      }
    }

    return nodes.where((n) => !covered.contains(n.id)).toList()
      ..sort(_compareNodes);
  }

  // Узлы для графа с учётом фильтра изолированных классов.
  // Ограничение количества отрисовываемых узлов выполняет сам граф,
  // чтобы не терять данные и не показывать пустую область.
  List<ClassNode> get graphNodes {
    if (hideIsolated) {
      return nodes.where((n) => !isolatedNodeIds.contains(n.id)).toList();
    }
    return nodes;
  }

  // Простая локальная экспертная система (ИИ-помощник)
  String aiAdviceFor(ClassNode node) {
    if (anomalyNodeIds.contains(node.id)) {
      return '⚠️ Этот класс слишком сильно связан с другими. '
          'Рекомендуется применить паттерн Фасад или разделить его '
          'на несколько классов.';
    }
    if (isolatedNodeIds.contains(node.id)) {
      return '💤 Этот класс не имеет связей. Возможно, это мертвый код '
          'или точка входа.';
    }
    final isChild = relations.any(
      (r) => r.fromClassId == node.id && r.type == 'inheritance',
    );
    if (isChild) {
      return '🧬 Этот класс расширяет другой класс. Убедитесь, что '
          'не нарушается принцип подстановки Барбары Лисков.';
    }
    return '✅ Класс выглядит архитектурно чистым. '
        'Количество связей в норме.';
  }

  // Текстовый отчёт для экспорта
  String buildTextReport(String projectName) {
    const line = '==================================================';
    final buffer = StringBuffer();

    buffer.writeln('ОТЧЁТ АРХИТЕКТУРНОГО АНАЛИЗА');
    buffer.writeln(line);
    buffer.writeln('Проект: $projectName');
    buffer.writeln(
      'Дата: ${DateTime.now().toLocal().toString().split('.').first}',
    );
    buffer.writeln();

    buffer.writeln('ОБЩАЯ СТАТИСТИКА');
    buffer.writeln(line);
    buffer.writeln('Классов: ${nodes.length}');
    buffer.writeln('Связей: ${relations.length}');
    buffer.writeln('Файлов: $filesCount');
    buffer.writeln('Абстрактных классов: ${abstractClasses.length}');
    buffer.writeln('Оценка здоровья: $healthScore/100');
    buffer.writeln();

    buffer.writeln('РАСЧЁТ ЗДОРОВЬЯ');
    buffer.writeln(line);
    buffer.writeln('База: 100');
    buffer.writeln(
      'Штраф за аномалии (${anomalyNodeIds.length} × 5, макс. '
      '$maxAnomalyPenalty): -$anomalyPenalty',
    );
    buffer.writeln(
      'Штраф за изолированные (${isolatedNodeIds.length} из ${nodes.length}, '
      'макс. $maxIsolatedPenalty): -$isolatedPenalty',
    );
    buffer.writeln('Итог: $healthScore');
    buffer.writeln();

    buffer.writeln('АНОМАЛИИ (God Objects): ${anomalyNodeIds.length}');
    buffer.writeln(line);
    if (anomalyNodes.isEmpty) {
      buffer.writeln('Не обнаружены.');
    } else {
      for (final node in anomalyNodes) {
        buffer.writeln(
          ' - ${node.name} (${node.language}) — входящих связей: '
          '${incomingCount(node.id)}',
        );
        buffer.writeln('   Файл: ${node.filePath}');
      }
    }
    buffer.writeln();

    buffer.writeln(
      'ИСКЛЮЧЁННЫЕ АНОМАЛИИ (решение пользователя): '
      '${ignoredAnomalyNodes.length}',
    );
    buffer.writeln(line);
    if (ignoredAnomalyNodes.isEmpty) {
      buffer.writeln('Нет.');
    } else {
      for (final node in ignoredAnomalyNodes) {
        buffer.writeln(' - ${node.name} (${node.language})');
        buffer.writeln('   Файл: ${node.filePath}');
      }
    }
    buffer.writeln();

    buffer.writeln('ИЗОЛИРОВАННЫЕ КЛАССЫ: ${isolatedNodes.length}');
    buffer.writeln(line);
    if (isolatedNodes.isEmpty) {
      buffer.writeln('Не обнаружены.');
    } else {
      for (final node in isolatedNodes) {
        buffer.writeln(' - ${node.name} (${node.language})');
        buffer.writeln('   Файл: ${node.filePath}');
      }
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    nodes,
    relations,
    filesCount,
    selectedNode,
    allAnomalyNodeIds,
    ignoredAnomalyIds,
    anomalyNodeIds,
    isolatedNodeIds,
    healthScore,
    section,
    hideIsolated,
    filesQuery,
  ];
}

// --- САМ BLOC (Мозг) ---
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final StorageService _storage;
  String? _projectPath;

  ProjectBloc({StorageService? storage})
    : _storage = storage ?? StorageService(),
      super(ProjectInitial()) {
    on<AnalyzeProject>((event, emit) async {
      emit(ProjectLoading());
      _projectPath = event.path;

      try {
        // Загружаем исключённые аномалии (свои для каждого проекта)
        final ignored = await _storage.getIgnoredAnomalies(event.path);

        // 1. Сканируем проект в отдельном изоляте, чтобы не вешать UI.
        final (nodes, relations, filesCount) = await _scanInIsolate(event.path);

        // 2. ИЩЕМ ВСЕ АНОМАЛИИ.
        //    God Object — класс, который используют больше 5 РАЗНЫХ классов
        //    (6+). Повторные связи одного класса считаются один раз.
        //    Наследование НЕ считается: абстрактные базовые классы и интерфейсы
        //    не должны автоматически становиться аномалиями.
        final usageSources = <String, Set<String>>{};
        for (final rel in relations) {
          if (rel.type != 'usage') continue;
          if (rel.fromClassId == rel.toClassId) continue;
          usageSources
              .putIfAbsent(rel.toClassId, () => <String>{})
              .add(rel.fromClassId);
        }
        final allAnomalies = <String>{};
        usageSources.forEach((id, sources) {
          if (sources.length > ProjectLoaded.maxIncomingUsage) {
            allAnomalies.add(id);
          }
        });

        // 3. ИЩЕМ ИЗОЛИРОВАННЫЕ КЛАССЫ
        final connectedNodes = <String>{};
        for (final rel in relations) {
          connectedNodes.add(rel.fromClassId);
          connectedNodes.add(rel.toClassId);
        }

        final isolated = <String>{};
        for (final node in nodes) {
          if (!connectedNodes.contains(node.id)) isolated.add(node.id);
        }

        // 4. АКТИВНЫЕ АНОМАЛИИ = все минус исключённые пользователем
        final activeAnomalies = allAnomalies.difference(ignored);

        // 5. СЧИТАЕМ ЗДОРОВЬЕ
        final score = _calculateHealth(
          activeAnomalies.length,
          isolated.length,
          nodes.length,
        );

        // 6. Отправляем данные в UI
        if (isClosed) return;
        emit(
          ProjectLoaded(
            nodes: nodes,
            relations: relations,
            filesCount: filesCount,
            allAnomalyNodeIds: allAnomalies,
            ignoredAnomalyIds: ignored,
            anomalyNodeIds: activeAnomalies,
            isolatedNodeIds: isolated,
            healthScore: score,
          ),
        );
      } catch (e) {
        if (isClosed) return;
        emit(ProjectError(e.toString()));
      }
    });

    on<SelectNode>((event, emit) {
      if (state is ProjectLoaded) {
        final currentState = state as ProjectLoaded;
        if (event.node == null) {
          emit(currentState.copyWith(resetSelectedNode: true));
        } else {
          emit(currentState.copyWith(selectedNode: event.node));
        }
      }
    });

    on<SelectSection>((event, emit) {
      if (state is ProjectLoaded) {
        final currentState = state as ProjectLoaded;
        emit(currentState.copyWith(section: event.section));
      }
    });

    on<ToggleHideIsolated>((event, emit) {
      if (state is ProjectLoaded) {
        final currentState = state as ProjectLoaded;
        emit(currentState.copyWith(hideIsolated: !currentState.hideIsolated));
      }
    });

    on<SearchFiles>((event, emit) {
      if (state is ProjectLoaded) {
        final currentState = state as ProjectLoaded;
        emit(currentState.copyWith(filesQuery: event.query));
      }
    });

    on<ToggleAnomalyIgnored>((event, emit) async {
      if (state is! ProjectLoaded || _projectPath == null) return;
      final current = state as ProjectLoaded;

      final ignored = Set<String>.from(current.ignoredAnomalyIds);
      if (ignored.contains(event.node.id)) {
        ignored.remove(event.node.id);
      } else {
        ignored.add(event.node.id);
      }

      // Сохраняем решение пользователя для этого проекта
      await _storage.saveIgnoredAnomalies(_projectPath!, ignored);

      if (isClosed) return;
      emit(_withAnomalies(current, ignored));
    });
  }

  static int _calculateHealth(
    int anomaliesCount,
    int isolatedCount,
    int totalCount,
  ) {
    final anomalyPenalty = math
        .min(anomaliesCount * 5, ProjectLoaded.maxAnomalyPenalty)
        .toInt();
    var score = 100 - anomalyPenalty;
    if (totalCount > 0) {
      score -= (isolatedCount / totalCount * ProjectLoaded.maxIsolatedPenalty)
          .round();
    }
    return score < 0 ? 0 : score;
  }

  ProjectLoaded _withAnomalies(ProjectLoaded current, Set<String> ignored) {
    final active = current.allAnomalyNodeIds.difference(ignored);
    return current.copyWith(
      ignoredAnomalyIds: ignored,
      anomalyNodeIds: active,
      healthScore: _calculateHealth(
        active.length,
        current.isolatedNodeIds.length,
        current.nodes.length,
      ),
    );
  }
}
