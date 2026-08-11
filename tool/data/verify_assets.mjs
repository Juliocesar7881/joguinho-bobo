import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

import { auditEditorialCatalog } from './audit_editorial.mjs';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolDir, '..', '..');
const dataDir = path.join(rootDir, 'assets', 'data');
const errors = [...auditEditorialCatalog()];
const expectedCounts = { 3: 820, 4: 2754, 5: 5229, 6: 8479, 7: 11802, 8: 12955 };
const read = (file) =>
  JSON.parse(fs.readFileSync(path.join(rootDir, ...file.split('/')), 'utf8'));
const hash = (file) =>
  crypto
    .createHash('sha256')
    .update(fs.readFileSync(path.join(rootDir, ...file.split('/'))))
    .digest('hex');

let acceptedTotal = 0;
for (let length = 3; length <= 8; length += 1) {
  const file = `assets/data/accepted_words_${length}.json`;
  const bucket = read(file);
  if (
    bucket.schemaVersion !== 1 ||
    bucket.length !== length ||
    !Array.isArray(bucket.words) ||
    bucket.words.length !== expectedCounts[length]
  ) {
    errors.push(`${file}: cabeçalho ou quantidade inválida.`);
    continue;
  }
  for (let index = 0; index < bucket.words.length; index += 1) {
    const word = bucket.words[index];
    if (
      !new RegExp(`^[a-z]{${length}}$`).test(word) ||
      (index > 0 && bucket.words[index - 1] >= word)
    ) {
      errors.push(`${file}: entrada, ordem ou duplicidade inválida em ${word}.`);
      break;
    }
  }
  acceptedTotal += bucket.words.length;
}
if (acceptedTotal !== 42039) errors.push(`Dicionário total: ${acceptedTotal}.`);

const source = read('tool/data/catalog_source.json');
const englishHints = read('tool/data/english_hints.json');
const selectionAudit = read('tool/data/selection_audit.json');
const semanticReview = read('tool/data/single_sense_review.json');
const levelFiles = [
  ['assets/data/levels_with_hints.json', 'withHints'],
  ['assets/data/levels_without_hints.json', 'withoutHints'],
];
const allLevels = [];
for (const [file, mode] of levelFiles) {
  const document = read(file);
  if (
    document.schemaVersion !== 2 ||
    document.mode !== mode ||
    document.levels?.length !== 500
  ) {
    errors.push(`${file}: cabeçalho ou quantidade inválida.`);
    continue;
  }
  for (const level of document.levels) {
    const sourceRecord = source.records.find(
      (item) => item.mode === mode && item.number === level.number,
    );
    const expected = {
      number: sourceRecord?.number,
      answer: sourceRecord?.answer,
      translation: sourceRecord?.translation,
      meaning: sourceRecord?.meaning,
      ...(mode === 'withHints'
        ? { hint: sourceRecord?.hint, hintEn: sourceRecord?.hintEn }
        : {}),
    };
    if (JSON.stringify(level) !== JSON.stringify(expected)) {
      errors.push(`${file} nível ${level.number}: conteúdo diverge da fonte.`);
    }
    allLevels.push([mode, level]);
  }
}

const selectedAnswers = source.records.map((item) => item.answer);
if (
  englishHints.schemaVersion !== 2 ||
  englishHints.catalogRevision !== source.catalogRevision ||
  englishHints.locale !== 'en-US' ||
  englishHints.passes?.length !== 2 ||
  englishHints.records?.length !== 500
) {
  errors.push('english_hints.json possui metadados centrais inválidos.');
} else {
  englishHints.records.forEach((record, index) => {
    const sourceRecord = source.records.find(
      (item) => item.mode === 'withHints' && item.number === index + 1,
    );
    const expectedHash = crypto
      .createHash('sha256')
      .update(
        JSON.stringify({
          number: record.number,
          answer: record.answer,
          hintEn: record.hintEn,
        }),
        'utf8',
      )
      .digest('hex');
    if (
      record.number !== index + 1 ||
      record.answer !== sourceRecord?.answer ||
      record.hintEn !== sourceRecord?.hintEn ||
      record.contentSha256 !== expectedHash ||
      record.authorApproved !== true ||
      record.independentReviewApproved !== true
    ) {
      errors.push(`english_hints.json diverge no índice ${index}.`);
    }
  });
}
if (
  selectionAudit.schemaVersion !== 1 ||
  selectionAudit.catalogRevision !== source.catalogRevision ||
  selectionAudit.source?.name !== 'SCOWL/ESDB' ||
  selectionAudit.source?.release !== 'rel-2026.02.25' ||
  selectionAudit.source?.commit !== '7e99edab8e32f9f9ea2b15f249ca8d4d67237410' ||
  selectionAudit.source?.mergedExpandedFilteredCount !== 42039 ||
  selectionAudit.review?.humanReview !== false ||
  selectionAudit.counts?.records !== 1000 ||
  selectionAudit.counts?.uniqueAnswers !== 1000 ||
  selectionAudit.counts?.presentInScowlEnUs !== 1000 ||
  selectionAudit.counts?.presentInMergedAcceptedWords !== 1000 ||
  selectionAudit.records?.length !== 1000
) {
  errors.push('selection_audit.json possui metadados centrais inválidos.');
} else {
  selectionAudit.records.forEach((record, index) => {
    const sourceRecord = source.records[index];
    if (
      record.mode !== sourceRecord.mode ||
      record.number !== sourceRecord.number ||
      record.answer !== sourceRecord.answer ||
      record.scowlEnUs !== true ||
      record.mergedAccepted !== true ||
      record.lemmaApproved !== true
    ) {
      errors.push(`selection_audit.json diverge no índice ${index}.`);
    }
  });
  if (new Set(selectedAnswers).size !== 1000) {
    errors.push('A seleção editorial não possui 1.000 respostas únicas.');
  }
}

