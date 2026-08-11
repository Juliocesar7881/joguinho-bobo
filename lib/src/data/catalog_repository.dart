import 'dart:convert';

import 'package:flutter/services.dart';

import 'catalog_validator.dart' show CatalogValidator;
import '../domain/models.dart';

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;

  @override
  String toString() => 'CatalogException: $message';
}

class CatalogRepository {
  CatalogRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<GameMode, List<WordLevel>> _levels = {};
  int? _acceptedLength;
  List<String> _acceptedWords = const [];

  Future<void> load() async {
    final results = await Future.wait(<Future<List<WordLevel>>>[
      _loadLevels(GameMode.withHints, 'assets/data/levels_with_hints.json'),
      _loadLevels(
        GameMode.withoutHints,
        'assets/data/levels_without_hints.json',
      ),
    ]);
    _levels[GameMode.withHints] = results[0];
    _levels[GameMode.withoutHints] = results[1];
  }

  WordLevel level(GameMode mode, int number) {
    final levels = _levels[mode];
    if (levels == null || number < 1 || number > levels.length) {
      throw CatalogException('Nível $number indisponível em ${mode.id}.');
    }
    return levels[number - 1];
  }

  WordLengthBand bandForLevel(int globalLevelNumber) {
    final band = WordLengthBand.tryFromGlobalLevel(globalLevelNumber);
    if (band == null) {
      throw CatalogException('Nível $globalLevelNumber fora do catálogo.');
    }
    return band;
  }

  int globalLevelForLocal(int wordLength, int localLevelNumber) {
    final band = WordLengthBand.tryFromWordLength(wordLength);
    if (band == null) {
      throw CatalogException('Tamanho de palavra inválido: $wordLength.');
    }
    try {
      return band.globalLevelForLocal(localLevelNumber);
    } on RangeError {
      throw CatalogException(
        'Nível local $localLevelNumber indisponível para $wordLength letras.',
      );
    }
  }

  int localLevelNumber(int globalLevelNumber) {
    final band = bandForLevel(globalLevelNumber);
    return band.localLevelForGlobal(globalLevelNumber);
  }

  WordLevel levelForLocal(
    GameMode mode,
    int wordLength,
    int localLevelNumber,
  ) => level(mode, globalLevelForLocal(wordLength, localLevelNumber));

  List<WordLevel> levelsFor(GameMode mode) =>
      List<WordLevel>.unmodifiable(_levels[mode] ?? const <WordLevel>[]);

  List<WordLevel> levelsForLength(GameMode mode, int wordLength) {
    final band = WordLengthBand.tryFromWordLength(wordLength);
    if (band == null) {
      throw CatalogException('Tamanho de palavra inválido: $wordLength.');
    }
    final levels = _levels[mode];
    if (levels == null || levels.length < band.lastGlobalLevel) {
      throw CatalogException('Catálogo ${mode.id} ainda não foi carregado.');
    }
    return List<WordLevel>.unmodifiable(
      levels.sublist(band.firstGlobalLevel - 1, band.lastGlobalLevel),
    );
  }

  Future<bool> isAccepted(String word) async {
    await _ensureAcceptedLength(word.length);
    return _binaryContains(_acceptedWords, word);
  }

  Future<List<WordLevel>> _loadLevels(GameMode mode, String path) async {
    final raw = await _bundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw CatalogException('Estrutura inválida em $path.');
    }
    final document = Map<String, Object?>.from(decoded);
    final validation = CatalogValidator.validateLevelDocument(
      json: document,
      mode: mode,
    );
    if (!validation.isValid) {
      throw CatalogException('$path: ${validation.errors.join(' ')}');
    }
    final rawLevels = document['levels']! as List;
    final levels = <WordLevel>[];
    for (var index = 0; index < rawLevels.length; index++) {
      final item = rawLevels[index];
      if (item is! Map) {
        throw CatalogException('Nível ${index + 1} inválido em $path.');
      }
      final level = WordLevel.fromJson(Map<String, Object?>.from(item));
      levels.add(level);
    }
    return List<WordLevel>.unmodifiable(levels);
  }

  Future<void> _ensureAcceptedLength(int length) async {
    if (_acceptedLength == length) return;
    if (length < 3 || length > 8) {
      _acceptedLength = length;
      _acceptedWords = const <String>[];
      return;
    }
    final path = 'assets/data/accepted_words_$length.json';
    final decoded = jsonDecode(await _bundle.loadString(path));
    if (decoded is! Map) {
      throw CatalogException('Estrutura inválida em $path.');
    }
    final document = Map<String, Object?>.from(decoded);
    final validation = CatalogValidator.validateAcceptedBucket(
      json: document,
      length: length,
    );
    if (!validation.isValid) {
      throw CatalogException('$path: ${validation.errors.join(' ')}');
    }
    final words = (document['words']! as List).cast<String>();
    _acceptedLength = length;
    _acceptedWords = List<String>.unmodifiable(words);
  }

  static bool _binaryContains(List<String> sortedWords, String target) {
    var low = 0;
    var high = sortedWords.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      final comparison = sortedWords[middle].compareTo(target);
      if (comparison == 0) return true;
      if (comparison < 0) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return false;
  }
}
