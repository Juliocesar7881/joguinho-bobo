enum GameMode { withHints, withoutHints }

extension GameModeX on GameMode {
  String get id => switch (this) {
    GameMode.withHints => 'withHints',
    GameMode.withoutHints => 'withoutHints',
  };

  String get title => switch (this) {
    GameMode.withHints => 'Com dicas',
    GameMode.withoutHints => 'Sem dicas',
  };

  static GameMode? fromId(Object? value) {
    for (final mode in GameMode.values) {
      if (mode.id == value) return mode;
    }
    return null;
  }
}

/// The canonical level ranges used by both catalogs.
///
/// Level identifiers stay global and stable. The local number shown to the
/// player starts at one inside each band.
enum WordLengthBand {
  threeLetters(wordLength: 3, firstGlobalLevel: 1, levelCount: 50),
  fourLetters(wordLength: 4, firstGlobalLevel: 51, levelCount: 100),
  fiveLetters(wordLength: 5, firstGlobalLevel: 151, levelCount: 125),
  sixLetters(wordLength: 6, firstGlobalLevel: 276, levelCount: 125),
  sevenLetters(wordLength: 7, firstGlobalLevel: 401, levelCount: 60),
  eightLetters(wordLength: 8, firstGlobalLevel: 461, levelCount: 40);

  const WordLengthBand({
    required this.wordLength,
    required this.firstGlobalLevel,
    required this.levelCount,
  });

  final int wordLength;
  final int firstGlobalLevel;
  final int levelCount;

  int get lastGlobalLevel => firstGlobalLevel + levelCount - 1;

  bool containsGlobalLevel(int levelNumber) =>
      levelNumber >= firstGlobalLevel && levelNumber <= lastGlobalLevel;

  int globalLevelForLocal(int localLevelNumber) {
    if (localLevelNumber < 1 || localLevelNumber > levelCount) {
      throw RangeError.range(
        localLevelNumber,
        1,
        levelCount,
        'localLevelNumber',
      );
    }
    return firstGlobalLevel + localLevelNumber - 1;
  }

  int localLevelForGlobal(int globalLevelNumber) {
    if (!containsGlobalLevel(globalLevelNumber)) {
      throw RangeError.range(
        globalLevelNumber,
        firstGlobalLevel,
        lastGlobalLevel,
        'globalLevelNumber',
      );
    }
    return globalLevelNumber - firstGlobalLevel + 1;
  }

  static WordLengthBand? tryFromWordLength(int wordLength) {
    for (final band in values) {
      if (band.wordLength == wordLength) return band;
    }
    return null;
  }

  static WordLengthBand? tryFromGlobalLevel(int globalLevelNumber) {
    for (final band in values) {
      if (band.containsGlobalLevel(globalLevelNumber)) return band;
    }
    return null;
  }
}

enum LetterMark { absent, present, correct }

class WordLevel {
  const WordLevel({
    required this.number,
    required this.answer,
    required this.translation,
    required this.meaning,
    this.hint,
    this.hintEn,
  });

  final int number;
  final String answer;
  final String translation;
  final String meaning;
  final String? hint;
  final String? hintEn;

  int get wordLength => answer.length;

  factory WordLevel.fromJson(Map<String, Object?> json) {
    return WordLevel(
      number: json['number']! as int,
      answer: json['answer']! as String,
      translation: json['translation']! as String,
      meaning: json['meaning']! as String,
      hint: json['hint'] as String?,
      hintEn: json['hintEn'] as String?,
    );
  }
}

class GuessResult {
  const GuessResult({required this.word, required this.marks});

  final String word;
  final List<LetterMark> marks;
}

class GameSession {
  const GameSession({
    required this.levelNumber,
    this.submittedGuesses = const <String>[],
    this.draft = '',
  });

  final int levelNumber;
  final List<String> submittedGuesses;
  final String draft;

  bool isWon(String answer) =>
      submittedGuesses.isNotEmpty && submittedGuesses.last == answer;

  bool isLost(String answer) => !isWon(answer) && submittedGuesses.length >= 6;

  bool isTerminal(String answer) => isWon(answer) || isLost(answer);

