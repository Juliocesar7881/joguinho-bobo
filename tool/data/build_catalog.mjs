import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolDir, '..', '..');
const dataDir = path.join(rootDir, 'assets', 'data');
const source = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'catalog_source.json'), 'utf8'),
);
const curatedMeanings = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'curated_meanings_ptbr.json'), 'utf8'),
);
const curatedEnglishHints = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'english_hints.json'), 'utf8'),
);

const sourceKeys = Object.keys(source).sort().join(',');
if (
  sourceKeys !==
  ['catalogRevision', 'lexicalSource', 'records', 'schemaVersion'].join(',')
) {
  throw new Error('catalog_source.json possui campos ausentes ou desconhecidos.');
}
if (
  source.schemaVersion !== 2 ||
  source.catalogRevision !==
    'lexinexo-1.0.0-scowl-rel-2026.02.25-bilingual-hints' ||
  source.lexicalSource?.name !== 'SCOWL/ESDB' ||
  source.lexicalSource?.release !== 'rel-2026.02.25' ||
  source.lexicalSource?.commit !==
    '7e99edab8e32f9f9ea2b15f249ca8d4d67237410' ||
  !Array.isArray(source.records) ||
  source.records.length !== 1000
) {
  throw new Error('Cabeçalho ou quantidade inválida em catalog_source.json.');
}
if (
  Object.keys(curatedMeanings).length !== 1000 ||
  source.records.some(
    (item) => curatedMeanings[item.answer] !== item.meaning,
  )
) {
  throw new Error('A fonte diverge da curadoria explícita dos significados.');
}

if (
  curatedEnglishHints.schemaVersion !== 2 ||
  curatedEnglishHints.catalogRevision !== source.catalogRevision ||
  curatedEnglishHints.locale !== 'en-US' ||
  curatedEnglishHints.records?.length !== 500 ||
  curatedEnglishHints.records.some((reviewed, index) => {
    const sourceRecord = source.records.find(
      (item) => item.mode === 'withHints' && item.number === index + 1,
    );
    return (
      reviewed.number !== index + 1 ||
      reviewed.answer !== sourceRecord?.answer ||
      reviewed.hintEn !== sourceRecord?.hintEn ||
      reviewed.authorApproved !== true ||
      reviewed.independentReviewApproved !== true
    );
  })
) {
  throw new Error('A fonte diverge da curadoria revisada das dicas inglesas.');
}

const accepted = new Map();
for (let length = 3; length <= 8; length += 1) {
  const bucket = JSON.parse(
    fs.readFileSync(path.join(dataDir, `accepted_words_${length}.json`), 'utf8'),
  );
  accepted.set(length, new Set(bucket.words));
}

const fold = (value) =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase('pt-BR');
const escaped = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const reveals = (text, value) => {
  const candidate = fold(value.trim());
  if (candidate.length < 3) return false;
  return new RegExp(`(^|[^a-z])${escaped(candidate)}([^a-z]|$)`).test(
    fold(text),
  );
};
const truncated = (value) =>
  /(?:\u2026|\.\.\.|\betc\.?$)/iu.test(value.trim());
const genericPrefixes = [
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
];
const expectedLength = (level) =>
  level <= 50
    ? 3
    : level <= 150
      ? 4
      : level <= 275
        ? 5
        : level <= 400
          ? 6
          : level <= 460
            ? 7
            : 8;

