import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/catalog_repository.dart';
import '../data/save_repository.dart';
import '../domain/models.dart';
import '../domain/word_evaluator.dart';

enum SubmitStatus { incomplete, notFound, accepted }

typedef _SaveMutation = AppSave Function(AppSave persisted);

class SubmitOutcome {
  const SubmitOutcome._({
    required this.status,
    this.result,
    this.won = false,
    this.lost = false,
  });

  const SubmitOutcome.incomplete() : this._(status: SubmitStatus.incomplete);
  const SubmitOutcome.notFound() : this._(status: SubmitStatus.notFound);
  const SubmitOutcome.accepted({
    required GuessResult result,
    required bool won,
    required bool lost,
  }) : this._(
         status: SubmitStatus.accepted,
         result: result,
         won: won,
         lost: lost,
       );

  final SubmitStatus status;
  final GuessResult? result;
  final bool won;
  final bool lost;
}

class GameStore extends ChangeNotifier {
  GameStore({required this.catalog, required this.saves});

  final CatalogRepository catalog;
  final SaveRepository saves;
  AppSave _save = AppSave();
  final Map<GameMode, int> _modeRevisions = <GameMode, int>{
    for (final mode in GameMode.values) mode: 0,
  };
  int _soundRevision = 0;
  late AppSave _persistedSave;
  Future<void> _persistenceQueue = Future<void>.value();
  bool _initialized = false;

  bool get isInitialized => _initialized;
  AppSave get save => _save;
  bool get successSoundEnabled => _save.successSoundEnabled;

  Future<void> initialize() async {
    await catalog.load();
    _save = await saves.load();
    _persistedSave = _save;
    final changed = await _sanitizeSessions();
    if (changed || _save.needsMigration) {
      _save = _save.copyWith(needsMigration: false);
      final normalizedSave = _save;
      await _enqueuePersistence((_) => normalizedSave);
    }
    _initialized = true;
    notifyListeners();
  }

  ModeProgress progressFor(GameMode mode) => _save.progressFor(mode);

  LengthProgress lengthProgressFor(GameMode mode, int wordLength) =>
      progressFor(mode).progressForLength(wordLength);

  WordLevel level(GameMode mode, int number) => catalog.level(mode, number);

  WordLevel levelForLocal(
    GameMode mode,
    int wordLength,
    int localLevelNumber,
  ) => catalog.levelForLocal(mode, wordLength, localLevelNumber);

  List<WordLevel> levelsFor(GameMode mode) => catalog.levelsFor(mode);

  List<WordLevel> levelsForLength(GameMode mode, int wordLength) {
    final band = _bandForLength(wordLength);
    final levels = levelsFor(mode);
    if (levels.length < band.lastGlobalLevel) return const <WordLevel>[];
    return List<WordLevel>.unmodifiable(
      levels.sublist(band.firstGlobalLevel - 1, band.lastGlobalLevel),
    );
  }

  int globalLevelForLocal(int wordLength, int localLevelNumber) =>
      catalog.globalLevelForLocal(wordLength, localLevelNumber);

  int localLevelNumber(int globalLevelNumber) =>
      catalog.localLevelNumber(globalLevelNumber);

  int nextLevelFor(GameMode mode, int wordLength) {
    final band = _bandForLength(wordLength);
    return lengthProgressFor(mode, wordLength).nextGlobalLevel(band);
  }

  bool isLevelUnlocked(GameMode mode, int globalLevelNumber) {
    final band = _bandForLevel(globalLevelNumber);
    final progress = progressFor(mode).progressForBand(band);
    return _isLevelAccessible(progress, band, globalLevelNumber);
  }

  GameSession? sessionFor(GameMode mode, int levelNumber) {
    final band = WordLengthBand.tryFromGlobalLevel(levelNumber);
    if (band == null) return null;
    final session = progressFor(mode).progressForBand(band).session;
    return session?.levelNumber == levelNumber ? session : null;
  }

