import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/data/catalog_repository.dart';
import 'package:lexinexo/src/data/save_repository.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/state/game_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryStorage storage;
  late GameStore store;

  setUp(() async {
    storage = MemoryStorage();
    store = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await store.initialize();
  });

  test('palavra invalida nao consome tentativa', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'zzz');
    final outcome = await store.submit(GameMode.withHints, 1);
    expect(outcome.status, SubmitStatus.notFound);
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses, isEmpty);
  });

  test('palavra incompleta nao consome tentativa nem apaga rascunho', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'ca');

    final outcome = await store.submit(GameMode.withHints, 1);

    expect(outcome.status, SubmitStatus.incomplete);
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses, isEmpty);
    expect(store.sessionFor(GameMode.withHints, 1)?.draft, 'ca');
  });

  test(
    'vitoria desbloqueia exatamente o nivel seguinte e separa modos',
    () async {
      await store.openLevel(GameMode.withHints, 1);
      _type(store, GameMode.withHints, 1, 'cat');
      final outcome = await store.submit(GameMode.withHints, 1);
      expect(outcome.won, isTrue);
      expect(store.progressFor(GameMode.withHints).completedThrough, 1);
      expect(store.progressFor(GameMode.withoutHints).completedThrough, 0);

      await store.restartLevel(GameMode.withHints, 1);
      _type(store, GameMode.withHints, 1, 'cat');
      await store.submit(GameMode.withHints, 1);
      expect(store.progressFor(GameMode.withHints).completedThrough, 1);
    },
  );

  test('seis erros causam derrota sem desbloqueio', () async {
    await store.openLevel(GameMode.withHints, 1);
    for (var attempt = 0; attempt < 6; attempt++) {
      _type(store, GameMode.withHints, 1, 'dog');
      final outcome = await store.submit(GameMode.withHints, 1);
      if (attempt < 5) expect(outcome.lost, isFalse);
      if (attempt == 5) expect(outcome.lost, isTrue);
    }
    expect(store.progressFor(GameMode.withHints).completedThrough, 0);
  });

  test('nivel 500 conclui somente o modo correspondente', () async {
    final seeded = AppSave(
      modes: <GameMode, ModeProgress>{
        GameMode.withHints: const ModeProgress(completedThrough: 499),
        GameMode.withoutHints: const ModeProgress(completedThrough: 3),
      },
    );
    storage.value = jsonEncode(seeded.toJson());
    store = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await store.initialize();
    await store.openLevel(GameMode.withHints, 500);
    _type(store, GameMode.withHints, 500, 'elephant');
    final outcome = await store.submit(GameMode.withHints, 500);
    expect(outcome.won, isTrue);
    expect(store.progressFor(GameMode.withHints).completedThrough, 500);
    expect(store.progressFor(GameMode.withoutHints).completedThrough, 3);
  });

  test('nivel bloqueado nao pode ser aberto', () async {
    expect(() => store.openLevel(GameMode.withHints, 2), throwsArgumentError);
    expect(store.progressFor(GameMode.withHints).session, isNull);
  });

  test('replay de nivel concluido nao move a fronteira de progresso', () async {
    storage.value = jsonEncode(
      AppSave(
        modes: <GameMode, ModeProgress>{
          GameMode.withHints: const ModeProgress(completedThrough: 3),
          GameMode.withoutHints: const ModeProgress(),
        },
      ).toJson(),
    );
    store = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await store.initialize();

    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'cat');
    final outcome = await store.submit(GameMode.withHints, 1);

    expect(outcome.won, isTrue);
    expect(store.progressFor(GameMode.withHints).completedThrough, 3);
    await store.restartLevel(GameMode.withHints, 1);
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses, isEmpty);
  });

  test('sessoes e rascunhos sao independentes entre os modos', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'ca');
    await store.openLevel(GameMode.withoutHints, 1);
    _type(store, GameMode.withoutHints, 1, 'do');
    await store.flush();

    expect(store.sessionFor(GameMode.withHints, 1)?.draft, 'ca');
    expect(store.sessionFor(GameMode.withoutHints, 1)?.draft, 'do');

    final restored = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await restored.initialize();
    expect(restored.sessionFor(GameMode.withHints, 1)?.draft, 'ca');
    expect(restored.sessionFor(GameMode.withoutHints, 1)?.draft, 'do');
  });

  test('abrir outro nivel substitui apenas a sessao daquele modo', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'cat');
    await store.submit(GameMode.withHints, 1);
    await store.openLevel(GameMode.withoutHints, 1);
    _type(store, GameMode.withoutHints, 1, 'd');

    await store.openLevel(GameMode.withHints, 2);

    expect(store.sessionFor(GameMode.withHints, 1), isNull);
    expect(store.sessionFor(GameMode.withHints, 2), isNotNull);
    expect(store.sessionFor(GameMode.withoutHints, 1)?.draft, 'd');
  });

  test('vitoria terminal e gravada antes de qualquer animacao de UI', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'cat');

    final outcome = await store.submit(GameMode.withHints, 1);
    expect(outcome.won, isTrue);

    final restored = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await restored.initialize();
    final session = restored.sessionFor(GameMode.withHints, 1);
    expect(session?.isWon('cat'), isTrue);
    expect(restored.progressFor(GameMode.withHints).completedThrough, 1);
  });

  test(
    'vitoria terminal valida no frontier normaliza progresso e libera restart',
    () async {
      final band = WordLengthBand.threeLetters;
      storage.value = jsonEncode(
        AppSave(
          modes: <GameMode, ModeProgress>{
            GameMode.withHints: ModeProgress(
              lengths: <WordLengthBand, LengthProgress>{
                band: const LengthProgress(
                  completedCount: 0,
                  lastOpenedLevel: 1,
                  session: GameSession(
                    levelNumber: 1,
                    submittedGuesses: <String>['cat'],
                  ),
                ),
              },
            ),
          },
        ).toJson(),
      );

      final restored = GameStore(
        catalog: FakeCatalogRepository(),
        saves: SaveRepository(storage),
      );
      await restored.initialize();

      expect(
        restored.lengthProgressFor(GameMode.withHints, 3).completedCount,
        1,
      );
      expect(restored.isLevelUnlocked(GameMode.withHints, 2), isTrue);
      await restored.restartLevel(GameMode.withHints, 2);
      expect(
        restored.sessionFor(GameMode.withHints, 2)?.submittedGuesses,
        isEmpty,
      );

      final roundTrip = GameStore(
        catalog: FakeCatalogRepository(),
        saves: SaveRepository(storage),
      );
      await roundTrip.initialize();
      expect(
        roundTrip.lengthProgressFor(GameMode.withHints, 3).completedCount,
        1,
      );
      expect(roundTrip.sessionFor(GameMode.withHints, 2), isNotNull);
    },
  );

  test('falha ao persistir impede confirmar a vitoria em memoria', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'cat');
    await store.flush();
    storage.failWrites = true;

    await expectLater(store.submit(GameMode.withHints, 1), throwsStateError);

    expect(store.progressFor(GameMode.withHints).completedThrough, 0);
    expect(store.sessionFor(GameMode.withHints, 1)?.submittedGuesses, isEmpty);
    expect(store.sessionFor(GameMode.withHints, 1)?.draft, 'cat');
  });

  test('derrota terminal com seis tentativas e restaurada', () async {
    await store.openLevel(GameMode.withHints, 1);
    for (var attempt = 0; attempt < 6; attempt++) {
      _type(store, GameMode.withHints, 1, 'dog');
      await store.submit(GameMode.withHints, 1);
    }

    final restored = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await restored.initialize();
    final session = restored.sessionFor(GameMode.withHints, 1);
    expect(session?.submittedGuesses, hasLength(6));
    expect(session?.isLost('cat'), isTrue);
    expect(restored.progressFor(GameMode.withHints).completedThrough, 0);
  });

  test('sessao terminal permanece ate uma acao explicita', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'cat');
    await store.submit(GameMode.withHints, 1);

    await store.openLevel(GameMode.withHints, 1);
    expect(store.sessionFor(GameMode.withHints, 1)?.isWon('cat'), isTrue);

    await store.clearSession(GameMode.withHints);
    expect(store.progressFor(GameMode.withHints).session, isNull);
  });

  test('rascunho e tentativa sao restaurados do armazenamento', () async {
    await store.openLevel(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'dog');
    await store.submit(GameMode.withHints, 1);
    _type(store, GameMode.withHints, 1, 'ca');
    await store.flush();

    final restored = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await restored.initialize();
    final session = restored.sessionFor(GameMode.withHints, 1);
    expect(session?.submittedGuesses, <String>['dog']);
    expect(session?.draft, 'ca');
  });

  test('JSON corrompido inicia com progresso seguro', () async {
    storage.value = '{not json';
    final restored = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await restored.initialize();
    expect(restored.progressFor(GameMode.withHints).completedThrough, 0);
  });

  test('sessao adulterada e descartada sem apagar progresso valido', () async {
    storage.value = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'modes': <String, Object?>{
        'withHints': <String, Object?>{
          'completedThrough': 8,
          'lastOpenedLevel': 9,
          'session': <String, Object?>{
            'levelNumber': 10,
            'submittedGuesses': <String>[],
            'draft': 'c',
          },
        },
        'withoutHints': <String, Object?>{
          'completedThrough': 2,
          'lastOpenedLevel': 3,
          'session': null,
        },
      },
    });

    final restored = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await restored.initialize();

    expect(restored.progressFor(GameMode.withHints).completedThrough, 8);
    expect(restored.progressFor(GameMode.withHints).session, isNull);
    expect(restored.progressFor(GameMode.withoutHints).completedThrough, 2);
  });

  test('primeiro nível de cada tamanho começa liberado', () async {
    for (final band in WordLengthBand.values) {
      expect(
        store.isLevelUnlocked(GameMode.withHints, band.firstGlobalLevel),
        isTrue,
      );
      if (band.levelCount > 1) {
        expect(
          store.isLevelUnlocked(GameMode.withHints, band.firstGlobalLevel + 1),
          isFalse,
        );
      }
    }
  });

  test(
    'progresso e sessões são independentes por tamanho no mesmo modo',
    () async {
      await store.openLevel(GameMode.withHints, 1);
      _type(store, GameMode.withHints, 1, 'ca');
      await store.openLevel(GameMode.withHints, 51);
      _type(store, GameMode.withHints, 51, 'tr');

      expect(store.sessionFor(GameMode.withHints, 1)?.draft, 'ca');
      expect(store.sessionFor(GameMode.withHints, 51)?.draft, 'tr');

      _type(store, GameMode.withHints, 51, 'ee');
      final outcome = await store.submit(GameMode.withHints, 51);

      expect(outcome.won, isTrue);
      expect(store.lengthProgressFor(GameMode.withHints, 3).completedCount, 0);
      expect(store.lengthProgressFor(GameMode.withHints, 4).completedCount, 1);
      expect(store.nextLevelFor(GameMode.withHints, 4), 52);
      expect(store.isLevelUnlocked(GameMode.withHints, 52), isTrue);
    },
  );

  test('último nível conclui somente sua categoria', () async {
    final fourLetters = WordLengthBand.fourLetters;
    storage.value = jsonEncode(
      AppSave(
        modes: <GameMode, ModeProgress>{
          GameMode.withHints: ModeProgress(
            lengths: <WordLengthBand, LengthProgress>{
              fourLetters: LengthProgress(
                completedCount: 99,
                lastOpenedLevel: 150,
              ),
            },
            lastSelectedLength: 4,
          ),
        },
      ).toJson(),
    );
    store = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await store.initialize();

    await store.openLevel(GameMode.withHints, 150);
    _type(store, GameMode.withHints, 150, 'tree');
    await store.submit(GameMode.withHints, 150);

    expect(store.lengthProgressFor(GameMode.withHints, 4).completedCount, 100);
    expect(
      store.lengthProgressFor(GameMode.withHints, 4).isComplete(fourLetters),
      isTrue,
    );
    expect(store.progressFor(GameMode.withHints).isComplete, isFalse);
  });

  test('save v1 é migrado e regravado como v2 durante inicialização', () async {
    storage.value = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'modes': <String, Object?>{
        'withHints': <String, Object?>{
          'completedThrough': 52,
          'lastOpenedLevel': 53,
          'session': null,
        },
      },
    });
    store = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );

    await store.initialize();

    final raw = jsonDecode(storage.value!) as Map<String, Object?>;
    expect(raw['schemaVersion'], 2);
    expect(store.lengthProgressFor(GameMode.withHints, 3).completedCount, 50);
    expect(store.lengthProgressFor(GameMode.withHints, 4).completedCount, 2);
    expect(store.save.needsMigration, isFalse);
  });

  test('preferência de som é persistida', () async {
    expect(store.successSoundEnabled, isTrue);
    await store.setSuccessSoundEnabled(false);

    final restored = GameStore(
      catalog: FakeCatalogRepository(),
      saves: SaveRepository(storage),
    );
    await restored.initialize();

    expect(restored.successSoundEnabled, isFalse);
  });

  test(
    'vitória, som e flush concorrentes preservam o estado cumulativo',
    () async {
      final blockingStorage = BlockingStorage();
      final concurrentStore = GameStore(
        catalog: FakeCatalogRepository(),
        saves: SaveRepository(blockingStorage),
      );
      await concurrentStore.initialize();
      await concurrentStore.openLevel(GameMode.withHints, 1);
      _type(concurrentStore, GameMode.withHints, 1, 'cat');
      await concurrentStore.flush();

      blockingStorage.blockNextWrite();
      final submitFuture = concurrentStore.submit(GameMode.withHints, 1);
      await blockingStorage.waitUntilBlocked;
      final soundFuture = concurrentStore.setSuccessSoundEnabled(false);
      final flushFuture = concurrentStore.flush();

      expect(
        concurrentStore.lengthProgressFor(GameMode.withHints, 3).completedCount,
        1,
      );
      expect(concurrentStore.successSoundEnabled, isFalse);

      blockingStorage.releaseWrite();
      final outcome = await submitFuture;
      await soundFuture;
      await flushFuture;
      expect(outcome.won, isTrue);

      final restored = GameStore(
        catalog: FakeCatalogRepository(),
        saves: SaveRepository(blockingStorage),
      );
      await restored.initialize();
      expect(
        restored.lengthProgressFor(GameMode.withHints, 3).completedCount,
        1,
      );
      expect(restored.successSoundEnabled, isFalse);
      expect(restored.sessionFor(GameMode.withHints, 1)?.isWon('cat'), isTrue);
    },
  );
  test(
    'falha concorrente nao reaparece no disco por som ou outro modo',
    () async {
      final blockingStorage = BlockingStorage();
      final concurrentStore = GameStore(
        catalog: FakeCatalogRepository(),
        saves: SaveRepository(blockingStorage),
      );
      await concurrentStore.initialize();
      await concurrentStore.openLevel(GameMode.withHints, 1);
      _type(concurrentStore, GameMode.withHints, 1, 'cat');
      await concurrentStore.flush();

      blockingStorage.blockNextWrite(fail: true);
      final failedVictory = concurrentStore.submit(GameMode.withHints, 1);
      await blockingStorage.waitUntilBlocked;

      final soundMutation = concurrentStore.setSuccessSoundEnabled(false);
      final otherModeMutation = concurrentStore.openLevel(
        GameMode.withoutHints,
        1,
      );
      _type(concurrentStore, GameMode.withoutHints, 1, 'do');
      blockingStorage.releaseWrite();

      await expectLater(failedVictory, throwsStateError);
      await soundMutation;
      await otherModeMutation;
      await concurrentStore.flush();

      expect(
        concurrentStore.lengthProgressFor(GameMode.withHints, 3).completedCount,
        0,
      );
      expect(concurrentStore.sessionFor(GameMode.withHints, 1)?.draft, 'cat');
      expect(concurrentStore.successSoundEnabled, isFalse);
      expect(concurrentStore.sessionFor(GameMode.withoutHints, 1)?.draft, 'do');

      final restored = GameStore(
        catalog: FakeCatalogRepository(),
        saves: SaveRepository(blockingStorage),
      );
      await restored.initialize();
      expect(
        restored.lengthProgressFor(GameMode.withHints, 3).completedCount,
        0,
      );
      expect(restored.sessionFor(GameMode.withHints, 1)?.draft, 'cat');
      expect(
        restored.sessionFor(GameMode.withHints, 1)?.submittedGuesses,
        isEmpty,
      );
      expect(restored.successSoundEnabled, isFalse);
      expect(restored.sessionFor(GameMode.withoutHints, 1)?.draft, 'do');
    },
  );
}

