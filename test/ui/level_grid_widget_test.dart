import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/state/game_store.dart';
import 'package:lexinexo/src/ui/app_theme.dart';
import 'package:lexinexo/src/ui/game_scope.dart';
import 'package:lexinexo/src/ui/screens/level_grid_screen.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final band in WordLengthBand.values) {
    testWidgets(
      'grade de ${band.wordLength} letras tem ${band.levelCount} níveis locais',
      (tester) async {
        final store = await createTestStore();
        await _pumpGrid(tester, store, wordLength: band.wordLength);

        final grid = tester.widget<GridView>(find.byType(GridView));
        expect(grid.childrenDelegate.estimatedChildCount, band.levelCount);
        expect(find.text('${band.wordLength} letras'), findsOneWidget);
        expect(find.text('0/${band.levelCount} concluídos'), findsOneWidget);
      },
    );
  }

  testWidgets('grade representa concluído, próximo, bloqueado e sessão', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{3: 2},
          sessionsByLength: const <int, GameSession>{
            3: GameSession(levelNumber: 3, draft: 'c'),
          },
        ),
      ),
    );
    await _pumpGrid(tester, store);

    expect(
      find.bySemanticsLabel(RegExp(r'Nível 1, concluído')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Nível 3, disponível, partida em andamento'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Nível 4, bloqueado')),
      findsOneWidget,
    );
    expect(find.text('2/50 concluídos'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Continuar usa numeração local e restaura a sessão', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{4: 2},
          sessionsByLength: const <int, GameSession>{
            4: GameSession(levelNumber: 53, draft: 'bo'),
          },
          lastSelectedLength: 4,
        ),
      ),
    );
    await _pumpGrid(tester, store, wordLength: 4);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Nível 3 de 100'), findsOneWidget);
    expect(find.text('Com dicas • 4 letras'), findsOneWidget);
    expect(store.sessionFor(GameMode.withHints, 53)?.draft, 'bo');
  });

  testWidgets('número local 1 de quatro letras abre o ID global 51', (
    tester,
  ) async {
    final store = await createTestStore();
    await _pumpGrid(tester, store, wordLength: 4);

    expect(store.globalLevelForLocal(4, 1), 51);
    await tester.tap(find.bySemanticsLabel('Nível 1, disponível'));
    await tester.pumpAndSettle();

    expect(find.text('Nível 1 de 100'), findsOneWidget);
    expect(store.sessionFor(GameMode.withHints, 51), isNotNull);
    expect(store.sessionFor(GameMode.withHints, 1), isNull);
  });

  testWidgets('mapeamento final de oito letras permanece no ID 500', (
    tester,
  ) async {
    final store = await createTestStore();
    expect(store.globalLevelForLocal(8, 40), 500);
    expect(store.localLevelNumber(500), 40);
    expect(store.levelForLocal(GameMode.withHints, 8, 40).number, 500);
  });

  testWidgets('resultado terminal é restaurado antes de qualquer outro nível', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{3: 1},
          sessionsByLength: const <int, GameSession>{
            3: GameSession(levelNumber: 1, submittedGuesses: <String>['cat']),
          },
        ),
      ),
    );
    await _pumpGrid(tester, store);

    expect(find.text('Ver resultado'), findsOneWidget);
    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();

    expect(find.text('Nível 1 de 50'), findsOneWidget);
    expect(find.text('Você acertou!'), findsOneWidget);
    expect(store.sessionFor(GameMode.withHints, 1), isNotNull);
    expect(store.sessionFor(GameMode.withHints, 2), isNull);
  });

  testWidgets('replay substitui só a sessão da categoria escolhida', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{3: 2},
          sessionsByLength: const <int, GameSession>{
            3: GameSession(levelNumber: 3, draft: 'c'),
            4: GameSession(levelNumber: 51, draft: 'bo'),
          },
        ),
      ),
    );
    await _pumpGrid(tester, store);

    await tester.tap(find.bySemanticsLabel('Nível 1, concluído'));
    await tester.pumpAndSettle();

    expect(find.text('Nível 1 de 50'), findsOneWidget);
    expect(store.lengthProgressFor(GameMode.withHints, 3).completedCount, 2);
    expect(store.sessionFor(GameMode.withHints, 1), isNotNull);
    expect(store.sessionFor(GameMode.withHints, 3), isNull);
    expect(store.sessionFor(GameMode.withHints, 51)?.draft, 'bo');
  });

  testWidgets('categoria completa abre conclusão daquela faixa', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{4: 100},
          lastSelectedLength: 4,
        ),
      ),
    );
    await _pumpGrid(tester, store, wordLength: 4);

    expect(find.text('Categoria concluída'), findsOneWidget);
    await tester.tap(find.text('Categoria concluída'));
    await tester.pumpAndSettle();

    expect(find.text('4 letras concluídas!'), findsOneWidget);
    expect(find.text('Modo zerado!'), findsNothing);
  });

  testWidgets('último nível da categoria oferece Ver conclusão', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{4: 100},
          sessionsByLength: const <int, GameSession>{
            4: GameSession(
              levelNumber: 150,
              submittedGuesses: <String>['book'],
            ),
          },
          lastSelectedLength: 4,
        ),
      ),
    );
    await _pumpGrid(tester, store, wordLength: 4);

    expect(find.text('Ver resultado'), findsOneWidget);
    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    expect(find.text('Nível 100 de 100'), findsOneWidget);
    expect(find.text('Ver conclusão'), findsOneWidget);
  });
}

Future<void> _pumpGrid(
  WidgetTester tester,
  GameStore store, {
  int wordLength = 3,
}) async {
  await tester.pumpWidget(
    GameScope(
      store: store,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: LevelGridScreen(mode: GameMode.withHints, wordLength: wordLength),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
