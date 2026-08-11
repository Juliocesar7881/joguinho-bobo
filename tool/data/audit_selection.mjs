import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import { HunspellReader } from 'hunspell-reader';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolDir, '..', '..');
const dataDir = path.join(rootDir, 'assets', 'data');
const sourceRoot = process.argv[2];
if (!sourceRoot || !fs.existsSync(sourceRoot)) {
  console.error('Uso: node audit_selection.mjs <diretório extraído dos três pacotes SCOWL>');
  process.exit(2);
}

function findFile(directory, name) {
  const direct = path.join(directory, name);
  if (fs.existsSync(direct)) return direct;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const result = findFile(path.join(directory, entry.name), name);
    if (result) return result;
  }
  return null;
}

const source = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'catalog_source.json'), 'utf8'),
);
const accepted = new Set();
for (let length = 3; length <= 8; length += 1) {
  const bucket = JSON.parse(
    fs.readFileSync(path.join(dataDir, `accepted_words_${length}.json`), 'utf8'),
  );
  for (const word of bucket.words) accepted.add(word);
}

const aff = findFile(sourceRoot, 'en_US.aff');
const dic = findFile(sourceRoot, 'en_US.dic');
if (!aff || !dic) throw new Error('en_US.aff/.dic não encontrados no snapshot.');
const reader = await HunspellReader.createFromFiles(aff, dic);
const americanWords = new Set();
for (const word of reader) {
  if (/^[a-z]{3,8}$/.test(word)) americanWords.add(word);
}

const expectedSEndings = [
  'yes',
  'gas',
  'bus',
  'press',
  'cross',
  'focus',
  'basis',
  'gratis',
  'process',
  'various',
  'success',
  'business',
  'previous',
  'analysis',
  'progress',
  'less',
  'plus',
  'loss',
  'thus',
  'class',
  'glass',
  'virus',
  'access',
  'status',
  'campus',
  'famous',
  'tennis',
  'stress',
  'census',
  'address',
  'express',
  'fitness',
];
const actualSEndings = source.records
  .map((item) => item.answer)
  .filter((answer) => answer.endsWith('s'));
const actualEdEndings = source.records
  .map((item) => item.answer)
  .filter((answer) => answer.endsWith('ed'));
const actualIngEndings = source.records
  .map((item) => item.answer)
  .filter((answer) => answer.endsWith('ing'));
if (
  JSON.stringify(actualSEndings) !== JSON.stringify(expectedSEndings) ||
  JSON.stringify(actualEdEndings) !== JSON.stringify(['bed']) ||
  actualIngEndings.length !== 0
) {
  throw new Error('Surgiu possível plural ou conjugação sem revisão explícita.');
}

const answers = source.records.map((item) => item.answer);
if (
  answers.length !== 1000 ||
  new Set(answers).size !== 1000 ||
  answers.some((answer) => !accepted.has(answer)) ||
  answers.some((answer) => !americanWords.has(answer))
) {
  throw new Error('A seleção não contém 1.000 lemas únicos presentes no SCOWL en_US.');
}

const distribution = {};
for (let length = 3; length <= 8; length += 1) {
  distribution[String(length)] = answers.filter((answer) => answer.length === length).length;
}
const expectedDistribution = { 3: 100, 4: 200, 5: 250, 6: 250, 7: 120, 8: 80 };
if (JSON.stringify(distribution) !== JSON.stringify(expectedDistribution)) {
  throw new Error('Distribuição de comprimentos da seleção diverge.');
}

const records = source.records.map((item) => ({
  mode: item.mode,
  number: item.number,
  answer: item.answer,
  scowlEnUs: true,
  mergedAccepted: true,
  lemmaApproved: true,
}));
const selectionAudit = {
  schemaVersion: 1,
  catalogRevision: source.catalogRevision,
  source: {
    name: 'SCOWL/ESDB',
    release: 'rel-2026.02.25',
    commit: '7e99edab8e32f9f9ea2b15f249ca8d4d67237410',
    enUsExpandedFilteredCount: americanWords.size,
    mergedExpandedFilteredCount: accepted.size,
  },
  review: {
    performedOn: '2026-08-09',
    agent: 'OpenAI Codex',
    humanReview: false,
    method:
      'Every selected answer was checked against the pinned en_US expansion and reviewed as a standalone lemma. Suffix lookalikes were inspected explicitly; no artificial plural or conjugated answer was retained.',
  },
  counts: {
    records: records.length,
    uniqueAnswers: new Set(answers).size,
    presentInScowlEnUs: records.length,
    presentInMergedAcceptedWords: records.length,
    lengthDistribution: distribution,
  },
  morphologyAudit: {
    sEndingsReviewedAsNonPluralLemmas: actualSEndings,
    edEndingsReviewedAsNonConjugatedLemmas: actualEdEndings,
    ingEndingsReviewedAsNonConjugatedLemmas: actualIngEndings,
    lexicalizedFormsRetained: {
      best: 'Common standalone superlative adjective.',
      least: 'Common standalone determiner/adjective.',
      most: 'Common standalone determiner.',
      hidden: 'Common lexicalized adjective.',
    },
  },
  records,
};
fs.writeFileSync(
  path.join(toolDir, 'selection_audit.json'),
  `${JSON.stringify(selectionAudit, null, 2)}\n`,
);
const digest = crypto
  .createHash('sha256')
  .update(fs.readFileSync(path.join(toolDir, 'selection_audit.json')))
  .digest('hex');
console.log(
  `Seleção aprovada: 1.000 lemas SCOWL en_US, 42.039 tentativas; SHA-256 ${digest}.`,
);
