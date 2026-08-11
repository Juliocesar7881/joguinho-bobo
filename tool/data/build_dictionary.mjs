import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import { HunspellReader } from 'hunspell-reader';

const locales = ['en_US', 'en_GB-ise', 'en_GB-ize'];
const toolDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolDir, '..', '..');
const outputDir = path.join(rootDir, 'assets', 'data');

function usage() {
  console.error(
    'Uso: npm run build:dictionary -- <diretório com os três pacotes Hunspell extraídos>',
  );
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

const sourceRoot = process.argv[2];
if (!sourceRoot || !fs.existsSync(sourceRoot)) {
  usage();
  process.exit(2);
}

const words = new Set();
for (const locale of locales) {
  const aff = findFile(sourceRoot, `${locale}.aff`);
  const dic = findFile(sourceRoot, `${locale}.dic`);
  if (!aff || !dic) throw new Error(`Arquivos ${locale}.aff/.dic não encontrados.`);
  const reader = await HunspellReader.createFromFiles(aff, dic);
  for (const word of reader) {
    // The case-sensitive expression deliberately excludes entries that were
    // emitted with capitals, punctuation, accents, spaces, or digits.
    if (/^[a-z]{3,8}$/.test(word)) words.add(word);
  }
}

const sorted = [...words].sort((left, right) =>
  left < right ? -1 : left > right ? 1 : 0,
);
if (sorted.length !== 42039) {
  throw new Error(`Snapshot inesperado: ${sorted.length}; esperado: 42039.`);
}

fs.mkdirSync(outputDir, { recursive: true });
for (let length = 3; length <= 8; length += 1) {
  const bucket = sorted.filter((word) => word.length === length);
  fs.writeFileSync(
    path.join(outputDir, `accepted_words_${length}.json`),
    JSON.stringify({ schemaVersion: 1, length, words: bucket }),
  );
  console.log(`${length} letras: ${bucket.length}`);
}
console.log(`Total: ${sorted.length}`);
