import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kofe_mama/core/data_providers.dart';
import 'package:kofe_mama/main.dart';

import 'fake_kofe_api.dart';

void main() {
  testWidgets('City tap opens venue picker', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(FakeKofeApi())],
        child: const KofeMamaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Выберите город'), findsOneWidget);
    await tester.tap(find.text('Ростов-на-Дону'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Забрать'), findsOneWidget);
    expect(find.text('С собой'), findsOneWidget);
    expect(find.text('Выбрать'), findsOneWidget);
  });
}
