// Grammar path and mastery practice for the web app.
// Mirrors Packages/VocaDayCore/Sources/VocaDayCore/Grammar.swift.
import { accepted, distractors, normalize, shuffle, withArticle, parseCloze } from "./core.js";
import { PERSONS, TENSES, parseVerb, verbOf, harmonyA } from "./turkish.js";

/** Practice until every item was answered correctly `target` times in a row. */
export class MasterySession {
  constructor(items, target = 2, random = Math.random) {
    this.items = items;
    this.target = Math.max(1, target);
    this.byId = new Map(items.map((i) => [i.id, i]));
    this.queue = shuffle(items.map((i) => i.id), random);
    this.position = 0;
    this.streaks = {};
    this.firstTry = {};
    this.answers = 0;
    this.correctAnswers = 0;
  }

  get current() { return this.position < this.queue.length ? this.byId.get(this.queue[this.position]) : null; }
  get finished() { return this.current == null; }
  get currentStreak() { const c = this.current; return c ? this.streaks[c.id] ?? 0 : 0; }
  get isFirstAttempt() { const c = this.current; return c ? !(c.id in this.firstTry) : false; }
  get mastered() { return this.items.filter((i) => (this.streaks[i.id] ?? 0) >= this.target).length; }
  get progress() {
    if (!this.items.length) return 1;
    return this.items.reduce((a, i) => a + Math.min(this.streaks[i.id] ?? 0, this.target), 0) / (this.items.length * this.target);
  }
  get firstTryScore() {
    const v = Object.values(this.firstTry);
    return v.length ? v.filter(Boolean).length / v.length : 0;
  }

  answer(correct) {
    const item = this.current;
    if (!item) return;
    this.answers++;
    if (correct) this.correctAnswers++;
    if (!(item.id in this.firstTry)) this.firstTry[item.id] = correct;
    const streak = correct ? (this.streaks[item.id] ?? 0) + 1 : 0;
    this.streaks[item.id] = streak;
    if (streak < this.target) {
      const gap = correct ? 4 : 2;
      this.queue.splice(Math.min(this.queue.length, this.position + 1 + gap), 0, item.id);
    }
    this.position++;
  }
}

export function learnedVerbs(progress, index) {
  const seen = new Set();
  return Object.entries(progress.cards).sort((a, b) => b[1].lastReview - a[1].lastReview)
    .map(([id]) => index.get(id)).filter(Boolean)
    .map((w) => [w, verbOf(w)]).filter(([, v]) => v && !seen.has(v.dictionaryForm) && seen.add(v.dictionaryForm));
}

export function stageState(stage, stages, progress, index) {
  const grammar = progress.grammar ?? {};
  if (grammar[stage.id]?.completedAt) return { kind: "completed" };
  const i = stages.indexOf(stage);
  if (i > 0 && !grammar[stages[i - 1].id]?.completedAt) {
    return { kind: "locked", reason: `Schließe zuerst „${stages[i - 1].title}“ ab.` };
  }
  const verbs = learnedVerbs(progress, index).length;
  if (verbs < stage.requiresVerbs) {
    return { kind: "locked", reason: `Lerne zuerst ${stage.requiresVerbs} Verben (${verbs}/${stage.requiresVerbs}).` };
  }
  return { kind: "open" };
}

export const inflectionUnlocked = (progress) => Boolean(progress.grammar?.present?.completedAt);

export function recordGrammarSession(progress, stageID, score, now = Date.now()) {
  progress.grammar ??= {};
  const r = progress.grammar[stageID] ?? { completedAt: null, sessions: 0, bestFirstTry: 0 };
  r.sessions++;
  r.bestFirstTry = Math.max(r.bestFirstTry, score);
  r.completedAt ??= now;
  progress.grammar[stageID] = r;
}

const IRREGULAR_TITLES = { aorist: "Breite Zeit unregelmäßig", softening: "t wird zu d", vowelChange: "e wird zu i" };

function conjugationItem(verb, german, tense, person, wordID = null, random = Math.random) {
  const form = verb.conjugate(tense, person);
  const options = new Set([form]);
  for (const p of shuffle([0, 1, 2, 3, 4, 5], random)) if (options.size < 4) options.add(verb.conjugate(tense, p));
  let explanation = verb.breakdown(tense, person);
  const irregular = verb.irregularities.find((k) => tense === "aorist" || k !== "aorist");
  if (irregular) explanation += ` · ${IRREGULAR_TITLES[irregular]}`;
  const p = PERSONS[person];
  return {
    id: `conj-${tense}-${verb.dictionaryForm}-${p.id}`,
    kicker: `${TENSES[tense].name} · ${TENSES[tense].cue}`,
    prompt: `${p.id} + ${verb.dictionaryForm}`,
    detail: `${p.german}${german ? ` (${german})` : ""}`,
    answers: [form, `${p.id} ${form}`],
    choices: shuffle([...options], random),
    explanation, speech: form, wordID, lang: "tr",
  };
}