  GameSession copyWith({
    int? levelNumber,
    List<String>? submittedGuesses,
    String? draft,
  }) {
    return GameSession(
      levelNumber: levelNumber ?? this.levelNumber,
      submittedGuesses: submittedGuesses ?? this.submittedGuesses,
      draft: draft ?? this.draft,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'levelNumber': levelNumber,
    'submittedGuesses': submittedGuesses,
    'draft': draft,
  };

  static GameSession? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final level = json['levelNumber'];
    final guesses = json['submittedGuesses'];
    final draft = json['draft'];
    if (level is! int || level < 1 || level > 500) return null;
    if (guesses is! List || draft is! String) return null;
    final words = <String>[];
    for (final guess in guesses) {
      if (guess is! String || !RegExp(r'^[a-z]{3,8}$').hasMatch(guess)) {
        return null;
      }
      words.add(guess);
    }
    if (words.length > 6 || !RegExp(r'^[a-z]{0,8}$').hasMatch(draft)) {
      return null;
    }
    return GameSession(
      levelNumber: level,
      submittedGuesses: List<String>.unmodifiable(words),
      draft: draft,
    );
  }
}

class LengthProgress {
  const LengthProgress({
    this.completedCount = 0,
    required this.lastOpenedLevel,
    this.session,
  });

  factory LengthProgress.initial(WordLengthBand band) =>
      LengthProgress(lastOpenedLevel: band.firstGlobalLevel);

  final int completedCount;
  final int lastOpenedLevel;
  final GameSession? session;

  bool isComplete(WordLengthBand band) => completedCount == band.levelCount;

  int nextGlobalLevel(WordLengthBand band) => isComplete(band)
      ? band.lastGlobalLevel
      : band.firstGlobalLevel + completedCount;

  LengthProgress copyWith({
    int? completedCount,
    int? lastOpenedLevel,
    GameSession? session,
    bool clearSession = false,
  }) {
    return LengthProgress(
      completedCount: completedCount ?? this.completedCount,
      lastOpenedLevel: lastOpenedLevel ?? this.lastOpenedLevel,
      session: clearSession ? null : session ?? this.session,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'completedCount': completedCount,
    'lastOpenedLevel': lastOpenedLevel,
    'session': session?.toJson(),
  };

  static LengthProgress fromJson(Object? value, WordLengthBand band) {
    if (value is! Map) return LengthProgress.initial(band);
    final json = Map<String, Object?>.from(value);
    final rawCompleted = json['completedCount'];
    final rawLastOpened = json['lastOpenedLevel'];
    final completed = rawCompleted is int
        ? rawCompleted.clamp(0, band.levelCount)
        : 0;
    final lastOpened = rawLastOpened is int
        ? rawLastOpened.clamp(band.firstGlobalLevel, band.lastGlobalLevel)
        : band.firstGlobalLevel;
    final session = GameSession.tryFromJson(json['session']);
    return LengthProgress(
      completedCount: completed,
      lastOpenedLevel: lastOpened,
      session: session != null && band.containsGlobalLevel(session.levelNumber)
          ? session
          : null,
    );
  }
}

class ModeProgress {
  /// [completedThrough], [lastOpenedLevel] and [session] keep source
  /// compatibility with schema-v1 callers. New code should pass [lengths].
  const ModeProgress({
    this.lengths = const <WordLengthBand, LengthProgress>{},
    this.lastSelectedLength = 3,
    int completedThrough = 0,
    int lastOpenedLevel = 1,
    GameSession? session,
  }) : _legacyCompletedThrough = completedThrough,
       _legacyLastOpenedLevel = lastOpenedLevel,
       _legacySession = session;

  final Map<WordLengthBand, LengthProgress> lengths;
  final int lastSelectedLength;
  final int _legacyCompletedThrough;
  final int _legacyLastOpenedLevel;
  final GameSession? _legacySession;

  LengthProgress progressForLength(int wordLength) {
    final band = WordLengthBand.tryFromWordLength(wordLength);
    if (band == null) {
      throw ArgumentError.value(
        wordLength,
        'wordLength',
        'O tamanho deve estar entre 3 e 8.',
      );
    }
    return progressForBand(band);
  }

  LengthProgress progressForBand(WordLengthBand band) {
    if (lengths.isNotEmpty) {
      return lengths[band] ?? LengthProgress.initial(band);
    }
    return _legacyProgressForBand(band);
  }

