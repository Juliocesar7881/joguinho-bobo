import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/ui/app_theme.dart';
import 'package:lexinexo/src/ui/game_scope.dart';
import 'package:lexinexo/src/ui/screens/category_completion_screen.dart';
import 'package:lexinexo/src/ui/screens/word_length_screen.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seletor mostra seis categorias, contagens e estados', (
    tester,
  ) async {
    final progress = modeProgress(
      completedByLength: const <int, int>{3: 50, 4: 2, 5: 1},
      sessionsByLength: const <int, GameSession>{
        4: GameSession(levelNumber: 53, draft: 'bo'),
        5: GameSession(levelNumber: 151, submittedGuesses: <String>['crane']),
      },
    );
    final store = await createTestStore(
      initialSave: appSave(withHints: progress),
    );
    final semantics = tester.ensureSemantics();
    await _pumpLengths(tester, store);

    for (final band in WordLengthBand.values) {
      expect(
        find.byKey(ValueKey<String>('length_card_${band.wordLength}')),
        findsOneWidget,
      );
    }
    expect(find.text('53/500 desafios concluídos'), findsOneWidget);
    expect(find.text('50/50 concluídos'), findsOneWidget);
    expect(find.text('2/100 concluídos'), findsOneWidget);
    expect(find.text('1/125 concluídos'), findsOneWidget);
    expect(find.text('Categoria concluída'), findsOneWidget);
    expect(find.text('Partida em andamento'), findsOneWidget);
    expect(find.text('Resultado pendente'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'3 letras, concluída')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'4 letras, Partida em andamento')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('categorias mantêm sessões independentes ao alternar tamanho', (
    tester,
  ) async {
    final progress = modeProgress(
      sessionsByLength: const <int, GameSession>{
        3: GameSession(levelNumber: 1, draft: 'c'),
        4: GameSession(levelNumber: 51, draft: 'bo'),
      },
    );
    final store = await createTestStore(
      initialSave: appSave(withHints: progress),
    );
    await _pumpLengths(tester, store);

    await tester.tap(find.byKey(const ValueKey<String>('length_card_3')));
    await tester.pumpAndSettle();
    expect(find.text('3 letras'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final fourLetters = find.byKey(const ValueKey<String>('length_card_4'));
    await tester.ensureVisible(fourLetters);
    await tester.tap(fourLetters);
    await tester.pumpAndSettle();
    expect(find.text('4 letras'), findsOneWidget);
    expect(store.sessionFor(GameMode.withHints, 1)?.draft, 'c');
    expect(store.sessionFor(GameMode.withHints, 51)?.draft, 'bo');
    expect(store.progressFor(GameMode.withHints).lastSelectedLength, 4);
  });

  testWidgets('semântica prioriza sessão mesmo em categoria concluída', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{3: 50, 4: 100},
          sessionsByLength: const <int, GameSession>{
            3: GameSession(levelNumber: 1, submittedGuesses: <String>['cat']),
            4: GameSession(levelNumber: 51, draft: 'bo'),
          },
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await _pumpLengths(tester, store);

    expect(
      find.bySemanticsLabel(
        RegExp(r'3 letras, Resultado pendente, 50 de 50 concluídos'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'4 letras, Partida em andamento, 100 de 100 concluídos'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('modo completo oferece sua conclusão', (tester) async {
    final completed = <int, int>{
      for (final band in WordLengthBand.values)
        band.wordLength: band.levelCount,
    };
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(completedByLength: completed),
      ),
    );
    await _pumpLengths(tester, store);

    expect(find.byKey(const Key('mode_completion_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mode_completion_button')));
    await tester.pumpAndSettle();
    expect(find.text('Modo zerado!'), findsOneWidget);
  });

  testWidgets('conclusão da categoria não afirma conclusão do modo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryCompletionScreen(
          mode: GameMode.withHints,
          band: WordLengthBand.fourLetters,
        ),
      ),
    );

    expect(find.text('4 letras concluídas!'), findsOneWidget);
    expect(find.textContaining('100 desafios de 4 letras'), findsOneWidget);
    expect(find.text('Voltar aos tamanhos'), findsOneWidget);
    expect(find.text('Modo zerado!'), findsNothing);
  });
}

Future<void> _pumpLengths(WidgetTester tester, dynamic store) async {
  await tester.pumpWidget(
    GameScope(
      store: store,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const WordLengthScreen(mode: GameMode.withHints),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
