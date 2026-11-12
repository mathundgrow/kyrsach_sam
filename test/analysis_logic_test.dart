import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:code_graph/blocs/project_bloc.dart';
import 'package:code_graph/models/class_node.dart';
import 'package:code_graph/models/class_relation.dart';
import 'package:code_graph/models/recent_project.dart';
import 'package:code_graph/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const a = ClassNode(
    id: 'a',
    name: 'A',
    filePath: '/project/a.dart',
    language: 'Dart',
    isAbstract: true,
  );
  const b = ClassNode(
    id: 'b',
    name: 'B',
    filePath: '/project/a.dart',
    language: 'Dart',
  );
  const c = ClassNode(
    id: 'c',
    name: 'C',
    filePath: '/project/c.dart',
    language: 'Dart',
  );
  const d = ClassNode(
    id: 'd',
    name: 'D',
    filePath: '/project/c.dart',
    language: 'Dart',
  );

  const state = ProjectLoaded(
    nodes: [a, b, c, d],
    relations: [
      ClassRelation(fromClassId: 'b', toClassId: 'a', type: 'inheritance'),
      ClassRelation(fromClassId: 'd', toClassId: 'b', type: 'usage'),
    ],
    filesCount: 2,
    allAnomalyNodeIds: {'a'},
    anomalyNodeIds: {'a'},
    isolatedNodeIds: {'c'},
    healthScore: 88,
  );

  test('группировка классов по файлам', () {
    final grouped = state.classesByFile;
    expect(grouped['/project/a.dart']!.length, 2);
    expect(grouped['/project/c.dart']!.length, 2);
  });

  test('поиск по файлам не меняет исходную группировку', () {
    expect(state.filteredClassesByFile.length, 2);

    final filtered = state.copyWith(filesQuery: 'c.dart');
    expect(filtered.filteredClassesByFile.keys, ['/project/c.dart']);
    expect(filtered.classesByFile.length, 2);

    final empty = state.copyWith(filesQuery: 'no-such-file');
    expect(empty.filteredClassesByFile, isEmpty);

    // Поиск идёт только по имени файла, а не по пути.
    final byPath = state.copyWith(filesQuery: 'project');
    expect(byPath.filteredClassesByFile, isEmpty);
  });

  test('фильтр изолированных классов', () {
    expect(state.graphNodes.length, 4);

    final filtered = state.copyWith(hideIsolated: true);
    expect(filtered.graphNodes.length, 3);
    expect(filtered.graphNodes.any((n) => n.id == 'c'), isFalse);
  });

  test('штрафы и смена раздела', () {
    expect(state.anomalyPenalty, 5);
    expect(state.isolatedPenalty, 5);

    final filesState = state.copyWith(section: AnalysisSection.files);
    expect(filesState.section, AnalysisSection.files);
  });

  test('дерево наследования и абстрактные классы', () {
    expect(state.abstractClasses.length, 1);
    expect(state.parentOf('b')!.id, 'a');
    expect(state.childrenCount('a'), 1);

    final groups = state.hierarchyGroups;
    expect(groups.length, 1);
    expect(groups.first.root.id, 'a');
    expect(groups.first.descendantsCount, 1);
    expect(groups.first.items.map((i) => i.node.id), ['a', 'b']);

    final standalone = state.standaloneClasses.map((n) => n.id).toList();
    expect(standalone, containsAll(['c', 'd']));
  });

  test('советы ИИ-помощника', () {
    expect(state.aiAdviceFor(a), startsWith('⚠️'));
    expect(state.aiAdviceFor(c), startsWith('💤'));
    expect(state.aiAdviceFor(b), startsWith('🧬'));
    expect(state.aiAdviceFor(d), startsWith('✅'));
  });

  test('исключённые аномалии не штрафуются', () {
    final ignored = state.copyWith(
      ignoredAnomalyIds: {'a'},
      anomalyNodeIds: const {},
      healthScore: 98,
    );

    expect(ignored.ignoredAnomalyNodes.length, 1);
    expect(ignored.ignoredAnomalyNodes.first.id, 'a');
    expect(ignored.anomalyNodes, isEmpty);
    expect(ignored.anomalyPenalty, 0);
  });

  test('текстовый отчёт содержит ключевые данные', () {
    final report = state.buildTextReport('TestProject');
    expect(report, contains('Проект: TestProject'));
    expect(report, contains('Классов: 4'));
    expect(report, contains('Связей: 2'));
    expect(report, contains('Оценка здоровья: 88/100'));
    expect(report, contains('A (Dart)'));
    expect(report, contains('ИСКЛЮЧЁННЫЕ АНОМАЛИИ'));
  });

  test('история хранит только путь и не дублирует проекты', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();

    await storage.addRecentProject(const RecentProject(path: '/p/one'));
    await storage.addRecentProject(const RecentProject(path: '/p/two'));
    await storage.addRecentProject(const RecentProject(path: '/p/one'));

    final projects = await storage.getRecentProjects();
    expect(projects.length, 2);
    expect(projects.first.path, '/p/one');
    expect(projects.first.name, 'one');
  });

  test('исключённые аномалии сохраняются отдельно для проекта', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();

    await storage.saveIgnoredAnomalies('/project/one', {'a', 'b'});
    expect(await storage.getIgnoredAnomalies('/project/one'), {'a', 'b'});
    expect(await storage.getIgnoredAnomalies('/project/two'), isEmpty);

    await storage.saveIgnoredAnomalies('/project/one', {'b'});
    expect(await storage.getIgnoredAnomalies('/project/one'), {'b'});
  });
}