  int get totalCompleted => WordLengthBand.values.fold<int>(
    0,
    (total, band) => total + progressForBand(band).completedCount,
  );

  bool get isComplete => totalCompleted == 500;

  /// Compatibility alias. It now represents the aggregate number completed.
  int get completedThrough => totalCompleted;

  int get lastOpenedLevel =>
      progressForLength(_safeSelectedLength).lastOpenedLevel;

  GameSession? get session => progressForLength(_safeSelectedLength).session;

  int get nextLevel {
    final band = WordLengthBand.tryFromWordLength(_safeSelectedLength)!;
    return progressForBand(band).nextGlobalLevel(band);
  }

  int get _safeSelectedLength {
    if (lengths.isEmpty) {
      return (WordLengthBand.tryFromGlobalLevel(
                _legacySession?.levelNumber ?? _legacyLastOpenedLevel,
              ) ??
              WordLengthBand.threeLetters)
          .wordLength;
    }
    return WordLengthBand.tryFromWordLength(lastSelectedLength)?.wordLength ??
        3;
  }

  ModeProgress replaceLength(
    WordLengthBand band,
    LengthProgress progress, {
    bool select = true,
  }) {
    return ModeProgress(
      lengths: <WordLengthBand, LengthProgress>{
        for (final value in WordLengthBand.values)
          value: value == band ? progress : progressForBand(value),
      },
      lastSelectedLength: select ? band.wordLength : _safeSelectedLength,
    );
  }

  ModeProgress selectLength(int wordLength) {
    final band = WordLengthBand.tryFromWordLength(wordLength);
    if (band == null) {
      throw ArgumentError.value(
        wordLength,
        'wordLength',
        'O tamanho deve estar entre 3 e 8.',
      );
    }
    return ModeProgress(
      lengths: <WordLengthBand, LengthProgress>{
        for (final value in WordLengthBand.values)
          value: progressForBand(value),
      },
      lastSelectedLength: wordLength,
    );
  }

  ModeProgress copyWith({
    Map<WordLengthBand, LengthProgress>? lengths,
    int? lastSelectedLength,
    int? completedThrough,
    int? lastOpenedLevel,
    GameSession? session,
    bool clearSession = false,
  }) {
    if (completedThrough != null) {
      return ModeProgress(
        completedThrough: completedThrough,
        lastOpenedLevel: lastOpenedLevel ?? this.lastOpenedLevel,
        session: clearSession ? null : session ?? this.session,
      );
    }

    final selected = WordLengthBand.tryFromWordLength(
      lastSelectedLength ?? _safeSelectedLength,
    )!;
    final base = lengths == null
        ? this
        : ModeProgress(
            lengths: lengths,
            lastSelectedLength: selected.wordLength,
          );
    var selectedProgress = base.progressForBand(selected);
    if (lastOpenedLevel != null || session != null || clearSession) {
      selectedProgress = selectedProgress.copyWith(
        lastOpenedLevel: lastOpenedLevel,
        session: session,
        clearSession: clearSession,
      );
    }
    return base.replaceLength(selected, selectedProgress);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'lastSelectedLength': _safeSelectedLength,
    'lengths': <String, Object?>{
      for (final band in WordLengthBand.values)
        '${band.wordLength}': progressForBand(band).toJson(),
    },
  };

  static ModeProgress fromJson(Object? value) {
    if (value is! Map) return const ModeProgress();
    final json = Map<String, Object?>.from(value);
    final rawLengths = json['lengths'];
    final lengths = <WordLengthBand, LengthProgress>{};
    for (final band in WordLengthBand.values) {
      final raw = rawLengths is Map ? rawLengths['${band.wordLength}'] : null;
      lengths[band] = LengthProgress.fromJson(raw, band);
    }
    final rawSelected = json['lastSelectedLength'];
    final selected =
        rawSelected is int &&
            WordLengthBand.tryFromWordLength(rawSelected) != null
        ? rawSelected
        : 3;
    return ModeProgress(lengths: lengths, lastSelectedLength: selected);
  }

