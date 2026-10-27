// Run: node --test web/tests/
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import * as core from "../js/core.js";

const bank = JSON.parse(readFileSync(new URL("../../App/Resources/words_de_tr.json", import.meta.url)));
const index = new Map(bank.words.map((w) => [w.id, w]));

function seeded(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

test("FSRS matches the Swift implementation", () => {
  const now = Date.UTC(2026, 9, 23, 8);
  const card = core.schedule(null, core.RATING.good, now);
  assert.equal(card.phase, "review");
  assert.ok(Math.abs(card.stability - 3.173) < 1e-9);
  assert.equal((card.due - now) / 86_400_000, 3);
  assert.ok(Math.abs(core.retrievability(10, 10) - 0.9) < 1e-4);

  let c = card;
  let previous = c.due - now;
  for (let i = 0; i < 5; i++) {
    const at = c.due;
    c = core.schedule(c, core.RATING.good, at);
    assert.ok(c.due - at > previous);
    previous = c.due - at;
  }
  const forgotten = core.schedule(c, core.RATING.again, c.due);
  assert.equal(forgotten.phase, "relearning");
  assert.equal(forgotten.lapses, 1);
  assert.ok(forgotten.stability < c.stability);
});

test("answer checking is Turkish-aware and tolerant", () => {
  assert.equal(core.checkAnswer("IŞIK", ["ışık"]).verdict, "correct");
  assert.equal(core.checkAnswer("ogretmen", ["öğretmen"]).verdict, "diacritics");
  assert.equal(core.checkAnswer("arabe", ["araba"]).verdict, "typo");
  assert.equal(core.checkAnswer("ew", ["ev"]).verdict, "wrong");
  assert.equal(core.checkAnswer("das Haus", ["Haus", "das Haus"]).verdict, "correct");
});

test("standard mode walks A–Z and skips X/Y", () => {
  const progress = core.newProgress();
  core.ensurePlans(progress, bank, "2026-01-01", 23, seeded(1));
  const letters = Array.from({ length: 24 }, (_, i) => core.addDays("2026-01-01", i))
    .map((d) => core.letterFor(index.get(progress.plans[d].wordIDs[0]).native)).join("");
  assert.equal(letters, "ABCDEFGHIJKLMNOPQRSTUVWZ");
  const all = Object.values(progress.plans).flatMap((p) => p.wordIDs);
  assert.equal(new Set(all).size, all.length);
});

test("extra word goes to today and keeps the rotation", () => {
  const progress = core.newProgress();
  core.ensurePlans(progress, bank, "2026-01-01", 5, seeded(2));
  const tomorrowCursor = progress.plans["2026-01-02"].cursorBefore;
  core.addExtraWords(1, progress, bank, "2026-01-01", seeded(3));
  assert.equal(progress.plans["2026-01-01"].wordIDs.length, 2);
  assert.equal(progress.plans["2026-01-02"].cursorBefore, tomorrowCursor + 1);
});

test("daily session introduces, checks and repeats mistakes", () => {
  const progress = core.newProgress();
  const now = new Date(2026, 9, 23, 8).getTime();
  progress.plans[core.dayKey(new Date(now))] = { wordIDs: ["haus"], cursorBefore: 0 };
  const session = core.dailySession(progress, index, now, "words");
  assert.deepEqual(session.items.map((i) => i.kind), ["introduction", "chooseNative", "chooseTarget"]);
  session.advance(null);
  session.advance(core.RATING.again);
  assert.equal(session.items.length, 4);
});

test("vocabulary test counts only first attempts and repeats mistakes", () => {
  const progress = core.newProgress();
  const now = Date.now();
  for (const id of ["haus", "auto"]) core.record(progress, id, core.RATING.good, now);
  const ids = core.testWordIDs("all", progress, index, now);
  const t = new core.VocabularyTest("all", "toNative", "typing", ids, now, seeded(4));
  const first = t.current.wordID;
  t.record(false);
  t.record(true);
  assert.ok(t.inMistakesRound);
  assert.equal(t.current.wordID, first);
  assert.equal(t.current.kind, "chooseNative");
  assert.equal(t.isFirstAttempt, false);
  t.record(true);
  assert.ok(t.finished);
  assert.equal(t.score, 0.5);
  assert.deepEqual(t.mistakes, [first]);
});

test("statistics and calendar export", () => {
  const progress = core.newProgress({ onboardingCompleted: true });
  const now = new Date(2026, 9, 23, 7).getTime();
  core.ensurePlans(progress, bank, core.dayKey(new Date(now)), 29, seeded(5));
  core.record(progress, "haus", core.RATING.good, now);
  core.addStudyTime(progress, 90, now);
  const stats = core.statistics(progress, bank, index, now);
  assert.equal(stats.learned, 1);
  assert.equal(stats.totalSeconds, 90);
  assert.equal(stats.recent.length, 30);
  assert.ok(stats.coverage > 0);
  const ics = core.calendarICS(progress, index, "https://example.org/", now);
  assert.equal(ics.match(/BEGIN:VEVENT/g).length, 30);
  assert.match(ics, /BEGIN:VALARM/);
});

test("learn now moves a picked word to today without duplicates", () => {
  const progress = core.newProgress();
  core.ensurePlans(progress, bank, "2026-10-27", 5, seeded(9));
  const picked = progress.plans["2026-10-28"].wordIDs[0];
  assert.equal(core.addSpecificWord(picked, progress, bank, "2026-10-27", seeded(10)), true);
  assert.equal(progress.plans["2026-10-27"].wordIDs.at(-1), picked);
  const all = Object.values(progress.plans).flatMap((p) => p.wordIDs);
  assert.equal(new Set(all).size, all.length);
  assert.equal(core.plannedDays(progress)[picked], "2026-10-27");
  assert.equal(core.addSpecificWord(picked, progress, bank, "2026-10-27"), false);
  core.record(progress, "haus", core.RATING.good);
  assert.equal(core.addSpecificWord("haus", progress, bank, "2026-10-27"), false);
});

import * as tr from "../js/turkish.js";

test("conjugation matches the shared fixtures", () => {
  const cases = JSON.parse(readFileSync(new URL("../../Packages/VocaDayCore/Tests/VocaDayCoreTests/Fixtures/conjugations.json", import.meta.url)));
  const failures = [];
  for (const c of cases) {
    const verb = tr.parseVerb(c.verb);
    const form = verb.conjugate(c.tense, c.person);
    if (form !== c.form) failures.push(`${c.verb} ${c.tense} ${c.person}: ${form} ≠ ${c.form}`);
  }
  assert.deepEqual(failures, []);
  assert.equal(tr.parseVerb("ihtiyacı olmak"), null);
  assert.deepEqual(tr.parseVerb("gelmek").irregularities, ["aorist"]);
  assert.equal(tr.parseVerb("gelmek").breakdown("present", "ben"), "gel + iyorum");
  assert.match(tr.parseVerb("gelmek").explanation("aorist"), /gelir statt geler/);
});

import * as g from "../js/grammar.js";

test("grammar path, mastery and base-form rule", () => {
  const curriculum = JSON.parse(readFileSync(new URL("../../App/Resources/grammar_de_tr.json", import.meta.url)));
  const stages = curriculum.stages;
  const progress = core.newProgress();
  assert.equal(g.stageState(stages[0], stages, progress, index).kind, "open");
  assert.equal(g.stageState(stages[1], stages, progress, index).kind, "locked");
  for (const id of ["pronouns", "verbEndings", "presentEndings"]) g.recordGrammarSession(progress, id, 0.9);
  assert.match(g.stageState(stages[3], stages, progress, index).reason, /0\/3/);
  for (const id of ["gehen", "kommen", "machen", "essen"]) core.record(progress, id, core.RATING.good);
  assert.equal(g.stageState(stages[3], stages, progress, index).kind, "open");
  for (const stage of stages) {
    const items = g.stageItems(stage, progress, bank, index, seeded(40));
    assert.ok(items.length > 0, stage.id);
    for (const item of items) if (item.choices.length) assert.ok(item.choices.includes(item.answers[0]), `${stage.id} ${item.prompt}`);
  }
  const model = g.stageItems(stages[2], progress, bank, index, seeded(41));
  assert.ok(model.some((i) => i.answers.includes("geliyorum") && i.detail === "ich"));

  const session = new g.MasterySession([{ id: "a" }, { id: "b" }, { id: "c" }], 2, seeded(42));
  session.answer(false);
  let steps = 1;
  while (!session.finished && steps < 50) { session.answer(true); steps++; }
  assert.equal(steps, 7);
  assert.equal(session.mastered, 3);

  const arbeiten = { id: "x", rank: 1, native: "arbeiten", partOfSpeech: "verb", translation: "çalışmak", alternatives: [], exampleTarget: "Çok [çalışıyorum]." };
  const card = { stability: 20, difficulty: 5, due: 0, lastReview: 0, phase: "review", reps: 3, lapses: 0 };
  for (let i = 0; i < 20; i++) assert.ok(!["clozeChoice", "clozeType"].includes(core.pickKind(card, "sentences", arbeiten, Math.random, false)));
  assert.equal(core.clozeIsBaseForm(index.get("haus")), false);
  const items = g.vocabularyItems(["gehen"], bank, index, seeded(43));
  assert.ok(items[0].answers.includes("gitmek"));
  assert.match(items[0].detail, /unregelmäßig/);
});
