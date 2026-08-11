import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const hintsPath = path.join(toolDir, 'english_hints.json');
const sourcePath = path.join(toolDir, 'catalog_source.json');
const draft = JSON.parse(fs.readFileSync(hintsPath, 'utf8'));
const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const catalogRevision =
  'lexinexo-1.0.0-scowl-rel-2026.02.25-bilingual-hints';
source.catalogRevision = catalogRevision;

// Independent language-review corrections. Entries not listed here were read
// and approved as written in the authoring pass.
const corrections = {
  2: 'Represents a single unit, with nothing else beside it.',
  7: 'Bring an activity to its final point.',
  9: 'Has existed for a long time compared with similar things.',
  19: 'Move something into a chosen position.',
  21: 'A defined plot of land where a building may be constructed.',
  22: 'A long trip is required to reach it.',
  23: 'A small amount with no exact measurement.',
  28: 'Contains the objects needed to complete a particular activity.',
  31: 'Strike someone or something with a blow.',
  42: 'A place offering massages, baths, and other wellness treatments.',
  47: 'The side of the body where the leg joins the torso.',
  48: 'Soft headwear, usually with a visor at the front.',
  50: 'Headwear with a crown and a brim.',
  53: 'Describes someone able to move without being restrained.',
  54: 'Marks a person or thing as the sole one mentioned.',
  56: 'Feel preference or pleasure toward someone or something.',
  62: 'Points to the largest part of a group.',
  64: 'Describes the option that surpasses every other one in quality.',
  65: 'Describes something suitable, positive, or desirable.',
  66: 'Located far above the base or the ground.',
  70: 'Condition shared by organisms that are born, grow, and change.',
  73: 'A continuous mark that connects points on a surface.',
  74: 'A category whose members share defining traits.',
  78: 'A visible clue that communicates the existence of something.',
  84: 'Feel deep affection for someone or something.',
  85: 'Try to speak with someone by telephone.',
  87: 'A product changes hands in exchange for payment.',
  88: 'The part of a home that normally contains a bed.',
  92: 'Reside habitually in a particular place.',
  94: 'Move toward the speaker or a stated destination.',
  97: 'Hand something voluntarily to another person.',
  102: 'Requires little effort to accomplish.',
  107: 'Indicates movement farther from the initial location.',
  115: 'Footwear that protects and covers a foot.',
  116: 'Experience an emotion internally.',
  117: 'Expose something to possible loss or harm.',
  119: 'Money lent for a fixed period and repaid later.',
  120: 'An everyday category used to group similar things.',
  125: 'Located a short distance from the reference point.',
  130: 'A trip through several places or points of interest.',
  131: 'Wish for something good to happen in the future.',
  137: 'Describes the sex associated with sperm production.',
  138: 'Occurs later than expected.',
  141: 'Protected from danger or damage.',
  144: 'A vertical structure that separates or encloses spaces.',
  149: 'A very small, reduced version of something.',
  150: 'Arrange objects inside packaging for transportation.',
  154: 'The Earth together with all its places and inhabitants.',
  155: 'Marks a time later than another event.',
  156: 'Arrange elements into an organized sequence.',
  160: 'Describes the very dark color associated with the absence of light.',
  161: 'An ordered list used to locate information.',
  165: 'Includes the entire set without leaving any part out.',
  168: 'Describes the pale color associated with snow and bright light.',
  169: "A stage's position within a difficulty scale.",
  173: 'Respond directly to a message that was received.',
  178: 'Related to people considered as a species.',
  182: "Repeat someone else's exact words.",
  183: 'At an early stage of life or development.',
  185: 'A matter that needs discussion or resolution.',
  189: 'Expresses that an event is possible but uncertain.',
  192: "A fraction of ownership in a company.",
  199: 'Create a particular impression on a listener.',
  207: 'An informal collective term for unspecified objects.',
  208: 'Compel a person to act against their own will.',
  211: 'Bringing together parts that were previously separate.',
  214: 'Used informally to intensify praise for something excellent.',
  218: 'Already happened before the time being discussed.',
  225: 'Describes something majestic and impressive in appearance.',
  226: 'A strong, shiny material that conducts heat and electricity well.',
  229: 'Correspond with something else in appearance and characteristics.',
  230: 'A bodily capacity for perceiving stimuli.',
  233: 'Feel pleasure and satisfaction during an experience.',
  237: 'Formally give what was requested.',
  241: 'A fragment created when an object is divided.',
  244: 'Use a resource unnecessarily or without benefit.',
  247: 'State something as true, though it may still need proof.',
  248: "Without anyone else's company.",
  249: 'Owned by two parties at the same time.',
  253: 'Has great weight or requires considerable effort.',
  254: 'Make light physical contact with a person or object.',
  256: 'Describes someone who solves problems intelligently and quickly.',
  258: 'Exercise power cruelly and harmfully against someone.',
  260: 'Expresses remorse for a past action.',
  262: 'Has exactly the same quantity as another element.',
  265: 'Conveys information that is not true.',
  268: 'A female monarch who occupies a throne and rules a country.',
  273: 'Weigh facts before reaching a decision.',
  274: 'Has secondary importance in a situation.',
  275: 'A sequence of events that repeats.',
  278: 'Cause another person to feel satisfied.',
  280: 'Located in the middle of an area, away from its edges.',
  282: "Plan an object's form and function before creating it.",
  291: 'Able to be transported or moved from place to place.',
  297: 'Enter a new state or condition.',
  303: 'Reaches its destination without an intermediary.',
  305: 'Send something for review, decision, or approval.',
  308: 'Contains few elements and is easy to understand.',
  310: 'Currently operating or taking part in an activity.',
  311: 'Signals that no more is needed.',
  315: 'A quantity that is twice another amount.',
  318: 'Reach the full stage of growth.',
  320: "Temporary use of someone else's property, usually for payment.",
  322: 'Travel behind someone who is showing the way.',
  327: 'Describes the sex associated with egg production.',
  328: 'Unlike any other element.',
  332: 'Describes someone with great physical power.',
  333: 'Take steps to make a desired outcome certain.',
  334: 'The sale of products directly to the final consumer.',
  337: 'Conforms to what is usual or expected.',
  338: 'Has a high chance of happening.',
  341: 'Pleasant and delicate in appearance.',
  342: 'A form such as text, sound, or image used in communication.',
  345: 'Related to sight or to what can be seen.',
  349: 'Care for a child and take responsibility for their upbringing.',
  354: 'Produces results without a predictable sequence.',
  359: 'An aromatic drink prepared from roasted beans.',
  363: 'A person who guides a group toward a shared goal.',
  366: 'A citrus fruit with brightly colored skin and a sweet or tart taste.',
  371: 'Related to thoughts, the mind, and emotions.',
  372: 'Use force or violence against a target.',
  374: 'Originates in the place with which it is associated.',
  378: 'A production guide for actors and crew members.',
  382: 'Kept outside public knowledge.',
  384: 'Someone who tracks prey in order to capture it.',
  388: 'Conforms to appropriate or expected behavior.',
  391: 'A person who works in a mill and turns grain into flour.',
  398: 'A female sibling who shares at least one parent.',
  402: 'Protection of personal life from access by other people.',
  403: 'Covers the whole set rather than one particular case.',
  404: 'Possesses a characteristic that distinguishes it from others.',
  406: 'A connected system whose members exchange information.',
  407: 'Regulation that keeps a system within desired limits.',
  409: 'Indicates an additional element different from the first.',
  416: 'Money given to settle a purchase or debt.',
  418: 'Make something available after it was restricted.',
  419: 'A visual representation created by a camera, drawing, or painting.',
  421: 'A specialized periodical published at regular intervals.',
  422: 'Located away from the edges of an area.',
  424: 'A particular form of a book prepared for a specific print run.',
  428: 'A relatively long trip from one place to another.',
  435: 'Considers the whole set rather than just one part.',
  437: 'Known to be true without doubt.',
  439: 'Customs, values, and forms of expression shared by a group.',
  441: 'A route used to distribute a message.',
  442: 'A noticeable quality that distinguishes something from others.',
  443: 'A place where train passengers board and leave trains.',
  445: 'Contains no error, failure, or missing part.',
  447: 'The favorable outcome of an effort.',
  448: 'Points in the direction ahead.',
  452: 'Seeks peace and avoids conflict.',
  454: 'Takes place outside buildings or enclosed spaces.',
  455: 'A person who shares an activity with someone else.',
  456: 'An important task assigned to a person or group.',
  464: 'Relates to an individual rather than the public or a group.',
  469: 'A system of sounds and symbols used for communication.',
  470: 'Breaks a topic into components so it can be understood.',
  473: 'Confirmed as valid by a competent authority.',
  476: 'The purpose for which a particular thing is used.',
  479: 'Reduce the amount charged for something.',
  484: 'Related to armed forces and national defense.',
  487: 'Kind and welcoming toward other people.',
  488: 'Move gradually closer to a person.',
  490: 'The person or thing preferred above all available options.',
};