  static ModeProgress fromLegacyJson(Object? value) {
    if (value is! Map) return const ModeProgress();
    final json = Map<String, Object?>.from(value);
    final completed = json['completedThrough'];
    final lastOpened = json['lastOpenedLevel'];
    return ModeProgress(
      completedThrough: completed is int ? completed.clamp(0, 500) : 0,
      lastOpenedLevel: lastOpened is int ? lastOpened.clamp(1, 500) : 1,
      session: GameSession.tryFromJson(json['session']),
    )._normalized();
  }

  ModeProgress _normalized() => ModeProgress(
    lengths: <WordLengthBand, LengthProgress>{
      for (final band in WordLengthBand.values)
        band: _legacyProgressForBand(band),
    },
    lastSelectedLength:
        (WordLengthBand.tryFromGlobalLevel(
                  _legacySession?.levelNumber ?? _legacyLastOpenedLevel,
                ) ??
                WordLengthBand.threeLetters)
            .wordLength,
  );

  LengthProgress _legacyProgressForBand(WordLengthBand band) {
    final safeCompleted = _legacyCompletedThrough.clamp(0, 500);
    final completedCount = (safeCompleted - band.firstGlobalLevel + 1).clamp(
      0,
      band.levelCount,
    );
    final session =
        _legacySession != null &&
            band.containsGlobalLevel(_legacySession.levelNumber)
        ? _legacySession
        : null;
    final lastOpened = band.containsGlobalLevel(_legacyLastOpenedLevel)
        ? _legacyLastOpenedLevel
        : session?.levelNumber ?? band.firstGlobalLevel;
    return LengthProgress(
      completedCount: completedCount,
      lastOpenedLevel: lastOpened,
      session: session,
    );
  }
}

class AppSave {
  AppSave({
    Map<GameMode, ModeProgress>? modes,
    this.successSoundEnabled = true,
    this.needsMigration = false,
  }) : modes = Map<GameMode, ModeProgress>.unmodifiable(
         <GameMode, ModeProgress>{
           for (final mode in GameMode.values)
             mode: modes?[mode] ?? const ModeProgress(),
         },
       );

  static const int schemaVersion = 2;
  final Map<GameMode, ModeProgress> modes;
  final bool successSoundEnabled;

  /// True only for a value decoded from schema v1 and not yet rewritten.
  final bool needsMigration;

  ModeProgress progressFor(GameMode mode) =>
      modes[mode] ?? const ModeProgress();

  AppSave replace(GameMode mode, ModeProgress progress) {
    return AppSave(
      modes: <GameMode, ModeProgress>{...modes, mode: progress},
      successSoundEnabled: successSoundEnabled,
      needsMigration: needsMigration,
    );
  }

  AppSave copyWith({
    Map<GameMode, ModeProgress>? modes,
    bool? successSoundEnabled,
    bool? needsMigration,
  }) {
    return AppSave(
      modes: modes ?? this.modes,
      successSoundEnabled: successSoundEnabled ?? this.successSoundEnabled,
      needsMigration: needsMigration ?? this.needsMigration,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'settings': <String, Object?>{'successSoundEnabled': successSoundEnabled},
    'modes': <String, Object?>{
      for (final entry in modes.entries) entry.key.id: entry.value.toJson(),
    },
  };

  static AppSave fromJson(Object? value) {
    if (value is! Map) return AppSave();
    final json = Map<String, Object?>.from(value);
    final version = json['schemaVersion'];
    final rawModes = json['modes'];
    if (rawModes is! Map) return AppSave();
    final modes = Map<String, Object?>.from(rawModes);

    if (version == 1) {
      return AppSave(
        modes: <GameMode, ModeProgress>{
          for (final mode in GameMode.values)
            mode: ModeProgress.fromLegacyJson(modes[mode.id]),
        },
        needsMigration: true,
      );
    }
    if (version != schemaVersion) return AppSave();

    final rawSettings = json['settings'];
    final settings = rawSettings is Map
        ? Map<String, Object?>.from(rawSettings)
        : const <String, Object?>{};
    final rawSound = settings['successSoundEnabled'];
    return AppSave(
      modes: <GameMode, ModeProgress>{
        for (final mode in GameMode.values)
          mode: ModeProgress.fromJson(modes[mode.id]),
      },
      successSoundEnabled: rawSound is bool ? rawSound : true,
    );
  }
}
