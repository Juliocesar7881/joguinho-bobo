import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolDir, '..', '..');
const dataDir = path.join(rootDir, 'assets', 'data');

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

const stopWords = new Set([
  'uma',
  'para',
  'por',
  'com',
  'que',
  'seu',
  'sua',
  'seus',
  'suas',
  'como',
  'dos',
  'das',
  'nos',
  'nas',
]);
const tokens = (text) =>
  new Set(
    (fold(text).match(/[a-z]+/g) ?? []).filter(
      (token) => token.length > 2 && !stopWords.has(token),
    ),
  );
const jaccard = (left, right) => {
  const leftTokens = tokens(left);
  const rightTokens = tokens(right);
  const union = new Set([...leftTokens, ...rightTokens]);
  if (union.size === 0) return 0;
  let intersection = 0;
  for (const token of leftTokens) {
    if (rightTokens.has(token)) intersection += 1;
  }
  return intersection / union.size;
};

export function auditEditorialCatalog() {
  const errors = [];
  const source = JSON.parse(
    fs.readFileSync(path.join(toolDir, 'catalog_source.json'), 'utf8'),
  );
  const curatedMeanings = JSON.parse(
    fs.readFileSync(path.join(toolDir, 'curated_meanings_ptbr.json'), 'utf8'),
  );
  const curatedEnglishHints = JSON.parse(
    fs.readFileSync(path.join(toolDir, 'english_hints.json'), 'utf8'),
  );
  const blocked = new Set(
    JSON.parse(fs.readFileSync(path.join(dataDir, 'denylist.json'), 'utf8'))
      .answers,
  );
  const accepted = new Map();
  for (let length = 3; length <= 8; length += 1) {
    const bucket = JSON.parse(
      fs.readFileSync(path.join(dataDir, `accepted_words_${length}.json`), 'utf8'),
    );
    accepted.set(length, new Set(bucket.words));
  }

  if (
    source.schemaVersion !== 2 ||
    source.catalogRevision !==
      'lexinexo-1.0.0-scowl-rel-2026.02.25-bilingual-hints' ||
    source.lexicalSource?.name !== 'SCOWL/ESDB' ||
    source.lexicalSource?.release !== 'rel-2026.02.25' ||
    source.lexicalSource?.commit !==
      '7e99edab8e32f9f9ea2b15f249ca8d4d67237410' ||
    source.records?.length !== 1000
  ) {
    errors.push('Fonte editorial não corresponde ao snapshot SCOWL fixado.');
    return errors;
  }
  if (Object.keys(curatedMeanings).length !== 1000) {
    errors.push('A curadoria de significados deve conter 1.000 entradas.');
  }
  if (
    curatedEnglishHints.schemaVersion !== 2 ||
    curatedEnglishHints.catalogRevision !== source.catalogRevision ||
    curatedEnglishHints.locale !== 'en-US' ||
    curatedEnglishHints.passes?.length !== 2 ||
    curatedEnglishHints.records?.length !== 500
  ) {
    errors.push('A curadoria de dicas inglesas está incompleta.');
  }

  const answers = new Set();
  const meanings = new Set();
  const hints = new Set();
  const englishHints = new Set();
  const oldTemplatePrefixes = [
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
  const artificialPortuguese = [
    /\bqualquer um dos v.rios\b/iu,
    /\bum(?:a)? determinad[oa]\b/iu,
    /\ba propriedade (?:de|criada)\b/iu,
    /\brelembrar o conhecimento\b/iu,
    /\bum exemplo de questionamento\b/iu,
    /\bapenas precedendo\b/iu,
    /\bconsiderar de forma abrangente\b/iu,
    /\b(?:sendo|tendo) (?:de|um|uma|o|a)\b/iu,
    /\b(?:assembléia|afecte|jóias)\b/iu,
    /\bou\s+[^,.]{1,35}\sou\s+[^,.]{1,35}\sou\b/iu,
  ];
  const validParts = new Set([
    'noun',
    'verb',
    'adjective',
    'adverb',
    'preposition',
    'pronoun',
    'determiner',
    'number',
  ]);

  for (const item of source.records) {
    const label = `${item.mode} nível ${item.number} (${item.answer})`;
    if (!accepted.get(item.answer?.length)?.has(item.answer)) {
      errors.push(`${label}: resposta não pertence ao SCOWL aceito.`);
    }
    if (blocked.has(item.answer)) errors.push(`${label}: resposta na denylist.`);
    if (answers.has(item.answer)) errors.push(`${label}: resposta repetida.`);
    answers.add(item.answer);
    if (!validParts.has(item.partOfSpeech)) {
      errors.push(`${label}: classe gramatical inválida.`);
    }
    if (curatedMeanings[item.answer] !== item.meaning) {
      errors.push(`${label}: significado diverge da curadoria explícita.`);
    }
    for (const [field, minimum, maximum] of [
      ['translation', 1, 60],
      ['meaning', 20, 140],
      ...(item.mode === 'withHints'
        ? [
            ['hint', 15, 100],
            ['hintEn', 15, 120],
          ]
        : []),
    ]) {
      const text = item[field];
      if (
        typeof text !== 'string' ||
        text !== text.trim() ||
        text.length < minimum ||
        text.length > maximum ||
        text.includes('\n') ||
        /(?:\u2026|\.\.\.|\betc\.?$)/iu.test(text) ||
        /\b(?:TODO|FIXME)\b/u.test(text) ||
        /\b(?:lorem|placeholder)\b/iu.test(text)
      ) {
        errors.push(`${label}: ${field} incompleto ou provisório.`);
      }
    }
    if (
      typeof item.meaning === 'string' &&
      (!/^[A-ZÁÀÂÃÉÊÍÓÔÕÚÇ]/u.test(item.meaning) ||
        !/[.!?]$/u.test(item.meaning) ||
        artificialPortuguese.some((pattern) => pattern.test(item.meaning)))
    ) {
      errors.push(`${label}: significado não passou a revisão de PT-BR.`);
    }
    const meaningKey = item.meaning?.toLocaleLowerCase('pt-BR');
    if (meanings.has(meaningKey)) errors.push(`${label}: significado repetido.`);
    meanings.add(meaningKey);
    if (item.mode === 'withHints') {
      const hintKey = item.hint?.toLocaleLowerCase('pt-BR');
      if (
        typeof item.hint === 'string' &&
        (!/^[A-ZÁÀÂÃÉÊÍÓÔÕÚÇ]/u.test(item.hint) ||
          !/[.!?]$/u.test(item.hint) ||
          oldTemplatePrefixes.some((prefix) => fold(item.hint).startsWith(prefix)) ||
          reveals(item.hint, item.answer) ||
          reveals(item.hint, item.translation) ||
          fold(item.hint) === fold(item.meaning))
      ) {
        errors.push(`${label}: dica não passou a revisão editorial.`);
      }
      if (hints.has(hintKey)) errors.push(`${label}: dica repetida.`);
      hints.add(hintKey);
      const hintEnKey = item.hintEn?.toLowerCase();
      const reviewedEnglish = curatedEnglishHints.records?.[item.number - 1];
      if (
        typeof item.hintEn !== 'string' ||
        !/^[A-Z]/.test(item.hintEn) ||
        !/[.!?]$/.test(item.hintEn) ||
        reveals(item.hintEn, item.answer) ||
        reviewedEnglish?.number !== item.number ||
        reviewedEnglish?.answer !== item.answer ||
        reviewedEnglish?.hintEn !== item.hintEn ||
        reviewedEnglish?.authorApproved !== true ||
        reviewedEnglish?.independentReviewApproved !== true
      ) {
        errors.push(`${label}: dica inglesa não passou a revisão editorial.`);
      }
      if (englishHints.has(hintEnKey)) {
        errors.push(`${label}: dica inglesa repetida.`);
      }
      englishHints.add(hintEnKey);
    } else if ('hint' in item || 'hintEn' in item) {
      errors.push(`${label}: dica indevida no modo sem dicas.`);
    }
  }
  if (
    answers.size !== 1000 ||
    meanings.size !== 1000 ||
    hints.size !== 500 ||
    englishHints.size !== 500
  ) {
    errors.push('A auditoria não encontrou 1.000 respostas/significados e 500 dicas únicos.');
  }
  const byAnswer = new Map(source.records.map((item) => [item.answer, item]));
  const strongCircularityAnswers = [
    'kit',
    'fit',
    'male',
    'north',
    'reply',
    'might',
    'watch',
    'super',
    'minor',
    'enough',
    'unique',
    'parent',
    'demand',
    'proper',
    'feature',
    'official',
  ];
  for (const answer of strongCircularityAnswers) {
    const item = byAnswer.get(answer);
    if (
      item == null ||
      reveals(item.meaning, item.translation) ||
      (item.hint != null && reveals(item.hint, item.translation))
    ) {
      errors.push(`Circularidade forte ainda presente em ${answer}.`);
    }
  }

  const mechanicalFamilies = [
    ['ten', 'four', 'seven', 'eight'],
    ['third', 'second', 'fourth'],
    ['northern', 'southern'],
  ];
  for (const family of mechanicalFamilies) {
    for (let left = 0; left < family.length; left += 1) {
      for (let right = left + 1; right < family.length; right += 1) {
        const leftItem = byAnswer.get(family[left]);
        const rightItem = byAnswer.get(family[right]);
        if (
          leftItem == null ||
          rightItem == null ||
          jaccard(
            `${leftItem.meaning} ${leftItem.hint ?? ''}`,
            `${rightItem.meaning} ${rightItem.hint ?? ''}`,
          ) >= 0.45
        ) {
          errors.push(
            `Familia editorial mecanica: ${family[left]}/${family[right]}.`,
          );
        }
      }
    }
  }

  const distinctSenseGroups = [
    ['far', 'away'],
    ['bit', 'part', 'piece'],
    ['aim', 'target'],
    ['type', 'sort'],
    ['near', 'nearby'],
    ['medium', 'channel'],
    ['version', 'edition'],
    ['reply', 'response'],
  ];
  for (const group of distinctSenseGroups) {
    for (let left = 0; left < group.length; left += 1) {
      for (let right = left + 1; right < group.length; right += 1) {
        const leftItem = byAnswer.get(group[left]);
        const rightItem = byAnswer.get(group[right]);
        if (
          leftItem == null ||
          rightItem == null ||
          jaccard(leftItem.meaning, rightItem.meaning) >= 0.35
        ) {
          errors.push(
            `Sentidos insuficientemente distintos: ${group[left]}/${group[right]}.`,
          );
        }
      }
    }
  }

  const nearDuplicateMeaningHintAnswers = [
    'hip',
    'bird',
    'item',
    'long',
    'risk',
    'girl',
    'idea',
    'vote',
    'price',
    'share',
    'error',
    'trust',
    'piece',
    'browse',
    'listen',
    'pocket',
    'branch',
    'script',
    'version',
    'network',
    'control',
    'central',
    'kingdom',
    'success',
    'personal',
    'analysis',
    'approach',
  ];
  for (const answer of nearDuplicateMeaningHintAnswers) {
    const item = byAnswer.get(answer);
    if (
      item == null ||
      item.hint == null ||
      jaccard(item.meaning, item.hint) >= 0.75
    ) {
      errors.push(`Significado e dica ainda muito similares em ${answer}.`);
    }
  }
  return errors;
}

if (path.resolve(process.argv[1] ?? '') === fileURLToPath(import.meta.url)) {
  const errors = auditEditorialCatalog();
  if (errors.length > 0) {
    for (const error of errors) console.error(`- ${error}`);
    process.exitCode = 1;
  } else {
    console.log(
      'Auditoria editorial aprovada: 1.000 significados, 500 dicas PT-BR e 500 dicas en-US; 0 circularidades fortes; 0 famílias mecânicas; sentidos distinguíveis; 0 pares significado/dica com Jaccard >= 0,75; sem revisão humana.',
    );
  }
}
