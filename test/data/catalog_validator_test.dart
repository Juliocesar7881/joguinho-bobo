import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/data/catalog_validator.dart';
import 'package:lexinexo/src/domain/models.dart';

void main() {
  test('fixture sintetica completa e valida', () {
    final fixture = _CatalogFixture.valid();

    expect(fixture.validate().errors, isEmpty);
  });

  _invalidCase(
    'falha com quantidade incorreta',
    (fixture) => _levels(fixture.withHints).removeLast(),
    'exatamente 500',
  );
  _invalidCase(
    'falha com numeracao incorreta',
    (fixture) => _level(fixture.withHints, 0)['number'] = 7,
    'numeração inválida',
  );
  _invalidCase('falha com resposta duplicada entre modos', (fixture) {
    _level(fixture.withoutHints, 0)['answer'] = _level(
      fixture.withHints,
      0,
    )['answer'];
  }, 'respostas repetidas');
  _invalidCase(
    'falha com caracteres invalidos na resposta',
    (fixture) => _level(fixture.withHints, 0)['answer'] = 'c4t',
    'resposta inválida',
  );
  _invalidCase(
    'falha com comprimento fora da faixa do nivel',
    (fixture) => _level(fixture.withHints, 0)['answer'] = 'aaaa',
    'esperado 3 letras',
  );
  _invalidCase('falha quando resposta nao esta no dicionario', (fixture) {
    final answer = _level(fixture.withHints, 0)['answer'];
    _words(fixture.acceptedBuckets[3]!).remove(answer);
  }, 'fora do dicionário');
  _invalidCase(
    'falha com traducao vazia',
    (fixture) => _level(fixture.withHints, 0)['translation'] = '',
    'tradução inválida',
  );
  _invalidCase(
    'falha com significado vazio',
    (fixture) => _level(fixture.withHints, 0)['meaning'] = '',
    'significado inválido',
  );
  _invalidCase(
    'falha quando dica obrigatoria esta ausente',
    (fixture) => _level(fixture.withHints, 0).remove('hint'),
    'dica inválida',
  );
  _invalidCase(
    'falha quando dica inglesa obrigatoria esta ausente',
    (fixture) => _level(fixture.withHints, 0).remove('hintEn'),
    'dica inglesa inválida',
  );
  _invalidCase(
    'falha quando dica aparece no modo sem dicas',
    (fixture) => _level(fixture.withoutHints, 0)['hint'] =
        'Pista que nao deveria existir.',
    'dica não permitida',
  );
  _invalidCase(
    'falha quando dica inglesa aparece no modo sem dicas',
    (fixture) => _level(fixture.withoutHints, 0)['hintEn'] =
        'This clue should not exist in this mode.',
    'dica não permitida',
  );
  _invalidCase('falha quando dica revela a resposta', (fixture) {
    final item = _level(fixture.withHints, 0);
    item['hint'] =
        'Contexto detalhado para a palavra ${item['answer']} em uso.';
  }, 'dica revela a resposta');
  _invalidCase('falha quando dica revela a traducao', (fixture) {
    final item = _level(fixture.withHints, 0);
    item['translation'] = 'conceito';
    item['hint'] = 'Pista ligada ao conceito em uma situacao cotidiana.';
  }, 'dica revela a tradução');
  _invalidCase('falha com significado duplicado', (fixture) {
    _level(fixture.withHints, 1)['meaning'] = _level(
      fixture.withHints,
      0,
    )['meaning'];
  }, 'significado repetido');
  _invalidCase('falha com dica duplicada', (fixture) {
    _level(fixture.withHints, 1)['hint'] = _level(fixture.withHints, 0)['hint'];
  }, 'dica repetida');
  _invalidCase('falha com dica inglesa duplicada', (fixture) {
    _level(fixture.withHints, 1)['hintEn'] = _level(
      fixture.withHints,
      0,
    )['hintEn'];
  }, 'dica inglesa repetida');
  _invalidCase(
    'falha quando dica inglesa revela a resposta',
    (fixture) {
      final item = _level(fixture.withHints, 0);
      item['hintEn'] =
          'A complete clue that explicitly says ${item['answer']} here.';
    },
    'dica inglesa revela a resposta',
  );
  _invalidCase('falha quando resposta pertence a denylist', (fixture) {
    final blocked = fixture.denylist['answers']! as List<Object?>;
    blocked.add(_level(fixture.withHints, 0)['answer']);
  }, 'resposta bloqueada');
  _invalidCase(
    'falha com campo JSON desconhecido',
    (fixture) => _level(fixture.withHints, 0)['extra'] = true,
    'campos ausentes ou desconhecidos',
  );
  _invalidCase('falha com palavra duplicada no dicionario', (fixture) {
    final words = _words(fixture.acceptedBuckets[3]!);
    words.insert(1, words.first);
  }, 'não está estritamente ordenado');
  _invalidCase('falha com dicionario desordenado', (fixture) {
    final words = _words(fixture.acceptedBuckets[3]!);
    final first = words[0];
    words[0] = words[1];
    words[1] = first;
  }, 'não está estritamente ordenado');
  _invalidCase(
    'falha com schemaVersion incompatvel',
    (fixture) => fixture.withHints['schemaVersion'] = 1,
    'Cabeçalho inválido',
  );
  _invalidCase('falha quando registro nao foi aprovado', (fixture) {
    final records = fixture.editorialReview['records']! as List<Object?>;
    final record = records.first! as Map<String, Object?>;
    final approvals = record['approvals']! as Map<String, Object?>;
    approvals['fixture-review'] = false;
  }, 'duas aprovações editoriais');
  _invalidCase(
    'falha com hash editorial desatualizado',
    (fixture) => _level(fixture.withHints, 0)['meaning'] =
        'Definicao alterada depois da aprovacao editorial registrada.',
    'Hash editorial desatualizado',
  );
  _invalidCase(
    'falha com significado truncado',
    (fixture) => _level(fixture.withHints, 0)['meaning'] =
        'Definicao interrompida antes de concluir a ideia…',
    'significado truncado',
  );
  _invalidCase(
    'falha com dica truncada',
    (fixture) => _level(fixture.withHints, 0)['hint'] =
        'Contexto interrompido antes de concluir a pista…',
    'dica truncada',
  );
  _invalidCase(
    'falha com dica inglesa truncada',
    (fixture) => _level(fixture.withHints, 0)['hintEn'] =
        'This English clue stops before completing its thought...',
    'dica inglesa truncada',
  );
  _invalidCase(
    'falha com template repetitivo em ingles',
    (fixture) => _level(fixture.withHints, 0)['hintEn'] =
        'Think of something related to a routine situation.',
    'dica inglesa usa família de template repetitivo',
  );
  _invalidCase(
    'falha com familia de template repetitivo',
    (fixture) => _level(fixture.withHints, 0)['hint'] =
        'Pense em algo ligado a: contexto cotidiano sem revelar o termo.',
    'família de template repetitivo',
  );
  _invalidCase('falha quando dica repete significado', (fixture) {
    final item = _level(fixture.withHints, 0);
    item['hint'] = item['meaning'];
  }, 'dica repete o significado');
  _invalidCase(
    'falha com schema editorial anterior',
    (fixture) => fixture.editorialReview['schemaVersion'] = 1,
    'schemaVersion inválido no manifesto editorial',
  );
  _invalidCase(
    'falha com revisao editorial incompatvel',
    (fixture) =>
        fixture.editorialReview['catalogRevision'] = 'fixture-old-revision',
    'Metadados do manifesto editorial estão incompletos',
  );
  _invalidCase(
    'falha quando revisao humana e alegada incorretamente',
    (fixture) => fixture.editorialReview['humanReview'] = true,
    'humanReview=false',
  );
  _invalidCase('falha com IDs de passes repetidos', (fixture) {
    final passes = fixture.editorialReview['passes']! as List<Object?>;
    final first = passes[0]! as Map<String, Object?>;
    final second = passes[1]! as Map<String, Object?>;
    second['id'] = first['id'];
  }, 'IDs distintos');
}

