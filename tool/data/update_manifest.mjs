import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolDir, '..', '..');
const dataDir = path.join(rootDir, 'assets', 'data');
const sha256 = (file) =>
  crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const rootFile = (name) => path.join(rootDir, ...name.split('/'));
const hashed = (file, extra = {}) => ({ file, ...extra, sha256: sha256(rootFile(file)) });

const acceptedFiles = {};
let acceptedTotal = 0;
for (let length = 3; length <= 8; length += 1) {
  const name = `assets/data/accepted_words_${length}.json`;
  const count = JSON.parse(fs.readFileSync(rootFile(name), 'utf8')).words.length;
  acceptedTotal += count;
  acceptedFiles[String(length)] = hashed(name, { count });
}
const levelEntry = (file) =>
  hashed(file, {
    count: JSON.parse(fs.readFileSync(rootFile(file), 'utf8')).levels.length,
  });
const editorialReview = JSON.parse(
  fs.readFileSync(path.join(dataDir, 'editorial_review.json'), 'utf8'),
);
const denylist = JSON.parse(
  fs.readFileSync(path.join(dataDir, 'denylist.json'), 'utf8'),
);

const manifest = {
  schemaVersion: 2,
  source: {
    name: 'SCOWL/ESDB',
    release: 'rel-2026.02.25',
    commit: '7e99edab8e32f9f9ea2b15f249ca8d4d67237410',
    license: 'SCOWL permissive notice in THIRD_PARTY_NOTICES.md',
    dictionaries: [
      {
        locale: 'en_US',
        url: 'https://github.com/en-wl/wordlist/releases/download/rel-2026.02.25/hunspell-en_US-2026.02.25.zip',
        sha256: 'ac8e73310e951d88c52c2cf2ba54ceaca34f8486a81630ac8a75dc5f931179f9',
      },
      {
        locale: 'en_GB-ise',
        url: 'https://github.com/en-wl/wordlist/releases/download/rel-2026.02.25/hunspell-en_GB-ise-2026.02.25.zip',
        sha256: 'd6fbb91ae7824c52fb02f74d7bc2cd9092f130faec60f42326a59437fa7247a3',
      },
      {
        locale: 'en_GB-ize',
        url: 'https://github.com/en-wl/wordlist/releases/download/rel-2026.02.25/hunspell-en_GB-ize-2026.02.25.zip',
        sha256: 'c5bdd92fc1e21da7503939fe4139f36f28f01c18ac35e2fc90b526a1b7bfb099',
      },
    ],
  },
  generation: {
    tool: 'hunspell-reader',
    version: '10.0.1',
    filter: '^[a-z]{3,8}$',
    lowercaseOnly: true,
    sort: 'ascending Unicode code point order',
    deduplicate: true,
  },
  editorial: {
    revision: 'lexinexo-1.0.0-scowl-rel-2026.02.25-bilingual-hints',
    selection:
      '1,000 familiar American-English headwords selected only from the pinned SCOWL snapshot; British variants remain guesses only.',
    portugueseText:
      'Explicit per-record PT-BR translations, meanings, and optional clues; no runtime or build-time text templates.',
    englishText:
      'Explicit per-record en-US clues aligned with the selected PT-BR sense; each clue has separate authoring and review approval.',
    review:
      'Two-pass OpenAI Codex review with separate authoring and procedural audit IDs for PT-BR and en-US content; no human editorial review is claimed.',
    humanReview: false,
    files: {
      source: hashed('tool/data/catalog_source.json', { count: 1000 }),
      meanings: hashed('tool/data/curated_meanings_ptbr.json', { count: 1000 }),
      englishHints: hashed('tool/data/english_hints.json', { count: 500 }),
      policy: hashed('tool/data/EDITORIAL_POLICY.md'),
      selectionAudit: hashed('tool/data/selection_audit.json', { count: 1000 }),
      semanticReview: hashed('tool/data/single_sense_review.json', { count: 1000 }),
    },
  },
  acceptedWords: { total: acceptedTotal, files: acceptedFiles },
  levels: {
    withHints: levelEntry('assets/data/levels_with_hints.json'),
    withoutHints: levelEntry('assets/data/levels_without_hints.json'),
    uniqueAnswers: 1000,
  },
  supportingFiles: {
    editorialReview: hashed('assets/data/editorial_review.json', {
      count: editorialReview.records.length,
    }),
    denylist: hashed('assets/data/denylist.json', {
      count: denylist.answers.length,
    }),
    thirdPartyNotices: hashed('THIRD_PARTY_NOTICES.md'),
  },
  tooling: {
    buildCatalog: hashed('tool/data/build_catalog.mjs'),
    buildDictionary: hashed('tool/data/build_dictionary.mjs'),
    applyCuratedMeanings: hashed('tool/data/apply_curated_meanings.mjs'),
    applySingleSenseReview: hashed('tool/data/apply_single_sense_review.mjs'),
    authorEnglishHints: hashed('tool/data/author_english_hints.mjs'),
    reviewEnglishHints: hashed('tool/data/review_english_hints.mjs'),
    auditEditorial: hashed('tool/data/audit_editorial.mjs'),
    auditSelection: hashed('tool/data/audit_selection.mjs'),
    reviewCatalog: hashed('tool/data/review_catalog.mjs'),
    verifyAssets: hashed('tool/data/verify_assets.mjs'),
    updateManifest: hashed('tool/data/update_manifest.mjs'),
    cliValidator: hashed('tool/validate_catalog.dart'),
    sharedValidator: hashed('lib/src/data/catalog_validator.dart'),
    sharedSha256: hashed('lib/src/data/sha256.dart'),
  },
};

fs.writeFileSync(
  path.join(dataDir, 'data_manifest.json'),
  JSON.stringify(manifest),
);
console.log('data_manifest.json v2 atualizado com cadeia de hashes.');
