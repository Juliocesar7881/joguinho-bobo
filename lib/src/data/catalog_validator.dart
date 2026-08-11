import 'dart:convert';

import '../domain/models.dart';
import 'sha256.dart';

class CatalogValidationResult {
  const CatalogValidationResult(this.errors);

  final List<String> errors;
  bool get isValid => errors.isEmpty;

  void throwIfInvalid() {
    if (!isValid) throw CatalogException(errors.join('\n'));
  }
}

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract final class CatalogValidator {
  static const _catalogRevision =
      'lexinexo-1.0.0-scowl-rel-2026.02.25-bilingual-hints';

  static CatalogValidationResult validateLevelDocument({
    required Map<String, Object?> json,
    required GameMode mode,
  }) {
    final errors = <String>[];
    final answers = <String>[];
    _validateLevelFile(
      json: json,
      mode: mode,
      accepted: const <int, Set<String>>{},
      requireAccepted: false,
      blocked: const <String>{},
      allAnswers: answers,
      meanings: <String>{},
      hints: <String>{},
      englishHints: <String>{},
      errors: errors,
    );
    if (answers.toSet().length != answers.length) {
      errors.add('Há respostas repetidas em ${mode.id}.');
    }
    return CatalogValidationResult(List<String>.unmodifiable(errors));
  }

  static CatalogValidationResult validateAcceptedBucket({
    required Map<String, Object?> json,
    required int length,
  }) {
    final errors = <String>[];
    _validateAcceptedWords(json, length, errors);
    return CatalogValidationResult(List<String>.unmodifiable(errors));
  }

  static CatalogValidationResult validate({
    required Map<String, Object?> withHints,
    required Map<String, Object?> withoutHints,
    required Map<int, Map<String, Object?>> acceptedBuckets,
    required Map<String, Object?> editorialReview,
    required Map<String, Object?> denylist,
  }) {
    final errors = <String>[];
    final accepted = <int, Set<String>>{};

    for (var length = 3; length <= 8; length++) {
      final bucket = acceptedBuckets[length];
      if (bucket == null) {
        errors.add('Dicionário de $length letras ausente.');
        continue;
      }
      accepted[length] = _validateAcceptedWords(bucket, length, errors);
    }

    final blocked = _stringSet(denylist['answers'], 'denylist.answers', errors);
    _expectKeys(
      denylist,
      const <String>{'schemaVersion', 'answers'},
      'denylist',
      errors,
    );
    if (denylist['schemaVersion'] != 1) {
      errors.add('schemaVersion inválido na denylist.');
    }

    final allAnswers = <String>[];
    final meanings = <String>{};
    final hints = <String>{};
    final englishHints = <String>{};
    _validateLevelFile(
      json: withHints,
      mode: GameMode.withHints,
      accepted: accepted,
      requireAccepted: true,
      blocked: blocked,
      allAnswers: allAnswers,
      meanings: meanings,
      hints: hints,
      englishHints: englishHints,
      errors: errors,
    );
    _validateLevelFile(
      json: withoutHints,
      mode: GameMode.withoutHints,
      accepted: accepted,
      requireAccepted: true,
      blocked: blocked,
      allAnswers: allAnswers,
      meanings: meanings,
      hints: hints,
      englishHints: englishHints,
      errors: errors,
    );

    if (allAnswers.toSet().length != allAnswers.length) {
      errors.add('Há respostas repetidas dentro ou entre os modos.');
    }
    _validateEditorialReview(
      review: editorialReview,
      withHints: withHints,
      withoutHints: withoutHints,
      errors: errors,
    );

    return CatalogValidationResult(List<String>.unmodifiable(errors));
  }

  static void _validateLevelFile({
    required Map<String, Object?> json,
    required GameMode mode,
    required Map<int, Set<String>> accepted,
    required bool requireAccepted,
    required Set<String> blocked,
    required List<String> allAnswers,
    required Set<String> meanings,
    required Set<String> hints,
    required Set<String> englishHints,
    required List<String> errors,
  }) {
    final source = mode.id;
    _expectKeys(
      json,
      const <String>{'schemaVersion', 'mode', 'levels'},
      source,
      errors,
    );
    if (json['schemaVersion'] != 2 || json['mode'] != mode.id) {
      errors.add('Cabeçalho inválido em $source.');
    }
    final rawLevels = json['levels'];
    if (rawLevels is! List || rawLevels.length != 500) {
      errors.add('$source deve conter exatamente 500 níveis.');
      return;
    }
    for (var index = 0; index < rawLevels.length; index++) {
      final raw = rawLevels[index];
      if (raw is! Map) {
        errors.add('$source nível ${index + 1} não é objeto.');
        continue;
      }
      final item = Map<String, Object?>.from(raw);
      final allowed = mode == GameMode.withHints
          ? const <String>{
              'number',
              'answer',
              'translation',
              'meaning',
              'hint',
              'hintEn',
            }
          : const <String>{'number', 'answer', 'translation', 'meaning'};
      _expectKeys(item, allowed, '$source nível ${index + 1}', errors);
      final number = item['number'];
      final answer = item['answer'];
      final translation = item['translation'];
      final meaning = item['meaning'];
      final hint = item['hint'];
      final hintEn = item['hintEn'];
      if (number != index + 1) {
        errors.add('$source tem numeração inválida no índice $index.');
      }
      if (answer is! String || !RegExp(r'^[a-z]{3,8}$').hasMatch(answer)) {
        errors.add('$source nível ${index + 1} tem resposta inválida.');
        continue;
      }
      final expectedLength = _expectedLength(index + 1);
      if (answer.length != expectedLength) {
        errors.add(
          '$source nível ${index + 1}: esperado $expectedLength letras, '
          'recebido ${answer.length}.',
        );
      }
      if (requireAccepted &&
          !(accepted[answer.length]?.contains(answer) ?? false)) {
        errors.add('$source nível ${index + 1}: $answer fora do dicionário.');
      }
      if (blocked.contains(answer)) {
        errors.add('$source nível ${index + 1}: resposta bloqueada $answer.');
      }
      allAnswers.add(answer);

      if (!_validText(translation, 1, 60)) {
        errors.add('$source nível ${index + 1}: tradução inválida.');
      }
      if (!_validText(meaning, 20, 140)) {
        errors.add('$source nível ${index + 1}: significado inválido.');
      } else {
        final meaningText = (meaning! as String).trim();
        if (_looksTruncated(meaningText)) {
          errors.add('$source nível ${index + 1}: significado truncado.');
        }
        if (!meanings.add(meaningText.toLowerCase())) {
          errors.add('$source nível ${index + 1}: significado repetido.');
        }
      }
      if (mode == GameMode.withHints) {
        if (!_validText(hint, 15, 100)) {
          errors.add('$source nível ${index + 1}: dica inválida.');
        } else {
          final hintText = (hint! as String).trim().toLowerCase();
          if (!hints.add(hintText)) {
            errors.add('$source nível ${index + 1}: dica repetida.');
          }
          if (_looksTruncated(hintText)) {
            errors.add('$source nível ${index + 1}: dica truncada.');
          }
          if (_usesGenericHintTemplate(hintText)) {
            errors.add(
              '$source nível ${index + 1}: dica usa família de template repetitivo.',
            );
          }
          if (meaning is String && _fold(hintText) == _fold(meaning.trim())) {
            errors.add(
              '$source nível ${index + 1}: dica repete o significado.',
            );
          }
          if (RegExp(
            '(^|[^a-z])${RegExp.escape(answer)}([^a-z]|\$)',
          ).hasMatch(hintText)) {
            errors.add('$source nível ${index + 1}: dica revela a resposta.');
          }
          if (translation is String) {
            final foldedHint = _fold(hintText);
            final foldedTranslation = _fold(translation.trim());
            if (foldedTranslation.length >= 3 &&
                RegExp(
                  '(^|[^a-z])${RegExp.escape(foldedTranslation)}([^a-z]|\$)',
                ).hasMatch(foldedHint)) {
              errors.add('$source nível ${index + 1}: dica revela a tradução.');
            }
          }
        }
        if (!_validText(hintEn, 15, 120)) {
          errors.add('$source nível ${index + 1}: dica inglesa inválida.');
        } else {
          final originalHintEn = (hintEn! as String).trim();
          final hintEnText = originalHintEn.toLowerCase();
          if (!englishHints.add(hintEnText)) {
            errors.add('$source nível ${index + 1}: dica inglesa repetida.');
          }
          if (_looksTruncated(hintEnText)) {
            errors.add('$source nível ${index + 1}: dica inglesa truncada.');
          }
          if (_usesGenericHintTemplate(hintEnText)) {
            errors.add(
              '$source nível ${index + 1}: dica inglesa usa família de template repetitivo.',
            );
          }
          if (!RegExp(r'^[A-Z]').hasMatch(originalHintEn) ||
              !RegExp(r'[.!?]$').hasMatch(originalHintEn)) {
            errors.add(
              '$source nível ${index + 1}: dica inglesa não é uma frase completa.',
            );
          }
          if (RegExp(
            '(^|[^a-z])${RegExp.escape(answer)}([^a-z]|\$)',
          ).hasMatch(hintEnText)) {
            errors.add(
              '$source nível ${index + 1}: dica inglesa revela a resposta.',
            );
          }
        }
      } else if (item.containsKey('hint') || item.containsKey('hintEn')) {
        errors.add('$source nível ${index + 1}: dica não permitida.');
      }
    }
  }

  static int _expectedLength(int level) {
    if (level <= 50) return 3;
    if (level <= 150) return 4;
    if (level <= 275) return 5;
    if (level <= 400) return 6;
    if (level <= 460) return 7;
    return 8;
  }

  static void _validateEditorialReview({
    required Map<String, Object?> review,
    required Map<String, Object?> withHints,
    required Map<String, Object?> withoutHints,
    required List<String> errors,
  }) {
    _expectKeys(
      review,
      const <String>{
        'schemaVersion',
        'catalogRevision',
        'canonicalization',
        'humanReview',
        'passes',
        'records',
      },
      'editorialReview',
      errors,
    );
    if (review['schemaVersion'] != 2) {
      errors.add('schemaVersion inválido no manifesto editorial.');
    }
    if (review['catalogRevision'] != _catalogRevision ||
        !_validText(review['canonicalization'], 20, 240)) {
      errors.add('Metadados do manifesto editorial estão incompletos.');
    }
    if (review['humanReview'] != false) {
      errors.add('O manifesto deve declarar honestamente humanReview=false.');
    }

    final rawPasses = review['passes'];
    final passIds = <String>[];
    final roles = <String>[];
    if (rawPasses is! List || rawPasses.length != 2) {
      errors.add(
        'O manifesto editorial deve registrar exatamente dois passes.',
      );
    } else {
      for (var index = 0; index < rawPasses.length; index++) {
        final raw = rawPasses[index];
        if (raw is! Map) {
          errors.add('Passe editorial $index inválido.');
          continue;
        }
        final pass = Map<String, Object?>.from(raw);
        _expectKeys(
          pass,
          const <String>{'id', 'role', 'agent', 'completedOn', 'method'},
          'editorialReview.passes[$index]',
          errors,
        );
        final id = pass['id'];
        final role = pass['role'];
        if (id is String && id.isNotEmpty) passIds.add(id);
        if (role is String && role.isNotEmpty) roles.add(role);
        if (!_validText(pass['agent'], 3, 80) ||
            !_validText(pass['method'], 20, 300) ||
            pass['completedOn'] is! String ||
            !RegExp(
              r'^\d{4}-\d{2}-\d{2}$',
            ).hasMatch(pass['completedOn']! as String)) {
          errors.add('Passe editorial $index possui identificação incompleta.');
        }
      }
    }
    if (passIds.length != 2 || passIds.toSet().length != 2) {
      errors.add('Os dois passes editoriais devem ter IDs distintos.');
    }
    if (!roles.contains('authoring') ||
        !roles.contains('procedurallyIndependentReview')) {
      errors.add('Papéis dos dois passes editoriais estão incompletos.');
    }

    final expected = <({String mode, Map<String, Object?> level})>[];
    void addLevels(Map<String, Object?> document, String mode) {
      final values = document['levels'];
      if (values is! List) return;
      for (final value in values) {
        if (value is Map) {
          expected.add((mode: mode, level: Map<String, Object?>.from(value)));
        }
      }
    }

    addLevels(withHints, GameMode.withHints.id);
    addLevels(withoutHints, GameMode.withoutHints.id);
    final rawRecords = review['records'];
    if (rawRecords is! List || rawRecords.length != 1000) {
      errors.add('O manifesto editorial deve aprovar 1.000 registros.');
      return;
    }
    if (expected.length != rawRecords.length) return;

    for (var index = 0; index < rawRecords.length; index++) {
      final raw = rawRecords[index];
      if (raw is! Map) {
        errors.add('Aprovação editorial inválida no índice $index.');
        continue;
      }
      final record = Map<String, Object?>.from(raw);
      _expectKeys(
        record,
        const <String>{
          'mode',
          'number',
          'answer',
          'contentSha256',
          'approvals',
        },
        'editorialReview.records[$index]',
        errors,
      );
      final target = expected[index];
      if (record['mode'] != target.mode ||
          record['number'] != target.level['number'] ||
          record['answer'] != target.level['answer']) {
        errors.add('Ordem/aprovação editorial diverge no índice $index.');
        continue;
      }
      final canonical = <String, Object?>{
        'mode': target.mode,
        'number': target.level['number'],
        'answer': target.level['answer'],
        'translation': target.level['translation'],
        'meaning': target.level['meaning'],
        if (target.mode == GameMode.withHints.id) 'hint': target.level['hint'],
        if (target.mode == GameMode.withHints.id)
          'hintEn': target.level['hintEn'],
      };
      final expectedHash = sha256Hex(utf8.encode(jsonEncode(canonical)));
      if (record['contentSha256'] != expectedHash) {
        errors.add('Hash editorial desatualizado no índice $index.');
      }
      final approvals = record['approvals'];
      if (approvals is! Map) {
        errors.add('Aprovações editoriais ausentes no índice $index.');
        continue;
      }
      final approvalMap = Map<String, Object?>.from(approvals);
      if (approvalMap.keys.toSet().length != passIds.length ||
          !approvalMap.keys.toSet().containsAll(passIds) ||
          approvalMap.values.any((value) => value != true)) {
        errors.add('Registro $index não possui as duas aprovações editoriais.');
      }
    }
  }

  static bool _looksTruncated(String value) =>
      value.contains('…') ||
      value.contains('...') ||
      RegExp(r'\betc\.?$', caseSensitive: false).hasMatch(value.trim());

  static bool _usesGenericHintTemplate(String value) {
    final folded = _fold(value.trim());
    const prefixes = <String>[
      'pense em algo ligado a:',
      'associe a palavra a:',
      'a ideia central e:',
      'pense nesta acao:',
      'a acao procurada envolve:',
      'associe o verbo a:',
      'pense nesta caracteristica:',
      'a palavra descreve algo:',
      'procure uma qualidade ligada a:',
      'neste contexto,',
      'no uso comum,',
      'think of something related to',
      'associate the word with',
      'the central idea is',
      'in this context,',
      'in common use,',
    ];
    return prefixes.any(folded.startsWith);
  }

  static Set<String> _validateAcceptedWords(
    Map<String, Object?> bucket,
    int length,
    List<String> errors,
  ) {
    _expectKeys(
      bucket,
      const <String>{'schemaVersion', 'length', 'words'},
      'accepted_words_$length',
      errors,
    );
    if (bucket['schemaVersion'] != 1 || bucket['length'] != length) {
      errors.add('Cabeçalho inválido no dicionário de $length letras.');
    }
    final rawWords = bucket['words'];
    if (rawWords is! List) {
      errors.add('Campo words inválido no dicionário de $length letras.');
      return const <String>{};
    }
    final words = <String>[];
    for (final value in rawWords) {
      if (value is! String ||
          value.length != length ||
          !RegExp(r'^[a-z]+$').hasMatch(value)) {
        errors.add('Palavra inválida no dicionário de $length letras: $value');
        continue;
      }
      words.add(value);
    }
    for (var index = 1; index < words.length; index++) {
      if (words[index - 1].compareTo(words[index]) >= 0) {
        errors.add(
          'Dicionário de $length letras não está estritamente ordenado em '
          '${words[index - 1]}/${words[index]}.',
        );
        break;
      }
    }
    return words.toSet();
  }

  static bool _validText(Object? value, int min, int max) {
    if (value is! String || value != value.trim()) return false;
    return value.length >= min && value.length <= max && !value.contains('\n');
  }

  static List<String> _stringList(
    Object? value,
    String label,
    List<String> errors,
  ) {
    if (value is! List || value.any((item) => item is! String)) {
      errors.add('$label deve ser uma lista de strings.');
      return const <String>[];
    }
    return value.cast<String>();
  }

  static Set<String> _stringSet(
    Object? value,
    String label,
    List<String> errors,
  ) => _stringList(value, label, errors).toSet();

  static void _expectKeys(
    Map<String, Object?> value,
    Set<String> expected,
    String label,
    List<String> errors,
  ) {
    final actual = value.keys.toSet();
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      errors.add('$label possui campos ausentes ou desconhecidos: $actual.');
    }
  }

  static String _fold(String value) {
    const accents = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    var result = value.toLowerCase();
    accents.forEach((key, replacement) {
      result = result.replaceAll(key, replacement);
    });
    return result;
  }
}
