import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/data/catalog_validator.dart';

void main() {
  test('snapshot entregue passa pelo validador compartilhado', () {
    const root = 'assets/data';
    final result = CatalogValidator.validate(
      withHints: _read('$root/levels_with_hints.json'),
      withoutHints: _read('$root/levels_without_hints.json'),
      acceptedBuckets: <int, Map<String, Object?>>{
        for (var length = 3; length <= 8; length++)
          length: _read('$root/accepted_words_$length.json'),
      },
      editorialReview: _read('$root/editorial_review.json'),
      denylist: _read('$root/denylist.json'),
    );

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
  });

  test('snapshot possui 500 dicas bilingues somente no modo correto', () {
    const root = 'assets/data';
    final withHints = _read('$root/levels_with_hints.json');
    final withoutHints = _read('$root/levels_without_hints.json');
    final hintedLevels = (withHints['levels']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final plainLevels = (withoutHints['levels']! as List<Object?>)
        .cast<Map<String, Object?>>();

    expect(withHints['schemaVersion'], 2);
    expect(withoutHints['schemaVersion'], 2);
    expect(hintedLevels, hasLength(500));
    expect(
      hintedLevels.every(
        (level) =>
            (level['hint'] as String).isNotEmpty &&
            (level['hintEn'] as String).isNotEmpty,
      ),
      isTrue,
    );
    expect(
      plainLevels.every(
        (level) => !level.containsKey('hint') && !level.containsKey('hintEn'),
      ),
      isTrue,
    );
    expect(
      hintedLevels.map((level) => level['hintEn']).toSet(),
      hasLength(500),
    );
  });
}

Map<String, Object?> _read(String path) =>
    Map<String, Object?>.from(jsonDecode(File(path).readAsStringSync()) as Map);