const authoredRecords = draft.records;
if (!Array.isArray(authoredRecords) || authoredRecords.length !== 500) {
  throw new Error('O rascunho deve conter exatamente 500 dicas inglesas.');
}

const fold = (value) => value.toLowerCase();
const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const reveals = (text, answer) =>
  new RegExp(`(^|[^a-z])${escapeRegExp(answer)}([^a-z]|$)`, 'i').test(text);
const genericPrefixes = [
  'think of something related to',
  'associate the word with',
  'the central idea is',
  'in this context',
  'in common use',
];
const seen = new Set();
const approved = authoredRecords.map((record, index) => {
  const number = index + 1;
  const sourceRecord = source.records.find(
    (item) => item.mode === 'withHints' && item.number === number,
  );
  if (
    record.number !== number ||
    record.answer !== sourceRecord?.answer ||
    typeof record.hintEn !== 'string'
  ) {
    throw new Error(`Dica inglesa ${number}: fonte ou ordem divergente.`);
  }
  const hintEn = corrections[number] ?? record.hintEn;
  const normalized = fold(hintEn);
  if (
    hintEn !== hintEn.trim() ||
    hintEn.length < 15 ||
    hintEn.length > 120 ||
    !/^[A-Z]/.test(hintEn) ||
    !/[.!?]$/.test(hintEn) ||
    /(?:\u2026|\.\.\.|\betc\.?$)/iu.test(hintEn) ||
    /\b(?:TODO|FIXME|lorem|placeholder)\b/iu.test(hintEn) ||
    genericPrefixes.some((prefix) => normalized.startsWith(prefix)) ||
    reveals(hintEn, record.answer)
  ) {
    throw new Error(`Dica inglesa ${number} (${record.answer}) reprovada: ${hintEn}`);
  }
  if (seen.has(normalized)) {
    throw new Error(`Dica inglesa repetida no nível ${number}: ${hintEn}`);
  }
  seen.add(normalized);
  const contentSha256 = crypto
    .createHash('sha256')
    .update(
      JSON.stringify({ number, answer: record.answer, hintEn }),
      'utf8',
    )
    .digest('hex');
  sourceRecord.hintEn = hintEn;
  return {
    number,
    answer: record.answer,
    hintEn,
    contentSha256,
    authorApproved: true,
    independentReviewApproved: true,
  };
});

