import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const sourcePath = path.join(toolDir, 'catalog_source.json');
const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const meanings = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'curated_meanings_ptbr.json'), 'utf8'),
);
const answers = new Set(source.records.map((item) => item.answer));
if (
  source.records.length !== 1000 ||
  Object.keys(meanings).length !== 1000 ||
  Object.keys(meanings).some((answer) => !answers.has(answer)) ||
  source.records.some((item) => typeof meanings[item.answer] !== 'string')
) {
  throw new Error('A curadoria de significados não cobre exatamente o catálogo.');
}
for (const item of source.records) item.meaning = meanings[item.answer];
fs.writeFileSync(sourcePath, `${JSON.stringify(source, null, 2)}\n`);
console.log('Os 1.000 significados editoriais foram aplicados à fonte.');
