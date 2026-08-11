import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lexinexo/src/app.dart';
import 'package:lexinexo/src/data/catalog_repository.dart';
import 'package:lexinexo/src/data/save_repository.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/state/game_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'catalogo real e SharedPreferences restauram a vitoria do nivel 1',
    (tester) async {
      final storage = PreferencesSaveStorage();
      await storage.write(jsonEncode(AppSave().toJson()));
      final store = GameStore(
        catalog: CatalogRepository(),
        saves: SaveRepository(storage),
      );
      await store.initialize();
      final answer = store.level(GameMode.withHints, 1).answer;

      expect(answer, matches(RegExp(r'^[a-z]{3}$')));
      await tester.pumpWidget(LexiNexoApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Com dicas'));
      await tester.pumpAndSettle();
      await _openLength(tester, 3);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await _submit(tester, answer);

      expect(find.text('Você acertou!'), findsOneWidget);
      expect(store.progressFor(GameMode.withHints).completedThrough, 1);

      await store.flush();
      await tester.pumpWidget(const SizedBox.shrink());
      final restoredStore = GameStore(
        catalog: CatalogRepository(),
        saves: SaveRepository(PreferencesSaveStorage()),
      );
      await restoredStore.initialize();
      expect(restoredStore.progressFor(GameMode.withHints).completedThrough, 1);
      expect(
        restoredStore
            .sessionFor(GameMode.withHints, 1)
            ?.isWon(restoredStore.level(GameMode.withHints, 1).answer),
        isTrue,
      );
    },
  );

  testWidgets('vence, perde, alterna modos e restaura o progresso', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final firstStore = await _newStore(storage);
    await tester.pumpWidget(LexiNexoApp(store: firstStore));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Com dicas'));
    await tester.pumpAndSettle();
    await _openLength(tester, 3);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await _submit(tester, 'cat');
    expect(find.text('Você acertou!'), findsOneWidget);
    await tester.tap(find.text('Voltar aos níveis'));
    await tester.pumpAndSettle();
    expect(find.text('1/50 concluídos'), findsOneWidget);

    await _tapBack(tester);
    await _tapBack(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem dicas'));
    await tester.pumpAndSettle();
    await _openLength(tester, 3);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 6; attempt++) {
      await _submit(tester, 'dog');
    }
    expect(find.text('Não foi dessa vez'), findsOneWidget);
    expect(find.text('CAT'), findsOneWidget);
    await tester.tap(find.text('Voltar aos níveis'));
    await tester.pumpAndSettle();
    await _tapBack(tester);
    await _tapBack(tester);
    await tester.pumpAndSettle();

    await firstStore.flush();
    await tester.pumpWidget(const SizedBox.shrink());
    final restoredStore = await _newStore(storage);
    await tester.pumpWidget(LexiNexoApp(store: restoredStore));
    await tester.pumpAndSettle();

    expect(find.text('1/500'), findsOneWidget);
    expect(find.text('0/500'), findsOneWidget);
  });

  testWidgets(
    'catalogo e preferencias reais restauram derrota e rascunho nos dois modos',
    (tester) async {
      final storage = PreferencesSaveStorage();
      await storage.write(jsonEncode(AppSave().toJson()));
      final store = GameStore(
        catalog: CatalogRepository(),
        saves: SaveRepository(storage),
      );
      await store.initialize();
      final noHintsLevel = store.level(GameMode.withoutHints, 1);
      expect(noHintsLevel.answer, isNot('dog'));
      expect(await store.catalog.isAccepted('dog'), isTrue);

      await tester.pumpWidget(LexiNexoApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sem dicas'));
      await tester.pumpAndSettle();
      await _openLength(tester, 3);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 6; attempt++) {
        await _submit(tester, 'dog');
      }
      expect(find.text('Não foi dessa vez'), findsOneWidget);
      await store.flush();

      await tester.pumpWidget(const SizedBox.shrink());
      final restored = GameStore(
        catalog: CatalogRepository(),
        saves: SaveRepository(PreferencesSaveStorage()),
      );
      await restored.initialize();
      expect(
        restored
            .sessionFor(GameMode.withoutHints, 1)
            ?.isLost(noHintsLevel.answer),
        isTrue,
      );
      expect(restored.progressFor(GameMode.withHints).completedThrough, 0);

      await tester.pumpWidget(LexiNexoApp(store: restored));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sem dicas'));
      await tester.pumpAndSettle();
      await _openLength(tester, 3);
      expect(find.text('Ver resultado'), findsOneWidget);
      await tester.tap(find.text('Ver resultado'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi dessa vez'), findsOneWidget);
      await tester.tap(find.text('Voltar aos níveis'));
      await tester.pumpAndSettle();
      await _tapBack(tester);
      await _tapBack(tester);

      await tester.tap(find.text('Com dicas'));
      await tester.pumpAndSettle();
      await _openLength(tester, 3);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final firstLetter = restored
          .level(GameMode.withHints, 1)
          .answer[0]
          .toUpperCase();
      await tester.tap(find.text(firstLetter).last);
      await tester.pump();
      await _tapBack(tester);
      await restored.flush();

      await tester.pumpWidget(const SizedBox.shrink());
      final draftRestored = GameStore(
        catalog: CatalogRepository(),
        saves: SaveRepository(PreferencesSaveStorage()),
      );
      await draftRestored.initialize();
      expect(
        draftRestored.sessionFor(GameMode.withHints, 1)?.draft,
        firstLetter.toLowerCase(),
      );
      expect(draftRestored.progressFor(GameMode.withoutHints).session, isNull);
    },
  );
}

Future<void> _submit(WidgetTester tester, String word) async {
  for (final letter in word.toUpperCase().split('')) {
    await tester.tap(find.text(letter).last);
  }
  await tester.tap(find.text('ENTER'));
  for (var attempt = 0; attempt < 120; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (_resultIsVisible() || _enterIsEnabled(tester)) break;
    if (attempt.isEven) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
  }
  await tester.pumpAndSettle();
}

bool _resultIsVisible() =>
    find.text('Você acertou!').evaluate().isNotEmpty ||
    find.text('Não foi dessa vez').evaluate().isNotEmpty;

bool _enterIsEnabled(WidgetTester tester) {
  final enter = find.byKey(const ValueKey<String>('special_key_enter'));
  final inkWell = find.descendant(of: enter, matching: find.byType(InkWell));
  if (inkWell.evaluate().isEmpty) return false;
  return tester.widget<InkWell>(inkWell).onTap != null;
}

Future<void> _openLength(WidgetTester tester, int wordLength) async {
  final card = find.byKey(ValueKey<String>('length_card_$wordLength'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Voltar').last);
  await tester.pumpAndSettle();
}

Future<GameStore> _newStore(_MemoryStorage storage) async {
  final store = GameStore(
    catalog: _FakeCatalog(),
    saves: SaveRepository(storage),
  );
  await store.initialize();
  return store;
}

class _MemoryStorage implements SaveStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _FakeCatalog extends CatalogRepository {
  static const answers = <int, String>{
    3: 'cat',
    4: 'book',
    5: 'crane',
    6: 'planet',
    7: 'journey',
    8: 'elephant',
  };
  static const wrongAnswers = <int, String>{
    3: 'dog',
    4: 'lamp',
    5: 'stone',
    6: 'flower',
    7: 'blanket',
    8: 'mountain',
  };
  static final accepted = <String>{...answers.values, ...wrongAnswers.values};

  @override
  Future<void> load() async {}

  @override
  WordLevel level(GameMode mode, int number) {
    final length = WordLengthBand.tryFromGlobalLevel(number)!.wordLength;
    final answer = answers[length]!;
    return WordLevel(
      number: number,
      answer: answer,
      translation: 'tradução de $answer',
      meaning: 'Significado comum da palavra $answer.',
      hint: mode == GameMode.withHints
          ? 'Uma pista em português para esta palavra.'
          : null,
      hintEn: mode == GameMode.withHints
          ? 'An English hint for this word.'
          : null,
    );
  }

  @override
  List<WordLevel> levelsFor(GameMode mode) => <WordLevel>[
    for (var number = 1; number <= 500; number++) level(mode, number),
  ];

  @override
  Future<bool> isAccepted(String word) async => accepted.contains(word);
}
