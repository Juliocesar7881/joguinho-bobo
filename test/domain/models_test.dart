import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';

void main() {
  test('faixas convertem números locais e globais nos limites', () {
    expect(WordLengthBand.fourLetters.globalLevelForLocal(1), 51);
    expect(WordLengthBand.fourLetters.globalLevelForLocal(100), 150);
    expect(WordLengthBand.eightLetters.localLevelForGlobal(500), 40);
    expect(WordLengthBand.tryFromGlobalLevel(276)?.wordLength, 6);
    expect(WordLengthBand.tryFromWordLength(2), isNull);
    expect(
      () => WordLengthBand.threeLetters.globalLevelForLocal(51),
      throwsRangeError,
    );
  });

  test('AppSave mantém progresso e sessões independentes no round-trip', () {
    final original = AppSave(
      modes: <GameMode, ModeProgress>{
        GameMode.withHints: const ModeProgress(
          completedThrough: 12,
          lastOpenedLevel: 13,
          session: GameSession(
            levelNumber: 13,
            submittedGuesses: <String>['crate'],
            draft: 'fl',
          ),
        ),
        GameMode.withoutHints: const ModeProgress(completedThrough: 4),
      },
    );

    final restored = AppSave.fromJson(
      jsonDecode(jsonEncode(original.toJson())),
    );
    expect(restored.progressFor(GameMode.withHints).completedThrough, 12);
    expect(restored.progressFor(GameMode.withHints).session?.draft, 'fl');
    expect(restored.progressFor(GameMode.withoutHints).completedThrough, 4);
  });

  test('save de versão desconhecida volta ao estado inicial', () {
    final restored = AppSave.fromJson(<String, Object?>{
      'schemaVersion': 99,
      'modes': <String, Object?>{},
    });
    expect(restored.progressFor(GameMode.withHints).completedThrough, 0);
    expect(restored.progressFor(GameMode.withoutHints).session, isNull);
  });

  test('sessão malformada é descartada sem perder progresso', () {
    final restored = AppSave.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'modes': <String, Object?>{
        'withHints': <String, Object?>{
          'completedThrough': 7,
          'lastOpenedLevel': 8,
          'session': <String, Object?>{
            'levelNumber': 8,
            'submittedGuesses': <Object?>[42],
            'draft': '',
          },
        },
        'withoutHints': <String, Object?>{},
      },
    });
    expect(restored.progressFor(GameMode.withHints).completedThrough, 7);
    expect(restored.progressFor(GameMode.withHints).session, isNull);
  });

  test('campos numericos fora da faixa sao limitados por modo', () {
    final restored = AppSave.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'modes': <String, Object?>{
        'withHints': <String, Object?>{
          'completedThrough': 900,
          'lastOpenedLevel': -4,
          'session': null,
        },
        'withoutHints': <String, Object?>{
          'completedThrough': -20,
          'lastOpenedLevel': 900,
          'session': null,
        },
      },
    });

    expect(restored.progressFor(GameMode.withHints).completedThrough, 500);
    expect(restored.progressFor(GameMode.withHints).lastOpenedLevel, 1);
    expect(restored.progressFor(GameMode.withoutHints).completedThrough, 0);
    expect(restored.progressFor(GameMode.withoutHints).lastOpenedLevel, 500);
  });

  test('campos invalidos em um modo nao apagam o outro modo valido', () {
    final restored = AppSave.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'modes': <String, Object?>{
        'withHints': <String, Object?>{
          'completedThrough': 'quebrado',
          'lastOpenedLevel': null,
          'session': <String, Object?>{'levelNumber': 700},
        },
        'withoutHints': <String, Object?>{
          'completedThrough': 37,
          'lastOpenedLevel': 38,
          'session': <String, Object?>{
            'levelNumber': 38,
            'submittedGuesses': <String>['crane'],
            'draft': 'st',
          },
        },
      },
    });

    expect(restored.progressFor(GameMode.withHints).completedThrough, 0);
    expect(restored.progressFor(GameMode.withHints).session, isNull);
    expect(restored.progressFor(GameMode.withoutHints).completedThrough, 37);
    expect(restored.progressFor(GameMode.withoutHints).session?.draft, 'st');
  });

  test('sessao com mais de seis tentativas e descartada', () {
    final session = GameSession.tryFromJson(<String, Object?>{
      'levelNumber': 1,
      'submittedGuesses': List<String>.filled(7, 'cat'),
      'draft': '',
    });

    expect(session, isNull);
  });

  test('schema v2 preserva seis progressos, sessões e preferência de som', () {
    final lengths = <WordLengthBand, LengthProgress>{
      for (final band in WordLengthBand.values)
        band: LengthProgress(
          completedCount: band.wordLength - 2,
          lastOpenedLevel: band.firstGlobalLevel + band.wordLength - 2,
          session: GameSession(
            levelNumber: band.firstGlobalLevel + band.wordLength - 2,
            draft: 'a',
          ),
        ),
    };
    final original = AppSave(
      successSoundEnabled: false,
      modes: <GameMode, ModeProgress>{
        GameMode.withHints: ModeProgress(
          lengths: lengths,
          lastSelectedLength: 8,
        ),
      },
    );

    final restored = AppSave.fromJson(
      jsonDecode(jsonEncode(original.toJson())),
    );

    expect(restored.successSoundEnabled, isFalse);
    expect(restored.progressFor(GameMode.withHints).lastSelectedLength, 8);
    for (final band in WordLengthBand.values) {
      final progress = restored
          .progressFor(GameMode.withHints)
          .progressForBand(band);
      expect(progress.completedCount, band.wordLength - 2);
      expect(progress.session?.levelNumber, progress.lastOpenedLevel);
    }
    expect(restored.progressFor(GameMode.withoutHints).totalCompleted, 0);
  });

  test('migração v1 distribui progresso e sessão na faixa correta', () {
    final restored = AppSave.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'modes': <String, Object?>{
        'withHints': <String, Object?>{
          'completedThrough': 175,
          'lastOpenedLevel': 176,
          'session': <String, Object?>{
            'levelNumber': 176,
            'submittedGuesses': <String>['crane'],
            'draft': 'st',
          },
        },
      },
    });
    final progress = restored.progressFor(GameMode.withHints);

    expect(restored.needsMigration, isTrue);
    expect(progress.progressForLength(3).completedCount, 50);
    expect(progress.progressForLength(4).completedCount, 100);
    expect(progress.progressForLength(5).completedCount, 25);
    expect(progress.progressForLength(6).completedCount, 0);
    expect(progress.progressForLength(5).session?.draft, 'st');
    expect(progress.lastSelectedLength, 5);
  });

  test('migração v1 respeita todas as fronteiras de tamanho', () {
    const cases = <int, List<int>>{
      0: <int>[0, 0, 0, 0, 0, 0],
      1: <int>[1, 0, 0, 0, 0, 0],
      50: <int>[50, 0, 0, 0, 0, 0],
      51: <int>[50, 1, 0, 0, 0, 0],
      150: <int>[50, 100, 0, 0, 0, 0],
      151: <int>[50, 100, 1, 0, 0, 0],
      275: <int>[50, 100, 125, 0, 0, 0],
      276: <int>[50, 100, 125, 1, 0, 0],
      400: <int>[50, 100, 125, 125, 0, 0],
      401: <int>[50, 100, 125, 125, 1, 0],
      460: <int>[50, 100, 125, 125, 60, 0],
      461: <int>[50, 100, 125, 125, 60, 1],
      500: <int>[50, 100, 125, 125, 60, 40],
    };

    for (final entry in cases.entries) {
      final restored = AppSave.fromJson(<String, Object?>{
        'schemaVersion': 1,
        'modes': <String, Object?>{
          'withHints': <String, Object?>{
            'completedThrough': entry.key,
            'lastOpenedLevel': entry.key.clamp(1, 500),
            'session': null,
          },
        },
      });
      final progress = restored.progressFor(GameMode.withHints);
      expect(
        <int>[
          for (final band in WordLengthBand.values)
            progress.progressForBand(band).completedCount,
        ],
        entry.value,
        reason: 'completedThrough=${entry.key}',
      );
    }
  });

  test('construtor legado seleciona a categoria da sessão ao serializar', () {
    final restored = AppSave.fromJson(
      jsonDecode(
        jsonEncode(
          AppSave(
            modes: <GameMode, ModeProgress>{
              GameMode.withHints: const ModeProgress(
                completedThrough: 500,
                lastOpenedLevel: 500,
                session: GameSession(
                  levelNumber: 500,
                  submittedGuesses: <String>['elephant'],
                ),
              ),
            },
          ).toJson(),
        ),
      ),
    );

    expect(restored.progressFor(GameMode.withHints).lastSelectedLength, 8);
    expect(
      restored.progressFor(GameMode.withHints).progressForLength(8).session,
      isNotNull,
    );
  });

  test('categoria v2 corrompida não apaga categorias válidas', () {
    final restored = AppSave.fromJson(<String, Object?>{
      'schemaVersion': 2,
      'settings': <String, Object?>{'successSoundEnabled': true},
      'modes': <String, Object?>{
        'withHints': <String, Object?>{
          'lastSelectedLength': 4,
          'lengths': <String, Object?>{
            '3': <String, Object?>{
              'completedCount': 12,
              'lastOpenedLevel': 13,
              'session': null,
            },
            '4': <String, Object?>{
              'completedCount': 'quebrado',
              'lastOpenedLevel': 900,
              'session': <String, Object?>{'levelNumber': 2},
            },
          },
        },
      },
    });
    final progress = restored.progressFor(GameMode.withHints);

    expect(progress.progressForLength(3).completedCount, 12);
    expect(progress.progressForLength(4).completedCount, 0);
    expect(progress.progressForLength(4).lastOpenedLevel, 150);
    expect(progress.progressForLength(4).session, isNull);
  });
}