function germanMeaning(verb, bank) {
  return bank.words.find((w) => w.partOfSpeech === "verb" && normalize(w.translation) === verb.dictionaryForm)?.native ?? null;
}

export function stageItems(stage, progress, bank, index, random = Math.random) {
  if (stage.kind === "pronouns") {
    const pairs = [["ich", "ben"], ["du", "sen"], ["er / sie / es", "o"], ["wir", "biz"], ["ihr", "siz"], ["sie (Plural)", "onlar"], ["Sie (höflich)", "siz"]];
    const all = ["ben", "sen", "o", "biz", "siz", "onlar"];
    return pairs.map(([de, t]) => ({
      id: `pronoun-${de}`, kicker: "Personalpronomen", prompt: de, detail: "Wie heißt das auf Türkisch?",
      answers: [t], choices: shuffle([...shuffle(all.filter((x) => x !== t), random).slice(0, 3), t], random), speech: t, lang: "tr",
    }));
  }
  if (stage.kind === "verbEndings") {
    const verbs = learnedVerbs(progress, index).map(([, v]) => v).filter((v) => !v.prefix);
    for (const f of ["gelmek", "yapmak", "okumak", "görmek", "bilmek", "almak", "içmek", "konuşmak"]) {
      if (verbs.length >= 8) break;
      const v = parseVerb(f);
      if (!verbs.some((x) => x.dictionaryForm === v.dictionaryForm)) verbs.push(v);
    }
    return shuffle(verbs, random).slice(0, 8).map((v, i) => {
      const german = germanMeaning(v, bank);
      if (i % 2 === 0) {
        const last = [...v.stem].reverse().find((c) => "aıoueiöüâî".includes(c));
        return {
          id: `ending-${v.infinitive}`, kicker: "-mak oder -mek?", prompt: `${v.stem}___`,
          detail: german ? `${german} – welche Endung? Achte auf den letzten Vokal.` : null,
          answers: [v.ending], choices: ["mak", "mek"], explanation: `Letzter Vokal „${last}“ → ${v.infinitive}`, speech: v.infinitive, lang: "tr",
        };
      }
      const distract = [v.infinitive.slice(0, -1), `${v.stem}m`, v.stem.slice(0, -1)].filter((x) => x && x !== v.stem);
      return {
        id: `stem-${v.infinitive}`, kicker: "Wie lautet der Stamm?", prompt: v.infinitive,
        detail: german ? `${german} – ohne -mak / -mek` : null, answers: [v.stem],
        choices: shuffle([...distract.slice(0, 3), v.stem], random), explanation: `${v.stem} + ${v.ending}`, speech: v.infinitive, lang: "tr",
      };
    });
  }
  if (stage.kind === "modelConjugation") {
    const items = [];
    (stage.modelVerbs ?? ["gelmek"]).map(parseVerb).forEach((v, i) => {
      const persons = i === 0 ? [0, 1, 2, 3, 4, 5] : shuffle([0, 1, 2, 3, 4, 5], random).slice(0, 3);
      for (const p of persons) items.push(conjugationItem(v, null, stage.tense, p, null, random));
    });
    return items;
  }
  let verbs = shuffle(learnedVerbs(progress, index), random);
  if (stage.tense === "aorist") verbs.sort((a, b) => Number(b[1].irregularities.includes("aorist")) - Number(a[1].irregularities.includes("aorist")));
  verbs = verbs.slice(0, 6);
  const items = [];
  let persons = shuffle([0, 1, 2, 3, 4, 5], random);
  for (const [w, v] of verbs) {
    for (let k = 0; k < (verbs.length < 4 ? 3 : 2); k++) {
      if (!persons.length) persons = shuffle([0, 1, 2, 3, 4, 5], random);
      items.push(conjugationItem(v, w.native, stage.tense, persons.shift(), w.id, random));
    }
  }
  return items;
}

/** Consolidation practice ("Festigen"): German prompt, Turkish dictionary form. */
export function vocabularyItems(ids, bank, index, random = Math.random) {
  return ids.map((id) => index.get(id)).filter(Boolean).map((w) => {
    const others = distractors(w, bank.words, (x) => x.translation, 3, random);
    const v = verbOf(w);
    return {
      id: `word-${w.id}`, kicker: "Wie heißt das auf Türkisch?", prompt: withArticle(w),
      detail: `${w.partOfSpeech === "noun" ? "Nomen" : w.partOfSpeech === "verb" ? "Verb" : ""}${v?.isIrregular ? " · unregelmäßig" : ""}`.replace(/^ · /, ""),
      answers: accepted(w), choices: shuffle([...others.map((x) => x.translation), w.translation], random),
      explanation: parseCloze(w.exampleTarget).plain, speech: w.translation, wordID: w.id, lang: "tr",
    };
  });
}

export { harmonyA };
