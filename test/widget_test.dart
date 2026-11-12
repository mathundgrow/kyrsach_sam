import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:code_graph/main.dart';

void main() {
  testWidgets('Экран приветствия отображается', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Графовый ИИ Анализатор'), findsOneWidget);
    expect(find.text('Открыть проект'), findsOneWidget);
    expect(find.text('История пуста'), findsOneWidget);
  });
}
