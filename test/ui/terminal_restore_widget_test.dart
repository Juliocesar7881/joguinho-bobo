import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/state/game_store.dart';
import 'package:lexinexo/src/ui/widgets/game_keyboard.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('entrada incompleta mostra mensagem exata sem consumir linha', (
    tester,
  ) async {
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
    );
    expect(
      tester.widget<GameKeyboard>(find.byType(GameKeyboard)).enabled,
      isTrue,
    );

    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();

    expect(find.text('Complete a palavra.'), findsOneWidget);
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses, isEmpty);
  });

  testWidgets('palavra ausente mostra mensagem exata sem consumir linha', (
    tester,
  ) async {
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.text('Z').last);
    }
    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();

    expect(find.text('Essa palavra não foi encontrada.'), findsOneWidget);
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses, isEmpty);
  });

  testWidgets('restaurar vitória terminal reabre diálogo sem animação', (
    tester,
  ) async {
    final audio = RecordingSuccessAudio();
    final ads = RecordingGameAds();
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

    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
      audio: audio,
      ads: ads,
    );

    expect(find.text('Você acertou!'), findsOneWidget);
    expect(find.text('Próximo nível'), findsOneWidget);
    expect(find.byKey(const Key('success_check_animation')), findsNothing);
    expect(audio.calls, 0);
    expect(ads.naturalBreakCalls, 0);
  });

  testWidgets('restaurar derrota terminal reabre resposta e significado', (
    tester,
  ) async {
    final ads = RecordingGameAds();
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          sessionsByLength: const <int, GameSession>{
            3: GameSession(
              levelNumber: 1,
              submittedGuesses: <String>[
                'dog',
                'dog',
                'dog',
                'dog',
                'dog',
                'dog',
              ],
            ),
          },
        ),
      ),
    );

    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
      ads: ads,
    );

    expect(find.text('Não foi dessa vez'), findsOneWidget);
    expect(find.text('CAT'), findsOneWidget);
    expect(find.text('Tradução: tradução de cat'), findsOneWidget);
    expect(find.textContaining('Significado:'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(ads.naturalBreakCalls, 0);
  });

  testWidgets('fechar durante revelação restaura a vitória persistida', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final firstStore = await createTestStore(storage: storage);
    await pumpGame(
      tester,
      store: firstStore,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    await enterWord(tester, 'cat');
    await tester.pump(const Duration(milliseconds: 20));

    expect(firstStore.sessionFor(GameMode.withHints, 1)?.isWon('cat'), isTrue);
    expect(find.text('Você acertou!'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await firstStore.flush();
    final restored = await createTestStore(storage: storage);
    await pumpGame(
      tester,
      store: restored,
      mode: GameMode.withHints,
      levelNumber: 1,
    );
    expect(find.text('Você acertou!'), findsOneWidget);
  });

  testWidgets('replay limpa só o resultado terminal daquela categoria', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: const <int, int>{3: 1},
          sessionsByLength: const <int, GameSession>{
            3: GameSession(levelNumber: 1, submittedGuesses: <String>['cat']),
            4: GameSession(levelNumber: 51, draft: 'bo'),
          },
        ),
      ),
    );
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    await tester.tap(find.text('Jogar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Você acertou!'), findsNothing);
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses, isEmpty);
    expect(store.lengthProgressFor(GameMode.withHints, 3).completedCount, 1);
    expect(store.sessionFor(GameMode.withHints, 51)?.draft, 'bo');
  });

  testWidgets('falha ao repetir mantém resultado recuperável', (tester) async {
    final storage = _ActionFailingStorage();
    final store = await _terminalStore(storage: storage, won: true);
    storage.failWrites = true;
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    await _tapFailingResultAction(tester, 'Jogar novamente');

    expect(find.text('Você acertou!'), findsOneWidget);
    expect(
      find.text('Não foi possível concluir a ação. Tente novamente.'),
      findsOneWidget,
    );
    expect(store.sessionFor(GameMode.withHints, 1)?.isWon('cat'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao avançar mantém derrota recuperável', (tester) async {
    final storage = _ActionFailingStorage();
    final store = await _terminalStore(storage: storage, won: false);
    storage.failWrites = true;
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    await _tapFailingResultAction(tester, 'Tentar novamente');

    expect(find.text('Não foi dessa vez'), findsOneWidget);
    expect(
      find.text('Não foi possível concluir a ação. Tente novamente.'),
      findsOneWidget,
    );
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses.length, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao voltar aos níveis mantém resultado recuperável', (
    tester,
  ) async {
    final storage = _ActionFailingStorage();
    final store = await _terminalStore(storage: storage, won: true);
    storage.failWrites = true;
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    await _tapFailingResultAction(tester, 'Voltar aos níveis');

    expect(find.text('Você acertou!'), findsOneWidget);
    expect(
      find.text('Não foi possível concluir a ação. Tente novamente.'),
      findsOneWidget,
    );
    expect(store.sessionFor(GameMode.withHints, 1)?.isWon('cat'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vitória no ID 500 conduz à conclusão do modo', (tester) async {
    final completed = <int, int>{
      for (final band in WordLengthBand.values)
        band.wordLength: band.levelCount,
    };
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(
          completedByLength: completed,
          sessionsByLength: const <int, GameSession>{
            8: GameSession(
              levelNumber: 500,
              submittedGuesses: <String>['elephant'],
            ),
          },
          lastSelectedLength: 8,
        ),
      ),
    );
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 500,
    );

    expect(find.text('Nível 40 de 40'), findsOneWidget);
    expect(find.text('Ver conclusão'), findsOneWidget);
    await tester.tap(find.text('Ver conclusão'));
    await tester.pumpAndSettle();

    expect(find.text('Modo zerado!'), findsOneWidget);
    expect(store.lengthProgressFor(GameMode.withHints, 8).session, isNull);
  });
}

Future<GameStore> _terminalStore({
  required _ActionFailingStorage storage,
  required bool won,
}) {
  return createTestStore(
    storage: storage,
    initialSave: appSave(
      withHints: modeProgress(
        completedByLength: won ? const <int, int>{3: 1} : const <int, int>{},
        sessionsByLength: <int, GameSession>{
          3: GameSession(
            levelNumber: 1,
            submittedGuesses: won
                ? const <String>['cat']
                : const <String>['dog', 'dog', 'dog', 'dog', 'dog', 'dog'],
          ),
        },
      ),
    ),
  );
}

Future<void> _tapFailingResultAction(
  WidgetTester tester,
  String actionLabel,
) async {
  await tester.tap(find.text(actionLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _ActionFailingStorage extends MemoryStorage {
  bool failWrites = false;

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('falha de gravação simulada');
    await super.write(value);
  }
}