const answers = new Set();
const meanings = new Set();
const hints = new Set();
const englishHints = new Set();
const output = new Map([
  ['withHints', []],
  ['withoutHints', []],
]);
for (const mode of output.keys()) {
  const records = source.records.filter((item) => item.mode === mode);
  if (records.length !== 500) {
    throw new Error(`${mode} deve conter exatamente 500 registros.`);
  }
  records.forEach((item, index) => {
    const number = index + 1;
    const expectedKeys = (
      mode === 'withHints'
        ? [
            'answer',
            'hint',
            'hintEn',
            'meaning',
            'mode',
            'number',
            'partOfSpeech',
            'translation',
          ]
        : [
            'answer',
            'meaning',
            'mode',
            'number',
            'partOfSpeech',
            'translation',
          ]
    ).join(',');
    if (Object.keys(item).sort().join(',') !== expectedKeys) {
      throw new Error(`${mode} nível ${number}: campos editoriais inválidos.`);
    }
    if (
      item.number !== number ||
      !/^[a-z]{3,8}$/.test(item.answer) ||
      item.answer.length !== expectedLength(number) ||
      !accepted.get(item.answer.length)?.has(item.answer)
    ) {
      throw new Error(`${mode} nível ${number}: resposta fora do SCOWL fixado.`);
    }
    if (
      ![
        'noun',
        'verb',
        'adjective',
        'adverb',
        'preposition',
        'pronoun',
        'determiner',
        'number',
      ].includes(item.partOfSpeech)
    ) {
      throw new Error(`${mode} nível ${number}: classe gramatical inválida.`);
    }
    if (answers.has(item.answer)) throw new Error(`Resposta repetida: ${item.answer}.`);
    answers.add(item.answer);
    for (const [field, minimum, maximum] of [
      ['translation', 1, 60],
      ['meaning', 20, 140],
    ]) {
      const text = item[field];
      if (
        typeof text !== 'string' ||
        text !== text.trim() ||
        text.length < minimum ||
        text.length > maximum ||
        text.includes('\n') ||
        truncated(text)
      ) {
        throw new Error(`${mode} nível ${number}: ${field} inválido.`);
      }
    }
    const meaningKey = item.meaning.toLocaleLowerCase('pt-BR');
    if (meanings.has(meaningKey)) {
      throw new Error(`${mode} nível ${number}: significado repetido.`);
    }
    meanings.add(meaningKey);
    if (mode === 'withHints') {
      if (
        typeof item.hint !== 'string' ||
        item.hint !== item.hint.trim() ||
        item.hint.length < 15 ||
        item.hint.length > 100 ||
        truncated(item.hint) ||
        reveals(item.hint, item.answer) ||
        reveals(item.hint, item.translation) ||
        fold(item.hint) === fold(item.meaning) ||
        genericPrefixes.some((prefix) => fold(item.hint).startsWith(prefix))
      ) {
        throw new Error(`${mode} nível ${number}: dica editorial inválida.`);
      }
      const hintKey = item.hint.toLocaleLowerCase('pt-BR');
      if (hints.has(hintKey)) {
        throw new Error(`${mode} nível ${number}: dica repetida.`);
      }
      hints.add(hintKey);
      if (
        typeof item.hintEn !== 'string' ||
        item.hintEn !== item.hintEn.trim() ||
        item.hintEn.length < 15 ||
        item.hintEn.length > 120 ||
        !/^[A-Z]/.test(item.hintEn) ||
        !/[.!?]$/.test(item.hintEn) ||
        truncated(item.hintEn) ||
        reveals(item.hintEn, item.answer)
      ) {
        throw new Error(`${mode} nível ${number}: dica inglesa inválida.`);
      }
      const hintEnKey = item.hintEn.toLowerCase();
      if (englishHints.has(hintEnKey)) {
        throw new Error(`${mode} nível ${number}: dica inglesa repetida.`);
      }
      englishHints.add(hintEnKey);
    }
    output.get(mode).push({
      number,
      answer: item.answer,
      translation: item.translation,
      meaning: item.meaning,
      ...(mode === 'withHints'
        ? { hint: item.hint, hintEn: item.hintEn }
        : {}),
    });
  });
}

if (answers.size !== 1000) throw new Error('O catálogo deve ter 1.000 respostas.');
fs.mkdirSync(dataDir, { recursive: true });
for (const [mode, levels] of output) {
  const name =
    mode === 'withHints'
      ? 'levels_with_hints.json'
      : 'levels_without_hints.json';
  fs.writeFileSync(
    path.join(dataDir, name),
    JSON.stringify({ schemaVersion: 2, mode, levels }),
  );
}
console.log('Catálogo SCOWL gerado: 500 níveis com dicas e 500 sem dicas.');
