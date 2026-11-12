import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:code_graph/models/class_node.dart';
import 'package:code_graph/models/class_relation.dart';
import 'package:code_graph/widgets/graph_view_widget.dart';

void main() {
  testWidgets('большой граф не пустой и сгруппирован по типам', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final nodes = List.generate(
      500,
      (i) => ClassNode(
        id: 'n$i',
        name: 'Class$i',
        filePath: '/project/file$i.dart',
        language: 'Dart',
        isAbstract: i >= 3 && i < 23,
      ),
    );

    final relations = <ClassRelation>[
      for (var i = 0; i < 100; i++)
        ClassRelation(
          fromClassId: 'n${i + 100}',
          toClassId: 'n0',
          type: 'usage',
        ),
      for (var i = 0; i < 30; i++)
        ClassRelation(
          fromClassId: 'n${i + 200}',
          toClassId: 'n3',
          type: 'inheritance',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphViewWidget(
            nodes: nodes,
            relations: relations,
            anomalyNodeIds: const {'n0', 'n1'},
            ignoredAnomalyIds: const {'n2'},
            selectedNodeId: 'n0',
            onNodeTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Показаны 400 из 500 классов'), findsOneWidget);
    expect(find.text('Аномалии (2)'), findsOneWidget);
    expect(find.text('Исключённые аномалии (1)'), findsOneWidget);
    expect(find.text('Абстракции (20)'), findsOneWidget);
    expect(find.textContaining('Обычные классы'), findsOneWidget);
  });

  testWidgets('обычные классы всегда серые, фильтр не меняет цвет', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const visible = ClassNode(
      id: 'z1',
      name: 'ZClass',
      filePath: '/project/z.dart',
      language: 'Dart',
    );
    const isolated = ClassNode(
      id: 'a1',
      name: 'AIsolated',
      filePath: '/project/a.dart',
      language: 'Dart',
    );

    Widget buildGraph(List<ClassNode> nodes) {
      return MaterialApp(
        home: Scaffold(
          body: GraphViewWidget(
            nodes: nodes,
            relations: const [],
            anomalyNodeIds: const {},
            onNodeTap: (_) {},
          ),
        ),
      );
    }

    Color colorOf(String id) {
      final container = tester.widget<Container>(
        find.byKey(ValueKey('graph-node-$id')),
      );
      final decoration = container.decoration! as BoxDecoration;
      return decoration.color!;
    }

    await tester.pumpWidget(buildGraph(const [isolated, visible]));
    final before = colorOf('z1');

    // Включаем фильтр изолированных: остальные узлы не перекрашиваются.
    await tester.pumpWidget(buildGraph(const [visible]));
    final after = colorOf('z1');

    expect(before, const Color(0xFF4A4A4D));
    expect(after, before);
    expect(find.byKey(const ValueKey('graph-node-a1')), findsNothing);
  });

  testWidgets('при выборе связи двух направлений окрашены по-разному', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const selected = ClassNode(
      id: 's',
      name: 'Selected',
      filePath: '/project/s.dart',
      language: 'Dart',
    );
    const incoming = ClassNode(
      id: 'in',
      name: 'UsesSelected',
      filePath: '/project/in.dart',
      language: 'Dart',
    );
    const outgoing = ClassNode(
      id: 'out',
      name: 'UsedBySelected',
      filePath: '/project/out.dart',
      language: 'Dart',
    );
    const unrelated = ClassNode(
      id: 'other',
      name: 'Unrelated',
      filePath: '/project/other.dart',
      language: 'Dart',
    );
    const child = ClassNode(
      id: 'child',
      name: 'Child',
      filePath: '/project/child.dart',
      language: 'Dart',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphViewWidget(
            nodes: const [selected, incoming, outgoing, unrelated, child],
            relations: const [
              ClassRelation(fromClassId: 'in', toClassId: 's', type: 'usage'),
              ClassRelation(fromClassId: 's', toClassId: 'out', type: 'usage'),
              ClassRelation(
                fromClassId: 'child',
                toClassId: 's',
                type: 'inheritance',
              ),
            ],
            anomalyNodeIds: const {},
            selectedNodeId: 's',
            onNodeTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    Color colorOf(String id) {
      final container = tester.widget<Container>(
        find.byKey(ValueKey('graph-node-$id')),
      );
      final decoration = container.decoration! as BoxDecoration;
      return decoration.color!;
    }

    expect(colorOf('in'), const Color(0xFF29B6F6));
    expect(colorOf('child'), const Color(0xFF29B6F6));
    expect(colorOf('out'), const Color(0xFF4CAF50));
    expect(colorOf('other'), const Color(0xFF4A4A4D));
    expect(colorOf('s'), const Color(0xFF4A4A4D));

    // Выбранный класс выделяется жёлтой рамкой, а не заливкой.
    final selectedContainer = tester.widget<Container>(
      find.byKey(const ValueKey('graph-node-s')),
    );
    final selectedDecoration = selectedContainer.decoration! as BoxDecoration;
    final border = selectedDecoration.border! as Border;
    expect(border.top.color, const Color(0xFFFFD54F));

    expect(find.text('используют / наследуют его'), findsOneWidget);
    expect(find.text('он использует / наследует'), findsOneWidget);
    expect(find.text('использование'), findsNothing);
  });

  testWidgets('класс, связанный в обе стороны, получает градиент', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const selected = ClassNode(
      id: 's',
      name: 'Selected',
      filePath: '/project/s.dart',
      language: 'Dart',
    );
    const mutual = ClassNode(
      id: 'm',
      name: 'Mutual',
      filePath: '/project/m.dart',
      language: 'Dart',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphViewWidget(
            nodes: const [selected, mutual],
            relations: const [
              ClassRelation(fromClassId: 'm', toClassId: 's', type: 'usage'),
              ClassRelation(fromClassId: 's', toClassId: 'm', type: 'usage'),
            ],
            anomalyNodeIds: const {},
            selectedNodeId: 's',
            onNodeTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('graph-node-m')),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, isNull);
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [Color(0xFF29B6F6), Color(0xFF4CAF50)]);
    expect(find.text('связь в обе стороны'), findsOneWidget);
  });

  testWidgets('возврат с экрана графа не оставляет ошибок', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final nodes = List.generate(
      150,
      (i) => ClassNode(
        id: 'n$i',
        name: 'Class$i',
        filePath: '/project/file$i.dart',
        language: 'Dart',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: GraphViewWidget(
                          nodes: nodes,
                          relations: const [],
                          anomalyNodeIds: const {},
                          onNodeTap: (_) {},
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.byType(GraphViewWidget), findsOneWidget);

    Navigator.of(tester.element(find.byType(GraphViewWidget))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Открыть'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