  List<GuessResult> evaluatedGuesses(GameMode mode, int levelNumber) {
    final levelData = level(mode, levelNumber);
    final guesses = sessionFor(mode, levelNumber)?.submittedGuesses ?? const [];
    return <GuessResult>[
      for (final guess in guesses)
        WordEvaluator.evaluate(answer: levelData.answer, guess: guess),
    ];
  }

  Map<String, LetterMark> keyboardMarks(GameMode mode, int levelNumber) =>
      WordEvaluator.keyboardMarks(evaluatedGuesses(mode, levelNumber));

  Future<void> selectWordLength(GameMode mode, int wordLength) async {
    _bandForLength(wordLength);
    final progress = progressFor(mode);
    if (progress.lastSelectedLength == wordLength &&
        progress.lengths.isNotEmpty) {
      return;
    }
    await _commitProgress(mode, progress.selectLength(wordLength));
  }

  Future<GameSession> openLevel(GameMode mode, int levelNumber) async {
    final band = _bandForLevel(levelNumber);
    final modeProgress = progressFor(mode);
    final lengthProgress = modeProgress.progressForBand(band);
    _checkLevelAccess(lengthProgress, band, levelNumber);
    final existing = lengthProgress.session;
    final session = existing?.levelNumber == levelNumber
        ? existing!
        : GameSession(levelNumber: levelNumber);
    await _commitProgress(
      mode,
      modeProgress.replaceLength(
        band,
        lengthProgress.copyWith(lastOpenedLevel: levelNumber, session: session),
      ),
    );
    return session;
  }

  void addLetter(GameMode mode, int levelNumber, String letter) {
    final session = sessionFor(mode, levelNumber);
    final levelData = level(mode, levelNumber);
    if (session == null ||
        session.isTerminal(levelData.answer) ||
        session.draft.length >= levelData.wordLength) {
      return;
    }
    _updateSession(mode, session.copyWith(draft: '${session.draft}$letter'));
  }

  void deleteLetter(GameMode mode, int levelNumber) {
    final session = sessionFor(mode, levelNumber);
    if (session == null || session.draft.isEmpty) return;
    _updateSession(
      mode,
      session.copyWith(
        draft: session.draft.substring(0, session.draft.length - 1),
      ),
    );
  }

  Future<SubmitOutcome> submit(GameMode mode, int levelNumber) async {
    final band = _bandForLevel(levelNumber);
    final session = sessionFor(mode, levelNumber);
    final levelData = level(mode, levelNumber);
    if (session == null || session.isTerminal(levelData.answer)) {
      return const SubmitOutcome.incomplete();
    }
    if (session.draft.length != levelData.wordLength) {
      return const SubmitOutcome.incomplete();
    }
    if (!await catalog.isAccepted(session.draft)) {
      return const SubmitOutcome.notFound();
    }

    final guess = session.draft;
    final submitted = <String>[...session.submittedGuesses, guess];
    final nextSession = session.copyWith(
      submittedGuesses: List<String>.unmodifiable(submitted),
      draft: '',
    );
    final modeProgress = progressFor(mode);
    var lengthProgress = modeProgress
        .progressForBand(band)
        .copyWith(session: nextSession);
    final won = guess == levelData.answer;
    if (won &&
        levelNumber == band.firstGlobalLevel + lengthProgress.completedCount) {
      lengthProgress = lengthProgress.copyWith(
        completedCount: lengthProgress.completedCount + 1,
      );
    }
    await _commitProgress(
      mode,
      modeProgress.replaceLength(band, lengthProgress),
    );
    final result = WordEvaluator.evaluate(
      answer: levelData.answer,
      guess: guess,
    );
    return SubmitOutcome.accepted(
      result: result,
      won: won,
      lost: !won && submitted.length == 6,
    );
  }

