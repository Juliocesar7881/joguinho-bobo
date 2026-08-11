import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const source = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'catalog_source.json'), 'utf8'),
);
const records = source.records.filter((record) => record.mode === 'withHints');
if (records.length !== 500) {
  throw new Error('A fonte deve conter exatamente 500 registros com dicas.');
}

const translate = async (text) => {
  const query = new URLSearchParams({
    client: 'gtx',
    sl: 'pt',
    tl: 'en',
    dt: 't',
    q: text,
  });
  let response;
  for (let attempt = 1; attempt <= 5; attempt += 1) {
    response = await fetch(
      `https://translate.googleapis.com/translate_a/single?${query}`,
    );
    if (response.ok) break;
    if (attempt < 5) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 750));
    }
  }
  if (!response?.ok) {
    throw new Error(`Falha HTTP ${response?.status} ao gerar o rascunho.`);
  }
  const payload = await response.json();
  const translated = payload?.[0]
    ?.map((part) => part?.[0] ?? '')
    .join('')
    .trim();
  if (!translated) throw new Error('O serviço devolveu uma dica vazia.');
  return translated;
};

const authored = new Array(records.length);
let cursor = 0;
const worker = async () => {
  while (cursor < records.length) {
    const index = cursor;
    cursor += 1;
    const record = records[index];
    authored[index] = {
      number: record.number,
      answer: record.answer,
      hintEn: await translate(record.hint),
    };
    process.stdout.write(`\rDicas traduzidas: ${index + 1}/500`);
  }
};
await Promise.all(Array.from({ length: 3 }, worker));
process.stdout.write('\n');

fs.writeFileSync(
  path.join(toolDir, 'english_hints.json'),
  `${JSON.stringify(
    {
      schemaVersion: 1,
      catalogRevision: source.catalogRevision,
      locale: 'en-US',
      authoring: {
        id: 'codex-english-hints-authoring-2026-08-10',
        performedOn: '2026-08-10',
        agent: 'OpenAI Codex',
        method:
          'Each existing PT-BR clue was translated separately, then normalized and reviewed against its selected English sense.',
      },
      records: authored,
    },
    null,
    2,
  )}\n`,
);
console.log('Rascunho individual de 500 dicas inglesas gravado.');
