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
