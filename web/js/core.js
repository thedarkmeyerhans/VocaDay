// VocaDay learning logic for the web app.
// Mirrors Packages/VocaDayCore (Swift); keep both in sync.

// MARK: Days

/** Local calendar day as "YYYY-MM-DD". */
export function dayKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function keyToDate(key) {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function addDays(key, days) {
  const date = keyToDate(key);
  date.setDate(date.getDate() + days);
  return dayKey(date);
}

const DAY_MS = 86_400_000;

// MARK: Text

export function lowerTR(text) {
  let out = "";
  for (const ch of text) {
    if (ch === "I") out += "ı";
    else if (ch === "İ") out += "i";
    else out += ch.toLowerCase();
  }
  return out;
}

const FOLD = { ç: "c", ğ: "g", ı: "i", ö: "o", ş: "s", ü: "u", â: "a", î: "i", û: "u", ä: "a", ß: "s" };

export function foldDiacritics(text) {
  return [...text].map((ch) => FOLD[ch] ?? ch).join("");
}

export function normalize(text) {
  return lowerTR(text.normalize("NFC"))
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

export function levenshtein(a, b) {
  const x = [...a];
  const y = [...b];
  if (!x.length) return y.length;
  if (!y.length) return x.length;
  let prev = Array.from({ length: y.length + 1 }, (_, i) => i);
  for (let i = 1; i <= x.length; i++) {
    const cur = [i];
    for (let j = 1; j <= y.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] === y[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[y.length];
}

/** @returns {{verdict: "correct"|"diacritics"|"typo"|"wrong", expected: string}} */
export function checkAnswer(input, accepted) {
  const answer = normalize(input);
  const candidates = accepted.map((a) => ({ original: a, norm: normalize(a) }));
  const primary = candidates[0]?.original ?? "";
  if (candidates.some((c) => c.norm === answer)) return { verdict: "correct", expected: primary };
  if (!answer) return { verdict: "wrong", expected: primary };
  const folded = foldDiacritics(answer);
  const dia = candidates.find((c) => foldDiacritics(c.norm) === folded);
  if (dia) return { verdict: "diacritics", expected: dia.original };
  for (const c of candidates) {
    const f = foldDiacritics(c.norm);
    const allowed = [...f].length >= 8 ? 2 : [...f].length >= 4 ? 1 : 0;
    if (allowed > 0 && levenshtein(folded, f) <= allowed) return { verdict: "typo", expected: c.original };
  }
  return { verdict: "wrong", expected: primary };
}

export const RATING = { again: 1, hard: 2, good: 3, easy: 4 };
export const RATING_NAMES = { 1: "Nochmal", 2: "Schwer", 3: "Gut", 4: "Leicht" };

export function ratingForVerdict(verdict) {
  return verdict === "correct" ? RATING.good : verdict === "wrong" ? RATING.again : RATING.hard;
}

// MARK: Words

export function parseCloze(raw) {
  const open = raw.indexOf("[");
  const close = raw.indexOf("]", open);
  if (open < 0 || close < 0) return { before: raw, answer: "", after: "", plain: raw, hasGap: false };
  const before = raw.slice(0, open);
  const answer = raw.slice(open + 1, close);
  const after = raw.slice(close + 1);
  return { before, answer, after, plain: before + answer + after, hasGap: answer.length > 0 };
}

export function withArticle(word) {
  return word.article ? `${word.article} ${word.native}` : word.native;
}

export function accepted(word) {
  return [word.translation, ...(word.alternatives ?? [])];
}

export const POS_NAMES = {
  noun: "Nomen", verb: "Verb", adjective: "Adjektiv", adverb: "Adverb", pronoun: "Pronomen",
  preposition: "Präposition", conjunction: "Konjunktion", numeral: "Zahlwort", interjection: "Ausruf",
  phrase: "Wendung", other: "Sonstiges",
};

export const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
const UMLAUT = { Ä: "A", Ö: "O", Ü: "U" };

export function letterFor(native) {
  const first = [...native][0]?.toUpperCase();
  if (!first) return null;
  const letter = UMLAUT[first] ?? first;
  return LETTERS.includes(letter) ? letter : null;
}

// MARK: Standard mode (A–Z)

/**
 * Picks `count` words: a random one among the `candidates` most frequent
 * remaining words of the current letter, then the next letter. Letters without
 * words are skipped; after Z it starts again at A.
 */
export function pickWords(count, words, excluded, state, random = Math.random, candidates = 8) {
  const buckets = new Map();
  for (const w of words) {
    if (excluded.has(w.id)) continue;
    const letter = letterFor(w.native);
    if (!letter) continue;
    if (!buckets.has(letter)) buckets.set(letter, []);
    buckets.get(letter).push(w);
  }
  for (const list of buckets.values()) list.sort((a, b) => a.rank - b.rank);

  const n = LETTERS.length;
  state.cursor = ((state.cursor % n) + n) % n;
  const picked = [];
  while (picked.length < count) {
    let found = false;
    for (let i = 0; i < n; i++) {
      const letter = LETTERS[state.cursor];
      state.cursor = (state.cursor + 1) % n;
      const bucket = buckets.get(letter);
      if (!bucket || !bucket.length) continue;
      const window = Math.min(candidates, bucket.length);
      picked.push(bucket.splice(Math.floor(random() * window), 1)[0]);
      found = true;
      break;
    }
    if (!found) break;
  }
  return picked;
}

// MARK: Progress

export function newProgress(settings = {}) {
  return {
    version: 1,
    settings: {
      newWordsPerDay: 1, notificationHour: 8, notificationMinute: 0, desiredRetention: 0.9,
      mixSentenceExercises: true, onboardingCompleted: false, ...settings,
    },
    letterCursor: 0,
    plans: {},
    cards: {},
    stats: {},
    tests: [],
  };
}

function plannedOrLearned(progress) {
  const ids = new Set(Object.keys(progress.cards));
  for (const plan of Object.values(progress.plans)) plan.wordIDs.forEach((id) => ids.add(id));
  return ids;
}

function pickForPlan(progress, bank, count, random) {
  const state = { cursor: progress.letterCursor };
  const words = pickWords(count, bank.words, plannedOrLearned(progress), state, random);
  progress.letterCursor = state.cursor;
  return words;
}

export function ensurePlans(progress, bank, today, daysAhead = 29, random = Math.random) {
  for (let i = 0; i <= daysAhead; i++) {
    const day = addDays(today, i);
    if (progress.plans[day]) continue;
    const cursorBefore = progress.letterCursor;
    const words = pickForPlan(progress, bank, progress.settings.newWordsPerDay, random);
    progress.plans[day] = { wordIDs: words.map((w) => w.id), cursorBefore };
  }
}

function dropFuture(progress, today) {
  const future = Object.keys(progress.plans).filter((d) => d > today).sort();
  if (future.length) progress.letterCursor = progress.plans[future[0]].cursorBefore;
  for (const d of future) delete progress.plans[d];
}

export function replanFuture(progress, bank, today, random = Math.random) {
  dropFuture(progress, today);
  ensurePlans(progress, bank, today, 29, random);
}

export function addExtraWords(count, progress, bank, today, random = Math.random) {
  dropFuture(progress, today);
  const plan = progress.plans[today] ?? { wordIDs: [], cursorBefore: progress.letterCursor };
  const words = pickForPlan(progress, bank, count, random);
  plan.wordIDs.push(...words.map((w) => w.id));
  progress.plans[today] = plan;
  ensurePlans(progress, bank, today, 29, random);
  return words;
}

export const isIntroduced = (progress, id) => Boolean(progress.cards[id]);

export function pendingNewWords(progress, upTo) {
  return Object.keys(progress.plans).filter((d) => d <= upTo).sort()
    .flatMap((d) => progress.plans[d].wordIDs.filter((id) => !isIntroduced(progress, id)));
}

export function dueWordIDs(progress, now = Date.now()) {
  return Object.entries(progress.cards).filter(([, c]) => c.due <= now)
    .sort((a, b) => a[1].due - b[1].due).map(([id]) => id);
}

export function streak(progress, today) {
  let day = today;
  if (!(progress.stats[day]?.reviews > 0)) day = addDays(day, -1);
  let count = 0;
  while (progress.stats[day]?.reviews > 0) {
    count++;
    day = addDays(day, -1);
  }
  return count;
}

function dayStats(progress, day) {
  progress.stats[day] ??= { reviews: 0, correct: 0, newWords: 0, seconds: 0, reviewTotal: 0, reviewCorrect: 0 };
  return progress.stats[day];
}

export function record(progress, id, rating, now = Date.now()) {
  const previous = progress.cards[id] ?? null;
  progress.cards[id] = schedule(previous, rating, now, progress.settings.desiredRetention);
  const s = dayStats(progress, dayKey(new Date(now)));
  s.reviews++;
  if (rating !== RATING.again) s.correct++;
  if (!previous) s.newWords++;
  if (previous?.phase === "review") {
    s.reviewTotal++;
    if (rating !== RATING.again) s.reviewCorrect++;
  }
}

export function addStudyTime(progress, seconds, now = Date.now()) {
  if (!(seconds > 0)) return;
  dayStats(progress, dayKey(new Date(now))).seconds += Math.min(seconds, 7200);
}

// MARK: FSRS-5

export const FSRS_W = [
  0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925,
  1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
];
const DECAY = -0.5;
const FACTOR = 19 / 81;
const w = FSRS_W;
const clampD = (d) => Math.min(Math.max(d, 1), 10);

export function retrievability(elapsedDays, stability) {
  return Math.pow(1 + (FACTOR * Math.max(0, elapsedDays)) / stability, DECAY);
}

export function cardRecall(card, now = Date.now()) {
  return retrievability((now - card.lastReview) / DAY_MS, card.stability);
}

export function intervalDays(stability, retention = 0.9) {
  const raw = (stability / FACTOR) * (Math.pow(retention, 1 / DECAY) - 1);
  return Math.min(Math.max(Math.round(raw), 1), 3650);
}

const initS = (g) => Math.max(w[g - 1], 0.1);
const initD = (g) => clampD(w[4] - Math.exp(w[5] * (g - 1)) + 1);

function nextD(d, g) {
  const damped = d + (-w[6] * (g - 3) * (10 - d)) / 9;
  return clampD(w[7] * initD(4) + (1 - w[7]) * damped);
}

function recallS(d, s, r, g) {
  const hard = g === 2 ? w[15] : 1;
  const easy = g === 4 ? w[16] : 1;
  return s * (Math.exp(w[8]) * (11 - d) * Math.pow(s, -w[9]) * (Math.exp(w[10] * (1 - r)) - 1) * hard * easy + 1);
}

function forgetS(d, s, r) {
  const longTerm = w[11] * Math.pow(d, -w[12]) * (Math.pow(s + 1, w[13]) - 1) * Math.exp(w[14] * (1 - r));
  return Math.min(longTerm, s / Math.exp(w[17] * w[18]));
}

function shortTermS(s, g) {
  let inc = Math.exp(w[17] * (g - 3 + w[18]));
  if (g >= 3) inc = Math.max(inc, 1);
  return s * inc;
}

/** New memory state after answering with rating 1–4 (card null = first time). */
export function schedule(card, g, now = Date.now(), retention = 0.9) {
  let s;
  let d;
  let lapses = card?.lapses ?? 0;
  if (!card) {
    s = initS(g);
    d = initD(g);
  } else {
    const elapsed = (now - card.lastReview) / DAY_MS;
    d = nextD(card.difficulty, g);
    if (elapsed < 1) s = shortTermS(card.stability, g);
    else {
      const r = retrievability(elapsed, card.stability);
      s = g === 1 ? forgetS(card.difficulty, card.stability, r) : recallS(card.difficulty, card.stability, r, g);
    }
    if (g === 1 && card.phase === "review") lapses++;
  }
  s = Math.max(s, 0.1);
  const prev = card?.phase ?? null;
  let phase;
  let due;
  if (g === 1) {
    phase = prev === "review" || prev === "relearning" ? "relearning" : "learning";
    due = now + 60_000;
  } else if (g === 2 && prev !== "review") {
    phase = prev ?? "learning";
    due = now + 300_000;
  } else {
    phase = "review";
    due = now + intervalDays(s, retention) * DAY_MS;
  }
  return { stability: s, difficulty: d, due, lastReview: now, phase, reps: (card?.reps ?? 0) + 1, lapses };
}

export const isMature = (card) => card.phase === "review" && card.stability >= 21;

// MARK: Exercises

export const KIND_TITLES = {
  introduction: "Neues Wort",
  chooseNative: "Was bedeutet das?",
  chooseTarget: "Wie heißt das auf Türkisch?",
  typeTarget: "Schreib das Wort",
  typeNative: "Wie heißt das auf Deutsch?",
  flashcard: "Erinnerst du dich?",
  clozeChoice: "Welches Wort fehlt?",
  clozeType: "Ergänze den Satz",
  sentenceBuilder: "Bilde den Satz",
};

const CAP_GOOD = new Set(["chooseNative", "chooseTarget", "clozeChoice"]);
export const capRating = (kind, rating) => (CAP_GOOD.has(kind) ? Math.min(rating, RATING.good) : rating);

export function pickKind(card, style, word, random = Math.random) {
  const canSentence = parseCloze(word.exampleTarget).hasGap;
  const wantsSentence = style === "sentences" ? canSentence : style === "mixed" ? canSentence && random() < 0.5 : false;
  if (!card) return wantsSentence ? "clozeChoice" : "chooseNative";
  const s = card.stability;
  if (wantsSentence) {
    if (s < 3 || card.phase !== "review") return "clozeChoice";
    if (s < 14) return "clozeType";
    return random() < 0.5 ? "sentenceBuilder" : "clozeType";
  }
  if (card.phase !== "review") return "chooseTarget";
  if (s < 4) return random() < 0.5 ? "chooseTarget" : "flashcard";
  return random() < 0.5 ? "typeTarget" : "flashcard";
}

export function retryKind(kind) {
  return { typeTarget: "chooseTarget", flashcard: "chooseTarget", typeNative: "chooseNative",
    clozeType: "clozeChoice", sentenceBuilder: "clozeChoice", chooseTarget: "chooseNative" }[kind] ?? kind;
}

export function shuffle(list, random = Math.random) {
  const a = [...list];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Up to `count` distractors, same part of speech and similar frequency, never synonyms. */
export function distractors(word, words, answerOf, count = 3, random = Math.random) {
  const meanings = new Set(accepted(word).map(normalize));
  const native = normalize(word.native);
  const isSynonym = (o) => normalize(o.native) === native || accepted(o).some((a) => meanings.has(normalize(a)));
  const others = words.filter((o) => o.id !== word.id && !isSynonym(o));
  const near = shuffle(others.filter((o) => o.partOfSpeech === word.partOfSpeech)
    .sort((a, b) => Math.abs(a.rank - word.rank) - Math.abs(b.rank - word.rank)).slice(0, 60), random);
  const seen = new Set([normalize(answerOf(word))]);
  const result = [];
  for (const c of [...near, ...shuffle(others, random)]) {
    if (result.length >= count) break;
    const key = normalize(answerOf(c));
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push(c);
  }
  return result;
}

// MARK: Sessions

export class Session {
  constructor(items, newWordIDs = []) {
    this.items = items;
    this.newWordIDs = newWordIDs;
    this.position = 0;
    this.answered = 0;
    this.correct = 0;
    this.retries = {};
    this.nextId = items.length;
  }

  get current() { return this.items[this.position] ?? null; }
  get finished() { return this.position >= this.items.length; }
  get progress() { return this.items.length ? this.position / this.items.length : 1; }
  get remaining() { return Math.max(0, this.items.length - this.position); }

  advance(rating) {
    const item = this.current;
    if (!item) return;
    if (rating != null) {
      this.answered++;
      if (rating !== RATING.again) this.correct++;
      const count = this.retries[item.wordID] ?? 0;
      if (rating === RATING.again && count < 3) {
        this.retries[item.wordID] = count + 1;
        this.insert(item.wordID, retryKind(item.kind), 3);
      } else if (rating === RATING.hard && count < 3 && this.newWordIDs.includes(item.wordID)) {
        this.retries[item.wordID] = count + 1;
        this.insert(item.wordID, item.kind, 5);
      }
    }
    this.position++;
  }

  insert(wordID, kind, gap) {
    const index = Math.min(this.items.length, this.position + 1 + gap);
    this.items.splice(index, 0, { id: this.nextId++, wordID, kind });
  }
}

export function dailySession(progress, index, now, style, includeNew = true, maxReviews = 60, random = Math.random) {
  const today = dayKey(new Date(now));
  const newIDs = includeNew ? pendingNewWords(progress, today).filter((id) => index.get(id)) : [];
  let reviews = dueWordIDs(progress, now).filter((id) => index.get(id) && !newIDs.includes(id)).slice(0, maxReviews)
    .map((id, i) => ({ id: 1000 + i, wordID: id, kind: pickKind(progress.cards[id], style, index.get(id), random) }));
  const queue = [];
  let n = 0;
  for (const id of newIDs) {
    const word = index.get(id);
    const hasGap = parseCloze(word.exampleTarget).hasGap;
    queue.push({ id: n++, wordID: id, kind: "introduction" });
    queue.push({ id: n++, wordID: id, kind: style === "sentences" && hasGap ? "clozeChoice" : "chooseNative" });
    queue.push(...reviews.slice(0, 2));
    reviews = reviews.slice(2);
  }
  queue.push(...reviews);
  for (const id of newIDs) {
    const hasGap = parseCloze(index.get(id).exampleTarget).hasGap;
    queue.push({ id: n++, wordID: id, kind: style !== "words" && hasGap ? "clozeChoice" : "chooseTarget" });
  }
  queue.forEach((item, i) => { item.id = i; });
  return new Session(queue, newIDs);
}

export function practiceSession(progress, index, now, style, count = 12, random = Math.random) {
  const ids = Object.keys(progress.cards).filter((id) => index.get(id))
    .sort((a, b) => cardRecall(progress.cards[a], now) - cardRecall(progress.cards[b], now)).slice(0, count);
  const items = shuffle(ids, random).map((id, i) => ({ id: i, wordID: id, kind: pickKind(progress.cards[id], style, index.get(id), random) }));
  return new Session(items, []);
}

// MARK: Vocabulary test (mastery loop)

export const SCOPES = {
  all: { name: "Alle Wörter" },
  weakest: { name: "Die 20 schwächsten" },
  random: { name: "20 zufällige" },
  recent: { name: "Diese Woche" },
  mistakes: { name: "Fehler üben" },
};

export function testWordIDs(scope, progress, index, now = Date.now(), ids = [], random = Math.random) {
  const learned = Object.keys(progress.cards).filter((id) => index.get(id));
  switch (scope) {
    case "weakest":
      return learned.sort((a, b) => cardRecall(progress.cards[a], now) - cardRecall(progress.cards[b], now)).slice(0, 20);
    case "random":
      return shuffle(learned, random).slice(0, 20);
    case "recent": {
      const today = dayKey(new Date(now));
      const start = addDays(today, -6);
      return Object.keys(progress.plans).filter((d) => d >= start && d <= today).sort()
        .flatMap((d) => progress.plans[d].wordIDs).filter((id) => progress.cards[id] && index.get(id));
    }
    case "mistakes":
      return ids.filter((id) => progress.cards[id] && index.get(id));
    default:
      return learned;
  }
}

export class VocabularyTest {
  constructor(scope, direction, mode, ids, now = Date.now(), random = Math.random) {
    this.scope = scope;
    this.direction = direction;
    this.mode = mode;
    this.startedAt = now;
    this.items = shuffle(ids, random).map((wordID, i) => {
      const toTarget = direction === "toTarget" || (direction === "mixed" && random() < 0.5);
      const kind = mode === "choice" ? (toTarget ? "chooseTarget" : "chooseNative") : (toTarget ? "typeTarget" : "typeNative");
      return { id: i, wordID, kind };
    });
    this.wordCount = this.items.length;
    this.position = 0;
    this.first = {};
    this.attempts = {};
  }

  get current() { return this.items[this.position] ?? null; }
  get finished() { return this.position >= this.items.length; }
  get inMistakesRound() { return this.position >= this.wordCount && !this.finished; }
  get progress() { return this.items.length ? this.position / this.items.length : 1; }
  get isFirstAttempt() { const c = this.current; return c ? !(c.wordID in this.first) : false; }
  get correctFirstTry() { return Object.values(this.first).filter(Boolean).length; }
  get answeredFirstTry() { return Object.keys(this.first).length; }
  get mistakes() { return this.items.slice(0, this.wordCount).map((i) => i.wordID).filter((id) => this.first[id] === false); }
  get score() { return this.wordCount ? this.correctFirstTry / this.wordCount : 0; }

  record(correct) {
    const item = this.current;
    if (!item) return;
    if (!(item.wordID in this.first)) this.first[item.wordID] = correct;
    const count = (this.attempts[item.wordID] ?? 0) + 1;
    this.attempts[item.wordID] = count;
    if (!correct && count < 3) this.items.push({ id: this.items.length, wordID: item.wordID, kind: retryKind(item.kind) });
    this.position++;
  }

  result(now = Date.now()) {
    return {
      id: `${now}`, date: now, scope: this.scope, direction: this.direction, mode: this.mode,
      total: this.wordCount, correctFirstTry: this.correctFirstTry, seconds: (now - this.startedAt) / 1000,
      mistakes: this.mistakes,
    };
  }
}

export function grade(score) {
  if (score >= 0.9) return "Ausgezeichnet";
  if (score >= 0.75) return "Sehr gut";
  if (score >= 0.6) return "Gut";
  if (score >= 0.4) return "Weiter üben";
  return "Dranbleiben";
}

// MARK: Statistics

export function statistics(progress, bank, index, now = Date.now()) {
  const today = dayKey(new Date(now));
  const cards = Object.entries(progress.cards).filter(([id]) => index.get(id));
  const stages = { learning: 0, young: 0, mature: 0 };
  for (const [, c] of cards) stages[c.phase !== "review" ? "learning" : isMature(c) ? "mature" : "young"]++;

  const emptyStats = { reviews: 0, correct: 0, newWords: 0, seconds: 0, reviewTotal: 0, reviewCorrect: 0 };
  const day = (key) => ({ key, date: keyToDate(key), stats: { ...emptyStats, ...(progress.stats[key] ?? {}) } });
  const recent = Array.from({ length: 30 }, (_, i) => day(addDays(today, i - 29)));

  const sinceMonday = (new Date(now).getDay() + 6) % 7;
  const heatStart = addDays(today, -(17 * 7 + sinceMonday));
  const heatmap = Array.from({ length: 17 * 7 + sinceMonday + 1 }, (_, i) => day(addDays(heatStart, i)));

  const forecast = Array.from({ length: 14 }, (_, i) => {
    const key = addDays(today, i);
    const count = cards.filter(([, c]) => {
      const due = dayKey(new Date(c.due));
      return i === 0 ? due <= key : due === key;
    }).length;
    return { key, date: keyToDate(key), count };
  });

  const totals = {};
  const learnedPer = {};
  for (const w of bank.words) {
    const l = letterFor(w.native);
    if (!l) continue;
    totals[l] = (totals[l] ?? 0) + 1;
    if (progress.cards[w.id]) learnedPer[l] = (learnedPer[l] ?? 0) + 1;
  }
  const letters = LETTERS.filter((l) => totals[l]).map((l) => ({ letter: l, learned: learnedPer[l] ?? 0, total: totals[l] }));

  const sum = (list, key) => list.reduce((a, d) => a + d.stats[key], 0);
  const activeKeys = Object.keys(progress.stats).filter((k) => progress.stats[k].reviews > 0).sort();
  let longest = 0;
  let run = 0;
  let prev = null;
  for (const k of activeKeys) {
    run = prev && addDays(prev, 1) === k ? run + 1 : 1;
    longest = Math.max(longest, run);
    prev = k;
  }
  const allStats = Object.values(progress.stats);
  const learnedFreq = cards.reduce((a, [id]) => a + (index.get(id)?.frequency ?? 0), 0);
  const bankFreq = bank.words.reduce((a, w) => a + (w.frequency ?? 0), 0);
  const reviewTotal = sum(recent, "reviewTotal");
  const reviews30 = sum(recent, "reviews");

  return {
    totalWords: bank.words.length,
    learned: cards.length,
    stages,
    plannedAhead: Object.entries(progress.plans).filter(([d]) => d > today).reduce((a, [, p]) => a + p.wordIDs.length, 0),
    currentStreak: streak(progress, today),
    longestStreak: longest,
    activeDays: activeKeys.length,
    totalReviews: allStats.reduce((a, s) => a + (s.reviews ?? 0), 0),
    totalSeconds: allStats.reduce((a, s) => a + (s.seconds ?? 0), 0),
    averageStability: cards.length ? cards.reduce((a, [, c]) => a + c.stability, 0) / cards.length : 0,
    accuracy30: reviews30 ? sum(recent, "correct") / reviews30 : null,
    retention30: reviewTotal ? sum(recent, "reviewCorrect") / reviewTotal : null,
    retentionSamples30: reviewTotal,
    desiredRetention: progress.settings.desiredRetention,
    coverage: Math.min(1, learnedFreq / 1e6),
    maximumCoverage: Math.min(1, bankFreq / 1e6),
    recent,
    heatmap,
    forecast,
    letters,
    tests: progress.tests,
  };
}

// MARK: Calendar export

function icsDate(date) {
  const p = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}${p(date.getMonth() + 1)}${p(date.getDate())}T${p(date.getHours())}${p(date.getMinutes())}00`;
}

function icsEscape(text) {
  return text.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");
}

/** Calendar events with the planned word(s) of each day and an alert. */
export function calendarICS(progress, index, appURL, now = Date.now(), days = 30) {
  const today = dayKey(new Date(now));
  const { notificationHour: h, notificationMinute: m } = progress.settings;
  const lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//VocaDay//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH"];
  for (let i = 0; i < days; i++) {
    const key = addDays(today, i);
    const words = (progress.plans[key]?.wordIDs ?? []).map((id) => index.get(id)).filter(Boolean);
    const start = keyToDate(key);
    start.setHours(h, m, 0, 0);
    if (start.getTime() < now) continue;
    const end = new Date(start.getTime() + 15 * 60_000);
    const title = words.length
      ? `VocaDay: ${words.map((w) => `${w.translation} – ${withArticle(w)}`).join(", ")}`
      : "VocaDay: Zeit zum Wiederholen";
    const description = words.map((w) => `${w.translation} – ${withArticle(w)}\n${parseCloze(w.exampleTarget).plain}\n${w.exampleNative}`).join("\n\n");
    lines.push(
      "BEGIN:VEVENT",
      `UID:vocaday-${key}@vocaday`,
      `DTSTAMP:${icsDate(new Date(now))}`,
      `DTSTART:${icsDate(start)}`,
      `DTEND:${icsDate(end)}`,
      `SUMMARY:${icsEscape(title)}`,
      `DESCRIPTION:${icsEscape(description + (appURL ? `\n\n${appURL}` : ""))}`,
      appURL ? `URL:${appURL}` : "",
      "BEGIN:VALARM", "ACTION:DISPLAY", `DESCRIPTION:${icsEscape(title)}`, "TRIGGER:PT0M", "END:VALARM",
      "END:VEVENT",
    );
  }
  lines.push("END:VCALENDAR");
  return lines.filter(Boolean).join("\r\n") + "\r\n";
}