const remainingOrCount = source.records.filter((record) => /\bou\b/i.test(record.meaning))
  .length;
const explicitlyRevisedCount = semanticReview.records?.filter(
  (record) => record.explicitlyRevised === true,
).length;
if (
  semanticReview.schemaVersion !== 1 ||
  semanticReview.catalogRevision !== source.catalogRevision ||
  semanticReview.pass?.agent !== 'OpenAI Codex' ||
  semanticReview.pass?.humanReview !== false ||
  semanticReview.counts?.records !== 1000 ||
  semanticReview.counts?.originalOrCandidates !== 621 ||
  semanticReview.counts?.explicitlyRevised !== explicitlyRevisedCount ||
  explicitlyRevisedCount < 300 ||
  semanticReview.counts?.remainingSameSenseCoordinations !== remainingOrCount ||
  semanticReview.records?.length !== 1000
) {
  errors.push('single_sense_review.json possui metadados centrais inválidos.');
} else {
  semanticReview.records.forEach((reviewed, index) => {
    const record = source.records[index];
    const canonical = {
      mode: record.mode,
      number: record.number,
      answer: record.answer,
      partOfSpeech: record.partOfSpeech,
      translation: record.translation,
      meaning: record.meaning,
      ...(record.mode === 'withHints' ? { hint: record.hint } : {}),
    };
    const expectedHash = crypto
      .createHash('sha256')
      .update(JSON.stringify(canonical), 'utf8')
      .digest('hex');
    if (
      reviewed.mode !== record.mode ||
      reviewed.number !== record.number ||
      reviewed.answer !== record.answer ||
      reviewed.contentSha256 !== expectedHash ||
      reviewed.coordinatingOrRetained !== /\bou\b/i.test(record.meaning) ||
      reviewed.singleSenseApproved !== true
    ) {
      errors.push(`single_sense_review.json diverge no índice ${index}.`);
    }
  });
}

const review = read('assets/data/editorial_review.json');
if (
  review.schemaVersion !== 2 ||
  review.catalogRevision !== source.catalogRevision ||
  review.humanReview !== false ||
  review.passes?.length !== 2 ||
  review.records?.length !== 1000
) {
  errors.push('editorial_review.json v2 possui cabeçalho incompleto.');
} else {
  const passIds = review.passes.map((item) => item.id);
  if (new Set(passIds).size !== 2) errors.push('Passes editoriais não são distintos.');
  allLevels.forEach(([mode, level], index) => {
    const canonical = {
      mode,
      number: level.number,
      answer: level.answer,
      translation: level.translation,
      meaning: level.meaning,
      ...(mode === 'withHints'
        ? { hint: level.hint, hintEn: level.hintEn }
        : {}),
    };
    const expectedHash = crypto
      .createHash('sha256')
      .update(JSON.stringify(canonical), 'utf8')
      .digest('hex');
    const record = review.records[index];
    if (
      record?.mode !== mode ||
      record?.number !== level.number ||
      record?.answer !== level.answer ||
      record?.contentSha256 !== expectedHash ||
      Object.keys(record?.approvals ?? {}).length !== 2 ||
      passIds.some((id) => record.approvals?.[id] !== true)
    ) {
      errors.push(`editorial_review.json diverge no índice ${index}.`);
    }
  });
}

const manifest = read('assets/data/data_manifest.json');
if (
  manifest.schemaVersion !== 2 ||
  manifest.source?.commit !== '7e99edab8e32f9f9ea2b15f249ca8d4d67237410' ||
  manifest.acceptedWords?.total !== 42039 ||
  manifest.levels?.uniqueAnswers !== 1000 ||
  manifest.editorial?.humanReview !== false
) {
  errors.push('data_manifest.json possui metadados centrais inválidos.');
}
const entries = [
  ...Object.values(manifest.acceptedWords?.files ?? {}),
  manifest.levels?.withHints,
  manifest.levels?.withoutHints,
  ...Object.values(manifest.editorial?.files ?? {}),
  ...Object.values(manifest.supportingFiles ?? {}),
  ...Object.values(manifest.tooling ?? {}),
].filter(Boolean);
for (const entry of entries) {
  if (!entry.file || entry.sha256 !== hash(entry.file)) {
    errors.push(`Manifesto/hash inválido para ${entry.file ?? 'arquivo ausente'}.`);
  }
}

const assetNames = fs.readdirSync(dataDir).filter((name) => name.endsWith('.json'));
const rawBytes = assetNames.reduce(
  (total, name) => total + fs.statSync(path.join(dataDir, name)).size,
  0,
);
const compressedBytes = assetNames.reduce(
  (total, name) =>
    total + zlib.gzipSync(fs.readFileSync(path.join(dataDir, name)), { level: 9 }).length,
  0,
);
if (rawBytes > 1024 * 1024) errors.push(`Assets excedem 1 MiB: ${rawBytes}.`);
if (compressedBytes > 512 * 1024) errors.push(`Assets gzip excedem 0,5 MiB: ${compressedBytes}.`);

if (errors.length > 0) {
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(
    `OK: 1.000 níveis; 42.039 tentativas; ${rawBytes} bytes brutos; ${compressedBytes} bytes gzip.`,
  );
}