void _type(GameStore store, GameMode mode, int level, String word) {
  for (final letter in word.split('')) {
    store.addLetter(mode, level, letter);
  }
}

class MemoryStorage implements SaveStorage {
  String? value;
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('falha simulada');
    this.value = value;
  }
}

class BlockingStorage implements SaveStorage {
  String? value;
  Completer<void>? _writeStarted;
  Completer<void>? _writeGate;
  bool _failBlockedWrite = false;

  Future<void> get waitUntilBlocked => _writeStarted!.future;

  void blockNextWrite({bool fail = false}) {
    _writeStarted = Completer<void>();
    _writeGate = Completer<void>();
    _failBlockedWrite = fail;
  }

  void releaseWrite() => _writeGate!.complete();

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    final started = _writeStarted;
    final gate = _writeGate;
    if (started != null && gate != null && !started.isCompleted) {
      started.complete();
      await gate.future;
      final fail = _failBlockedWrite;
      _writeStarted = null;
      _writeGate = null;
      _failBlockedWrite = false;
      if (fail) throw StateError('falha bloqueada simulada');
    }
    this.value = value;
  }
}

class FakeCatalogRepository extends CatalogRepository {
  static const accepted = <String>{
    'cat',
    'dog',
    'tree',
    'crane',
    'planet',
    'teacher',
    'elephant',
  };

  @override
  Future<void> load() async {}

  @override
  WordLevel level(GameMode mode, int number) {
    final band = WordLengthBand.tryFromGlobalLevel(number)!;
    final answer = switch (band.wordLength) {
      3 => 'cat',
      4 => 'tree',
      5 => 'crane',
      6 => 'planet',
      7 => 'teacher',
      _ => 'elephant',
    };
    return WordLevel(
      number: number,
      answer: answer,
      translation: 'tradução',
      meaning: 'Significado adequado para a palavra de teste.',
      hint: mode == GameMode.withHints
          ? 'Dica adequada para a palavra de teste.'
          : null,
      hintEn: mode == GameMode.withHints
          ? 'A suitable hint for the test word.'
          : null,
    );
  }

  @override
  List<WordLevel> levelsFor(GameMode mode) => <WordLevel>[
    for (var index = 1; index <= 500; index++) level(mode, index),
  ];

  @override
  Future<bool> isAccepted(String word) async => accepted.contains(word);
}