void _invalidCase(
  String name,
  void Function(_CatalogFixture fixture) mutate,
  String expectedError,
) {
  test(name, () {
    final fixture = _CatalogFixture.valid();
    mutate(fixture);

    final result = fixture.validate();

    expect(result.isValid, isFalse);
    expect(result.errors.join('\n'), contains(expectedError));
  });
}

List<Object?> _levels(Map<String, Object?> file) =>
    file['levels']! as List<Object?>;

Map<String, Object?> _level(Map<String, Object?> file, int index) =>
    _levels(file)[index]! as Map<String, Object?>;

List<Object?> _words(Map<String, Object?> bucket) =>
    bucket['words']! as List<Object?>;

class _CatalogFixture {
  _CatalogFixture({
    required this.withHints,
    required this.withoutHints,
    required this.acceptedBuckets,
    required this.editorialReview,
    required this.denylist,
  });

  factory _CatalogFixture.valid() {
    final buckets = <int, List<String>>{
      for (var length = 3; length <= 8; length++) length: <String>[],
    };
    final nextWordIndex = <int, int>{
      for (var length = 3; length <= 8; length++) length: 0,
    };
    var editorialIndex = 0;

    Map<String, Object?> buildMode(GameMode mode) {
      final levels = <Map<String, Object?>>[];
      for (var number = 1; number <= 500; number++) {
        final length = _expectedLength(number);
        final wordIndex = nextWordIndex[length]!;
        nextWordIndex[length] = wordIndex + 1;
        final answer = _word(length, wordIndex);
        buckets[length]!.add(answer);
        final item = <String, Object?>{
          'number': number,
          'answer': answer,
          'translation': 'termo-portugues-$editorialIndex',
          'meaning':
              'Definicao editorial exclusiva para o conceito numero $editorialIndex.',
        };
        if (mode == GameMode.withHints) {
          item['hint'] =
              'Contexto exclusivo associado ao conceito numerado $editorialIndex.';
          item['hintEn'] =
              'Distinct context associated with numbered concept $editorialIndex.';
        }
        editorialIndex++;
        levels.add(item);
      }
      return <String, Object?>{
        'schemaVersion': 2,
        'mode': mode.id,
        'levels': levels,
      };
    }

    final withHints = buildMode(GameMode.withHints);
    final withoutHints = buildMode(GameMode.withoutHints);
    for (final words in buckets.values) {
      words.sort();
    }
    final editorialReview = _reviewFor(withHints, withoutHints);
    return _CatalogFixture(
      withHints: withHints,
      withoutHints: withoutHints,
      acceptedBuckets: <int, Map<String, Object?>>{
        for (var length = 3; length <= 8; length++)
          length: <String, Object?>{
            'schemaVersion': 1,
            'length': length,
            'words': buckets[length],
          },
      },
      editorialReview: editorialReview,
      denylist: <String, Object?>{'schemaVersion': 1, 'answers': <String>[]},
    );
  }

