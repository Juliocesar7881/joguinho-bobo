import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lexinexo/src/data/catalog_validator.dart';

Map<String, Object?> readObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw FormatException('$path não contém um objeto JSON.');
  }
  return Map<String, Object?>.from(decoded);
}

void main() {
  const data = 'assets/data';
  final files = <File>[
    File('$data/levels_with_hints.json'),
    File('$data/levels_without_hints.json'),
    for (var length = 3; length <= 8; length++)
      File('$data/accepted_words_$length.json'),
    File('$data/data_manifest.json'),
    File('$data/editorial_review.json'),
    File('$data/denylist.json'),
  ];
  final missing = files.where((file) => !file.existsSync()).toList();
  if (missing.isNotEmpty) {
    stderr.writeln(
      'Arquivos ausentes: ${missing.map((f) => f.path).join(', ')}',
    );
    exitCode = 1;
    return;
  }

  final withHints = readObject('$data/levels_with_hints.json');
  final withoutHints = readObject('$data/levels_without_hints.json');
  final acceptedBuckets = <int, Map<String, Object?>>{
    for (var length = 3; length <= 8; length++)
      length: readObject('$data/accepted_words_$length.json'),
  };
  final editorialReview = readObject('$data/editorial_review.json');
  final denylist = readObject('$data/denylist.json');
  final manifest = readObject('$data/data_manifest.json');
  final result = CatalogValidator.validate(
    withHints: withHints,
    withoutHints: withoutHints,
    acceptedBuckets: acceptedBuckets,
    editorialReview: editorialReview,
    denylist: denylist,
  );
  final errors = <String>[...result.errors];
  errors.addAll(
    validateManifest(
      manifest: manifest,
      acceptedBuckets: acceptedBuckets,
      editorialReview: editorialReview,
      denylist: denylist,
    ),
  );
  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  final rawBytes = files.fold<int>(0, (sum, file) => sum + file.lengthSync());
  final compressedBytes = files.fold<int>(
    0,
    (sum, file) => sum + gzip.encode(file.readAsBytesSync()).length,
  );
  if (rawBytes > 1024 * 1024) {
    stderr.writeln('Assets de dados excedem 1 MiB bruto: $rawBytes bytes.');
    exitCode = 1;
    return;
  }
  if (compressedBytes > 512 * 1024) {
    stderr.writeln(
      'Assets de dados excedem 0,5 MiB comprimido: $compressedBytes bytes.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Catálogo válido: 1.000 níveis; 42.039 tentativas; '
    '$rawBytes bytes brutos; $compressedBytes bytes comprimidos.',
  );
}

List<String> validateManifest({
  required Map<String, Object?> manifest,
  required Map<int, Map<String, Object?>> acceptedBuckets,
  required Map<String, Object?> editorialReview,
  required Map<String, Object?> denylist,
}) {
  final errors = <String>[];
  _expectKeys(
    manifest,
    const <String>{
      'schemaVersion',
      'source',
      'generation',
      'editorial',
      'acceptedWords',
      'levels',
      'supportingFiles',
      'tooling',
    },
    'data_manifest',
    errors,
  );
  if (manifest['schemaVersion'] != 2) {
    errors.add('Versão incompatível em data_manifest.json.');
  }

  final source = _object(manifest['source'], 'source', errors);
  _expectKeys(
    source,
    const <String>{'name', 'release', 'commit', 'license', 'dictionaries'},
    'source',
    errors,
  );
  if (source['name'] != 'SCOWL/ESDB' ||
      source['release'] != 'rel-2026.02.25' ||
      source['commit'] != '7e99edab8e32f9f9ea2b15f249ca8d4d67237410') {
    errors.add('Origem SCOWL fixada diverge do snapshot auditado.');
  }
  final dictionaries = source['dictionaries'];
  if (dictionaries is! List || dictionaries.length != 3) {
    errors.add('O manifesto deve registrar os três dicionários de origem.');
  } else {
    for (final value in dictionaries) {
      final entry = _object(value, 'source.dictionaries', errors);
      _expectKeys(
        entry,
        const <String>{'locale', 'url', 'sha256'},
        'source.dictionaries',
        errors,
      );
      if (!_isHash(entry['sha256'])) errors.add('Hash de origem inválido.');
    }
  }

  final generation = _object(manifest['generation'], 'generation', errors);
  _expectKeys(
    generation,
    const <String>{
      'tool',
      'version',
      'filter',
      'lowercaseOnly',
      'sort',
      'deduplicate',
    },
    'generation',
    errors,
  );
  if (generation['tool'] != 'hunspell-reader' ||
      generation['version'] != '10.0.1' ||
      generation['filter'] != r'^[a-z]{3,8}$' ||
      generation['lowercaseOnly'] != true ||
      generation['deduplicate'] != true) {
    errors.add('Parâmetros de geração incompatíveis.');
  }

  final editorial = _object(manifest['editorial'], 'editorial', errors);
  _expectKeys(
    editorial,
    const <String>{
      'revision',
      'selection',
      'portugueseText',
      'englishText',
      'review',
      'humanReview',
      'files',
    },
    'editorial',
    errors,
  );
  if (editorial['revision'] !=
          'lexinexo-1.0.0-scowl-rel-2026.02.25-bilingual-hints' ||
      editorial['humanReview'] != false ||
      editorial['selection'] is! String ||
      editorial['portugueseText'] is! String ||
      editorial['englishText'] is! String ||
      editorial['review'] is! String) {
    errors.add('Metadados editoriais v2 incompletos.');
  }
  final editorialFiles = _object(editorial['files'], 'editorial.files', errors);
  _expectKeys(
    editorialFiles,
    const <String>{
      'source',
      'meanings',
      'englishHints',
      'policy',
      'selectionAudit',
      'semanticReview',
    },
    'editorial.files',
    errors,
  );
  _checkFileEntry(
    value: editorialFiles['source'],
    label: 'editorial.files.source',
    expectedFile: 'tool/data/catalog_source.json',
    expectedCount: 1000,
    errors: errors,
  );
  _checkFileEntry(
    value: editorialFiles['meanings'],
    label: 'editorial.files.meanings',
    expectedFile: 'tool/data/curated_meanings_ptbr.json',
    expectedCount: 1000,
    errors: errors,
  );
  _checkFileEntry(
    value: editorialFiles['englishHints'],
    label: 'editorial.files.englishHints',
    expectedFile: 'tool/data/english_hints.json',
    expectedCount: 500,
    errors: errors,
  );
  _checkFileEntry(
    value: editorialFiles['policy'],
    label: 'editorial.files.policy',
    expectedFile: 'tool/data/EDITORIAL_POLICY.md',
    errors: errors,
  );
  _checkFileEntry(
    value: editorialFiles['selectionAudit'],
    label: 'editorial.files.selectionAudit',
    expectedFile: 'tool/data/selection_audit.json',
    expectedCount: 1000,
    errors: errors,
  );
  _checkFileEntry(
    value: editorialFiles['semanticReview'],
    label: 'editorial.files.semanticReview',
    expectedFile: 'tool/data/single_sense_review.json',
    expectedCount: 1000,
    errors: errors,
  );

  final accepted = _object(manifest['acceptedWords'], 'acceptedWords', errors);
  _expectKeys(
    accepted,
    const <String>{'total', 'files'},
    'acceptedWords',
    errors,
  );
  final acceptedFiles = _object(
    accepted['files'],
    'acceptedWords.files',
    errors,
  );
  var actualAcceptedTotal = 0;
  for (var length = 3; length <= 8; length++) {
    final words = acceptedBuckets[length]?['words'];
    final count = words is List ? words.length : 0;
    actualAcceptedTotal += count;
    _checkFileEntry(
      value: acceptedFiles['$length'],
      label: 'acceptedWords.files.$length',
      expectedFile: 'assets/data/accepted_words_$length.json',
      expectedCount: count,
      errors: errors,
    );
  }
  if (accepted['total'] != actualAcceptedTotal ||
      actualAcceptedTotal != 42039) {
    errors.add('Contagem total de tentativas aceitas diverge de 42.039.');
  }

  final levels = _object(manifest['levels'], 'levels', errors);
  _expectKeys(
    levels,
    const <String>{'withHints', 'withoutHints', 'uniqueAnswers'},
    'levels',
    errors,
  );
  _checkFileEntry(
    value: levels['withHints'],
    label: 'levels.withHints',
    expectedFile: 'assets/data/levels_with_hints.json',
    expectedCount: 500,
    errors: errors,
  );
  _checkFileEntry(
    value: levels['withoutHints'],
    label: 'levels.withoutHints',
    expectedFile: 'assets/data/levels_without_hints.json',
    expectedCount: 500,
    errors: errors,
  );
  if (levels['uniqueAnswers'] != 1000) {
    errors.add('O manifesto deve registrar 1.000 respostas únicas.');
  }

  final supporting = _object(
    manifest['supportingFiles'],
    'supportingFiles',
    errors,
  );
  _expectKeys(
    supporting,
    const <String>{'editorialReview', 'denylist', 'thirdPartyNotices'},
    'supportingFiles',
    errors,
  );
  _checkFileEntry(
    value: supporting['editorialReview'],
    label: 'supportingFiles.editorialReview',
    expectedFile: 'assets/data/editorial_review.json',
    expectedCount: (editorialReview['records'] as List?)?.length ?? 0,
    errors: errors,
  );
  _checkFileEntry(
    value: supporting['denylist'],
    label: 'supportingFiles.denylist',
    expectedFile: 'assets/data/denylist.json',
    expectedCount: (denylist['answers'] as List?)?.length ?? 0,
    errors: errors,
  );
  _checkFileEntry(
    value: supporting['thirdPartyNotices'],
    label: 'supportingFiles.thirdPartyNotices',
    expectedFile: 'THIRD_PARTY_NOTICES.md',
    errors: errors,
  );

  final tooling = _object(manifest['tooling'], 'tooling', errors);
  const toolFiles = <String, String>{
    'buildCatalog': 'tool/data/build_catalog.mjs',
    'buildDictionary': 'tool/data/build_dictionary.mjs',
    'applyCuratedMeanings': 'tool/data/apply_curated_meanings.mjs',
    'applySingleSenseReview': 'tool/data/apply_single_sense_review.mjs',
    'authorEnglishHints': 'tool/data/author_english_hints.mjs',
    'reviewEnglishHints': 'tool/data/review_english_hints.mjs',
    'auditEditorial': 'tool/data/audit_editorial.mjs',
    'auditSelection': 'tool/data/audit_selection.mjs',
    'reviewCatalog': 'tool/data/review_catalog.mjs',
    'verifyAssets': 'tool/data/verify_assets.mjs',
    'updateManifest': 'tool/data/update_manifest.mjs',
    'cliValidator': 'tool/validate_catalog.dart',
    'sharedValidator': 'lib/src/data/catalog_validator.dart',
    'sharedSha256': 'lib/src/data/sha256.dart',
  };
  _expectKeys(tooling, toolFiles.keys.toSet(), 'tooling', errors);
  for (final entry in toolFiles.entries) {
    _checkFileEntry(
      value: tooling[entry.key],
      label: 'tooling.${entry.key}',
      expectedFile: entry.value,
      errors: errors,
    );
  }
  return errors;
}

void _checkFileEntry({
  required Object? value,
  required String label,
  required String expectedFile,
  int? expectedCount,
  required List<String> errors,
}) {
  final entry = _object(value, label, errors);
  final expectedKeys = <String>{
    'file',
    'sha256',
    if (expectedCount != null) 'count',
  };
  _expectKeys(entry, expectedKeys, label, errors);
  if (entry['file'] != expectedFile ||
      (expectedCount != null && entry['count'] != expectedCount)) {
    errors.add('$label possui arquivo ou contagem divergente.');
  }
  final file = File(expectedFile);
  final actualHash = file.existsSync()
      ? sha256.convert(file.readAsBytesSync()).toString()
      : '';
  if (!_isHash(entry['sha256']) || entry['sha256'] != actualHash) {
    errors.add('$label possui SHA-256 divergente.');
  }
}

Map<String, Object?> _object(Object? value, String label, List<String> errors) {
  if (value is! Map) {
    errors.add('$label deve ser um objeto.');
    return <String, Object?>{};
  }
  return Map<String, Object?>.from(value);
}

void _expectKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String label,
  List<String> errors,
) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    errors.add('$label possui campos ausentes ou desconhecidos.');
  }
}

bool _isHash(Object? value) =>
    value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
