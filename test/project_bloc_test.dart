import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:code_graph/blocs/project_bloc.dart';
import 'package:code_graph/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('аномалию можно исключить, выбор сохраняется для проекта', () async {
    SharedPreferences.setMockInitialValues({});

    final tempDir = await Directory.systemTemp.createTemp('code_graph_test_');
    addTearDown(() => tempDir.delete(recursive: true));

    await File('${tempDir.path}/models.py').writeAsString('''
class Base:
    pass

class A:
    base: Base

class B:
    base: Base

class C:
    base: Base

class D:
    base: Base

class E:
    base: Base

class F:
    base: Base

class Almost:
    pass

class G:
    almost: Almost

class H:
    almost: Almost

class I:
    almost: Almost

class J:
    almost: Almost

class K:
    almost: Almost

class Parent:
    pass

class ChildA(Parent):
    pass

class ChildB(Parent):
    pass

class ChildC(Parent):
    pass
''');

    final storage = StorageService();
    final bloc = ProjectBloc(storage: storage);
    addTearDown(bloc.close);

    // Первое открытие проекта
    final firstStateFuture = bloc.stream.firstWhere(
      (state) => state is ProjectLoaded || state is ProjectError,
    );
    bloc.add(AnalyzeProject(tempDir.path));
    final firstState = await firstStateFuture.timeout(
      const Duration(seconds: 15),
    );

    expect(firstState, isA<ProjectLoaded>());
    final loaded = firstState as ProjectLoaded;

    final base = loaded.nodes.firstWhere((n) => n.name == 'Base');
    final almost = loaded.nodes.firstWhere((n) => n.name == 'Almost');
    final parent = loaded.nodes.firstWhere((n) => n.name == 'Parent');
    expect(base.line, 1);
    expect(parent.line, greaterThan(base.line));
    expect(loaded.allAnomalyNodeIds.length, 1);
    expect(loaded.anomalyNodeIds, contains(base.id));
    // 5 разных классов — ещё не аномалия, нужно больше 5.
    expect(loaded.allAnomalyNodeIds, isNot(contains(almost.id)));
    expect(loaded.anomalyNodeIds, isNot(contains(parent.id)));
    expect(loaded.incomingCount(base.id), 6);
    expect(loaded.incomingCount(almost.id), 5);
    expect(loaded.healthScore, 95);

    // Помечаем аномалию как допустимую
    final updatedFuture = bloc.stream.firstWhere(
      (state) => state is ProjectLoaded && state.ignoredAnomalyIds.isNotEmpty,
    );
    bloc.add(ToggleAnomalyIgnored(base));
    final updatedState = await updatedFuture.timeout(
      const Duration(seconds: 15),
    );

    expect(updatedState, isA<ProjectLoaded>());
    final updated = updatedState as ProjectLoaded;
    expect(updated.anomalyNodeIds, isEmpty);
    expect(updated.ignoredAnomalyIds, contains(base.id));
    expect(updated.healthScore, 100);

    // Решение сохранилось в хранилище
    expect(await storage.getIgnoredAnomalies(tempDir.path), contains(base.id));

    // Второе открытие проекта (как после перезапуска приложения)
    final reopenedBloc = ProjectBloc(storage: storage);
    addTearDown(reopenedBloc.close);

    final reopenedFuture = reopenedBloc.stream.firstWhere(
      (state) => state is ProjectLoaded || state is ProjectError,
    );
    reopenedBloc.add(AnalyzeProject(tempDir.path));
    final reopenedState = await reopenedFuture.timeout(
      const Duration(seconds: 15),
    );

    expect(reopenedState, isA<ProjectLoaded>());
    final reopened = reopenedState as ProjectLoaded;
    final reopenedBase = reopened.nodes.firstWhere((n) => n.name == 'Base');

    expect(reopened.ignoredAnomalyIds, contains(reopenedBase.id));
    expect(reopened.anomalyNodeIds, isEmpty);
    expect(reopened.healthScore, 100);
  });
}