  Future<void> restartLevel(GameMode mode, int levelNumber) async {
    final band = _bandForLevel(levelNumber);
    final modeProgress = progressFor(mode);
    final lengthProgress = modeProgress.progressForBand(band);
    _checkLevelAccess(lengthProgress, band, levelNumber);
    await _commitProgress(
      mode,
      modeProgress.replaceLength(
        band,
        lengthProgress.copyWith(
          lastOpenedLevel: levelNumber,
          session: GameSession(levelNumber: levelNumber),
        ),
      ),
    );
  }

  Future<void> clearSession(GameMode mode, [int? wordLength]) async {
    final modeProgress = progressFor(mode);
    final band = _bandForLength(wordLength ?? modeProgress.lastSelectedLength);
    final lengthProgress = modeProgress.progressForBand(band);
    await _commitProgress(
      mode,
      modeProgress.replaceLength(
        band,
        lengthProgress.copyWith(clearSession: true),
      ),
    );
  }

  Future<void> setSuccessSoundEnabled(bool enabled) async {
    if (_save.successSoundEnabled == enabled) return;
    final previous = _save.successSoundEnabled;
    final nextSave = _save.copyWith(successSoundEnabled: enabled);
    _save = nextSave;
    final revision = ++_soundRevision;
    notifyListeners();
    try {
      await _enqueuePersistence(
        (persisted) => persisted.copyWith(successSoundEnabled: enabled),
      );
    } on Object {
      if (_soundRevision == revision) {
        _save = _save.copyWith(successSoundEnabled: previous);
        _soundRevision++;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> flush() async {
    await _persistenceQueue;
    await saves.flush();
  }

  void _updateSession(GameMode mode, GameSession session) {
    final band = _bandForLevel(session.levelNumber);
    final modeProgress = progressFor(mode);
    final lengthProgress = modeProgress.progressForBand(band);
    _replaceProgress(
      mode,
      modeProgress.replaceLength(
        band,
        lengthProgress.copyWith(session: session),
      ),
    );
    unawaited(
      _enqueuePersistence((persisted) {
        final persistedMode = persisted.progressFor(mode);
        final persistedLength = persistedMode.progressForBand(band);
        if (persistedLength.session?.levelNumber != session.levelNumber) {
          return persisted;
        }
        return persisted.replace(
          mode,
          persistedMode.replaceLength(
            band,
            persistedLength.copyWith(session: session),
          ),
        );
      }).catchError((Object _) {}),
    );
  }

  Future<void> _commitProgress(GameMode mode, ModeProgress progress) async {
    final previous = progressFor(mode);
    final nextSave = _save.replace(mode, progress);
    _save = nextSave;
    final revision = (_modeRevisions[mode] ?? 0) + 1;
    _modeRevisions[mode] = revision;
    notifyListeners();
    try {
      final changedBands = <WordLengthBand>[
        for (final band in WordLengthBand.values)
          if (!_sameLengthProgress(
            previous.progressForBand(band),
            progress.progressForBand(band),
          ))
            band,
      ];
      final selectionChanged =
          previous.lastSelectedLength != progress.lastSelectedLength;
      await _enqueuePersistence((persisted) {
        var rebased = persisted.progressFor(mode);
        for (final band in changedBands) {
          rebased = rebased.replaceLength(
            band,
            progress.progressForBand(band),
            select: false,
          );
        }
        if (selectionChanged) {
          rebased = rebased.selectLength(progress.lastSelectedLength);
        }
        return persisted.replace(mode, rebased);
      });
    } on Object {
      if (_modeRevisions[mode] == revision) {
        _save = _save.replace(mode, previous);
        _modeRevisions[mode] = revision + 1;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _replaceProgress(GameMode mode, ModeProgress progress) {
    _save = _save.replace(mode, progress);
    _modeRevisions[mode] = (_modeRevisions[mode] ?? 0) + 1;
    notifyListeners();
  }

  Future<void> _enqueuePersistence(_SaveMutation mutation) {
    final operation = _persistenceQueue.then((_) async {
      final candidate = mutation(_persistedSave);
      await saves.save(candidate);
      _persistedSave = candidate;
    });
    _persistenceQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<bool> _sanitizeSessions() async {
    var changed = false;
    for (final mode in GameMode.values) {
      var modeProgress = _save.progressFor(mode);
      for (final band in WordLengthBand.values) {
        final lengthProgress = modeProgress.progressForBand(band);
        final session = lengthProgress.session;
        if (session == null) continue;
        final levelData = catalog.level(mode, session.levelNumber);
        final maxUnlocked = lengthProgress.isComplete(band)
            ? band.lastGlobalLevel
            : band.firstGlobalLevel + lengthProgress.completedCount;
        var valid =
            band.containsGlobalLevel(session.levelNumber) &&
            session.levelNumber <= maxUnlocked &&
            session.draft.length <= levelData.wordLength &&
            session.submittedGuesses.every(
              (guess) => guess.length == levelData.wordLength,
            );
        if (valid) {
          for (final guess in session.submittedGuesses) {
            if (!await catalog.isAccepted(guess)) {
              valid = false;
              break;
            }
          }
        }
        final winningIndex = session.submittedGuesses.indexOf(levelData.answer);
        if (winningIndex >= 0 &&
            winningIndex != session.submittedGuesses.length - 1) {
          valid = false;
        }
        if (session.isTerminal(levelData.answer) && session.draft.isNotEmpty) {
          valid = false;
        }
        if (!valid) {
          modeProgress = modeProgress.replaceLength(
            band,
            lengthProgress.copyWith(clearSession: true),
            select: false,
          );
          changed = true;
        } else if (session.isWon(levelData.answer) &&
            session.levelNumber ==
                band.firstGlobalLevel + lengthProgress.completedCount) {
          modeProgress = modeProgress.replaceLength(
            band,
            lengthProgress.copyWith(
              completedCount: lengthProgress.completedCount + 1,
            ),
            select: false,
          );
          changed = true;
        }
      }
      _save = _save.replace(mode, modeProgress);
    }
    return changed;
  }

  WordLengthBand _bandForLength(int wordLength) {
    final band = WordLengthBand.tryFromWordLength(wordLength);
    if (band == null) {
      throw ArgumentError.value(
        wordLength,
        'wordLength',
        'O tamanho deve estar entre 3 e 8.',
      );
    }
    return band;
  }

  WordLengthBand _bandForLevel(int levelNumber) {
    final band = WordLengthBand.tryFromGlobalLevel(levelNumber);
    if (band == null) {
      throw ArgumentError.value(
        levelNumber,
        'levelNumber',
        'O nível deve estar entre 1 e 500.',
      );
    }
    return band;
  }

  static bool _isLevelAccessible(
    LengthProgress progress,
    WordLengthBand band,
    int levelNumber,
  ) {
    if (!band.containsGlobalLevel(levelNumber)) return false;
    return progress.isComplete(band) ||
        levelNumber <= band.firstGlobalLevel + progress.completedCount;
  }

  static bool _sameLengthProgress(LengthProgress first, LengthProgress second) {
    return first.completedCount == second.completedCount &&
        first.lastOpenedLevel == second.lastOpenedLevel &&
        _sameSession(first.session, second.session);
  }

  static bool _sameSession(GameSession? first, GameSession? second) {
    if (identical(first, second)) return true;
    if (first == null || second == null) return false;
    return first.levelNumber == second.levelNumber &&
        first.draft == second.draft &&
        listEquals(first.submittedGuesses, second.submittedGuesses);
  }

  static void _checkLevelAccess(
    LengthProgress progress,
    WordLengthBand band,
    int levelNumber,
  ) {
    if (!_isLevelAccessible(progress, band, levelNumber)) {
      throw ArgumentError.value(levelNumber, 'levelNumber', 'Nível bloqueado.');
    }
  }
}