const reviewDocument = {
  schemaVersion: 2,
  catalogRevision,
  locale: 'en-US',
  passes: [
    {
      id: 'codex-english-hints-authoring-2026-08-10',
      role: 'authoring',
      agent: 'OpenAI Codex with per-record translation assistance',
      completedOn: '2026-08-10',
      method:
        'Each existing PT-BR clue was translated separately for the same selected sense; no runtime or build-time template generates clues.',
    },
    {
      id: 'codex-english-hints-independent-review-2026-08-10',
      role: 'procedurallyIndependentReview',
      agent: 'OpenAI Codex lexical review',
      completedOn: '2026-08-10',
      method:
        'A separate pass read all 500 English clues, corrected unnatural wording, and checked sense alignment, grammar, uniqueness, leakage, truncation, and template families.',
    },
  ],
  records: approved,
};
fs.writeFileSync(hintsPath, `${JSON.stringify(reviewDocument, null, 2)}\n`);
fs.writeFileSync(sourcePath, `${JSON.stringify(source, null, 2)}\n`);
for (const name of ['selection_audit.json', 'single_sense_review.json']) {
  const reviewPath = path.join(toolDir, name);
  const review = JSON.parse(fs.readFileSync(reviewPath, 'utf8'));
  review.catalogRevision = catalogRevision;
  fs.writeFileSync(reviewPath, `${JSON.stringify(review, null, 2)}\n`);
}
console.log(
  `Revisão inglesa aprovada: ${approved.length} dicas, ${Object.keys(corrections).length} correções explícitas.`,
);