  final Map<String, Object?> withHints;
  final Map<String, Object?> withoutHints;
  final Map<int, Map<String, Object?>> acceptedBuckets;
  final Map<String, Object?> editorialReview;
  final Map<String, Object?> denylist;

  CatalogValidationResult validate() => CatalogValidator.validate(
    withHints: _clone(withHints),
    withoutHints: _clone(withoutHints),
    acceptedBuckets: <int, Map<String, Object?>>{
      for (final entry in acceptedBuckets.entries)
        entry.key: _clone(entry.value),
    },
    editorialReview: _clone(editorialReview),
    denylist: _clone(denylist),
  );
}

Map<String, Object?> _reviewFor(
  Map<String, Object?> withHints,
  Map<String, Object?> withoutHints,
) {
  const authoringPass = 'fixture-authoring';
  const reviewPass = 'fixture-review';
  final records = <Map<String, Object?>>[];
  void add(Map<String, Object?> document, String mode) {
    for (final raw in document['levels']! as List<Object?>) {
      final level = raw! as Map<String, Object?>;
      final canonical = <String, Object?>{
        'mode': mode,
        'number': level['number'],
        'answer': level['answer'],
        'translation': level['translation'],
        'meaning': level['meaning'],
        if (mode == GameMode.withHints.id) 'hint': level['hint'],
        if (mode == GameMode.withHints.id) 'hintEn': level['hintEn'],
      };
      records.add(<String, Object?>{
        'mode': mode,
        'number': level['number'],
        'answer': level['answer'],
        'contentSha256': sha256
            .convert(utf8.encode(jsonEncode(canonical)))
            .toString(),
        'approvals': <String, Object?>{authoringPass: true, reviewPass: true},
      });
    }
  }

  add(withHints, GameMode.withHints.id);
  add(withoutHints, GameMode.withoutHints.id);
  return <String, Object?>{
    'schemaVersion': 2,
    'catalogRevision': 'lexinexo-1.0.0-scowl-rel-2026.02.25-bilingual-hints',
    'canonicalization':
        'UTF-8 JSON without whitespace in the documented canonical key order.',
    'humanReview': false,
    'passes': <Map<String, Object?>>[
      <String, Object?>{
        'id': authoringPass,
        'role': 'authoring',
        'agent': 'Fixture agent',
        'completedOn': '2026-08-09',
        'method':
            'Fixture authoring pass covering every generated test record.',
      },
      <String, Object?>{
        'id': reviewPass,
        'role': 'procedurallyIndependentReview',
        'agent': 'Fixture review agent',
        'completedOn': '2026-08-09',
        'method':
            'Separate fixture review pass covering every generated test record.',
      },
    ],
    'records': records,
  };
}

Map<String, Object?> _clone(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

int _expectedLength(int level) {
  if (level <= 50) return 3;
  if (level <= 150) return 4;
  if (level <= 275) return 5;
  if (level <= 400) return 6;
  if (level <= 460) return 7;
  return 8;
}

String _word(int length, int index) {
  var value = index;
  final codeUnits = List<int>.filled(length, 97);
  for (var position = length - 1; position >= 0; position--) {
    codeUnits[position] = 97 + value % 26;
    value ~/= 26;
  }
  return String.fromCharCodes(codeUnits);
}
