import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import { auditEditorialCatalog } from './audit_editorial.mjs';

if (!process.argv.includes('--confirm-two-pass-agent-review')) {
  console.error(
    'Use --confirm-two-pass-agent-review somente após executar os dois passes descritos em EDITORIAL_POLICY.md.',
  );
  process.exit(2);
}

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolDir, '..', '..');
const dataDir = path.join(rootDir, 'assets', 'data');
const auditErrors = auditEditorialCatalog();
if (auditErrors.length > 0) {
  throw new Error(`Auditoria editorial falhou:\n${auditErrors.join('\n')}`);
}
const source = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'catalog_source.json'), 'utf8'),
);
const documents = ['levels_with_hints.json', 'levels_without_hints.json'].map(
  (name) => JSON.parse(fs.readFileSync(path.join(dataDir, name), 'utf8')),
);

const authoringPass = 'codex-bilingual-authoring-2026-08-10';
const reviewPass = 'codex-independent-bilingual-audit-2026-08-10';
const records = [];
for (const document of documents) {
  for (const level of document.levels) {
    const sourceRecord = source.records.find(
      (item) => item.mode === document.mode && item.number === level.number,
    );
    const expected = {
      number: sourceRecord?.number,
      answer: sourceRecord?.answer,
      translation: sourceRecord?.translation,
      meaning: sourceRecord?.meaning,
      ...(document.mode === 'withHints'
        ? { hint: sourceRecord?.hint, hintEn: sourceRecord?.hintEn }
        : {}),
    };
    if (JSON.stringify(level) !== JSON.stringify(expected)) {
      throw new Error(
        `${document.mode} nível ${level.number}: asset diverge da fonte editorial.`,
      );
    }
    const canonical = {
      mode: document.mode,
      number: level.number,
      answer: level.answer,
      translation: level.translation,
      meaning: level.meaning,
      ...(document.mode === 'withHints'
        ? { hint: level.hint, hintEn: level.hintEn }
        : {}),
    };
    records.push({
      mode: document.mode,
      number: level.number,
      answer: level.answer,
      contentSha256: crypto
        .createHash('sha256')
        .update(JSON.stringify(canonical), 'utf8')
        .digest('hex'),
      approvals: {
        [authoringPass]: true,
        [reviewPass]: true,
      },
    });
  }
}
if (records.length !== 1000) throw new Error('A revisão deve cobrir 1.000 registros.');

fs.writeFileSync(
  path.join(dataDir, 'editorial_review.json'),
  JSON.stringify({
    schemaVersion: 2,
    catalogRevision: source.catalogRevision,
    canonicalization:
      'UTF-8 JSON without whitespace; keys: mode, number, answer, translation, meaning, then hint and hintEn when present.',
    humanReview: false,
    passes: [
      {
        id: authoringPass,
        role: 'authoring',
        agent: 'OpenAI Codex',
        completedOn: '2026-08-10',
        method:
          'First pass curated and normalized every SCOWL answer, PT-BR translation, meaning, and both optional PT-BR and English clues.',
      },
      {
        id: reviewPass,
        role: 'procedurallyIndependentReview',
        agent: 'OpenAI Codex review agent',
        completedOn: '2026-08-10',
        method:
          'A separate procedural pass independently audited every record for sense and word-class alignment, natural PT-BR and English, circularity, clue leakage and similarity, mechanical families, duplication, prohibited content, and truncation; no human review.',
      },
    ],
    records,
  }),
);
console.log('Revisão editorial v2 gravada: 1.000 registros, sem revisão humana.');
