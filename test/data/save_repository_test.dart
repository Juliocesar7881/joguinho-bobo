import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/data/save_repository.dart';
import 'package:lexinexo/src/domain/models.dart';

void main() {
  group('SaveRepository', () {
    test(
      'round-trip preserva progresso, tentativas e rascunho por modo',
      () async {
        final storage = _RecordingStorage();
        final repository = SaveRepository(storage);
        final original = AppSave(
          successSoundEnabled: false,
          modes: <GameMode, ModeProgress>{
            GameMode.withHints: const ModeProgress(
              completedThrough: 20,
              lastOpenedLevel: 21,
              session: GameSession(
                levelNumber: 21,
                submittedGuesses: <String>['crane', 'slate'],
                draft: 'br',
              ),
            ),
            GameMode.withoutHints: const ModeProgress(
              completedThrough: 7,
              lastOpenedLevel: 8,
              session: GameSession(levelNumber: 8, draft: 'ca'),
            ),
          },
        );

        await repository.save(original);
        final restored = await repository.load();

        expect(restored.progressFor(GameMode.withHints).completedThrough, 20);
        expect(restored.progressFor(GameMode.withHints).lastOpenedLevel, 21);
        expect(
          restored.progressFor(GameMode.withHints).session?.submittedGuesses,
          <String>['crane', 'slate'],
        );
        expect(restored.progressFor(GameMode.withHints).session?.draft, 'br');
        expect(restored.progressFor(GameMode.withoutHints).completedThrough, 7);
        expect(restored.progressFor(GameMode.withoutHints).lastOpenedLevel, 8);
        expect(
          restored.progressFor(GameMode.withoutHints).session?.draft,
          'ca',
        );
        expect(restored.successSoundEnabled, isFalse);
        expect(
          jsonDecode(storage.value!)['schemaVersion'],
          AppSave.schemaVersion,
        );
      },
    );

    test('escritas concorrentes sao serializadas e a ultima vence', () async {
      final storage = _RecordingStorage(delayWrites: true);
      final repository = SaveRepository(storage);

      final writes = <Future<void>>[
        for (var completed = 1; completed <= 4; completed++)
          repository.save(_saveAt(completed)),
      ];
      await Future.wait(writes);
      await repository.flush();

      expect(storage.maximumConcurrentWrites, 1);
      expect(storage.writtenCompletedValues, <int>[1, 2, 3, 4]);
      final restored = await repository.load();
      expect(restored.progressFor(GameMode.withHints).completedThrough, 4);
    });

    test('falha de escrita nao envenena as escritas seguintes', () async {
      final storage = _RecordingStorage(failFirstWrite: true);
      final repository = SaveRepository(storage);

      await expectLater(repository.save(_saveAt(1)), throwsStateError);
      await repository.save(_saveAt(2));
      await repository.flush();

      final restored = await repository.load();
      expect(restored.progressFor(GameMode.withHints).completedThrough, 2);
    });

    test('leitura que lanca excecao volta ao save inicial', () async {
      final repository = SaveRepository(_ThrowingReadStorage());

      final restored = await repository.load();

      expect(restored.progressFor(GameMode.withHints).completedThrough, 0);
      expect(restored.progressFor(GameMode.withoutHints).session, isNull);
    });

    test('versao desconhecida volta ao save inicial', () async {
      final storage = _RecordingStorage()
        ..value = jsonEncode(<String, Object?>{
          'schemaVersion': 99,
          'modes': <String, Object?>{
            'withHints': <String, Object?>{'completedThrough': 400},
          },
        });
      final restored = await SaveRepository(storage).load();

      expect(restored.progressFor(GameMode.withHints).completedThrough, 0);
      expect(restored.progressFor(GameMode.withoutHints).completedThrough, 0);
    });
  });
}

AppSave _saveAt(int completed) => AppSave(
  modes: <GameMode, ModeProgress>{
    GameMode.withHints: ModeProgress(completedThrough: completed),
    GameMode.withoutHints: const ModeProgress(),
  },
);

class _RecordingStorage implements SaveStorage {
  _RecordingStorage({this.delayWrites = false, this.failFirstWrite = false});

  final bool delayWrites;
  final bool failFirstWrite;
  String? value;
  int _activeWrites = 0;
  int maximumConcurrentWrites = 0;
  int _attempts = 0;
  final List<int> writtenCompletedValues = <int>[];

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String nextValue) async {
    _attempts++;
    _activeWrites++;
    if (_activeWrites > maximumConcurrentWrites) {
      maximumConcurrentWrites = _activeWrites;
    }
    try {
      if (delayWrites) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      if (failFirstWrite && _attempts == 1) {
        throw StateError('falha simulada');
      }
      value = nextValue;
      final decoded = jsonDecode(nextValue) as Map<String, Object?>;
      final modes = decoded['modes']! as Map<String, Object?>;
      final hints = modes['withHints']! as Map<String, Object?>;
      final lengths = hints['lengths']! as Map<String, Object?>;
      writtenCompletedValues.add(
        lengths.values.fold<int>(0, (total, rawProgress) {
          final progress = rawProgress! as Map<String, Object?>;
          return total + (progress['completedCount']! as int);
        }),
      );
    } finally {
      _activeWrites--;
    }
  }
}

class _ThrowingReadStorage implements SaveStorage {
  @override
  Future<String?> read() => Future<String?>.error(StateError('falha simulada'));

  @override
  Future<void> write(String value) async {}
}
