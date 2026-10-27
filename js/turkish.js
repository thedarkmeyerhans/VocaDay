// Turkish conjugation for the web app. Mirrors Packages/VocaDayCore/Sources/VocaDayCore/Turkish.swift.

export const PERSONS = [
  { id: "ben", german: "ich" }, { id: "sen", german: "du" }, { id: "o", german: "er/sie/es" },
  { id: "biz", german: "wir" }, { id: "siz", german: "ihr" }, { id: "onlar", german: "sie" },
];

export const TENSES = {
  present: { name: "Präsens", turkish: "Şimdiki zaman (-iyor)", cue: "jetzt" },
  past: { name: "Vergangenheit", turkish: "Geçmiş zaman (-di)", cue: "gestern" },
  future: { name: "Zukunft", turkish: "Gelecek zaman (-ecek)", cue: "morgen" },
  aorist: { name: "Breite Zeit", turkish: "Geniş zaman (-ir / -er)", cue: "immer / allgemein" },
};

const BACK = new Set(["a", "ı", "o", "u", "â", "û"]);
const FRONT = new Set(["e", "i", "ö", "ü", "î"]);
const ROUND = new Set(["o", "u", "ö", "ü", "û"]);
const VOICELESS = new Set(["ç", "f", "h", "k", "p", "s", "ş", "t"]);

const isVowel = (c) => BACK.has(c) || FRONT.has(c);
const lastVowel = (s) => [...s].reverse().find(isVowel);
export const harmonyA = (s) => (BACK.has(lastVowel(s)) ? "a" : "e");
export function harmonyI(s) {
  const v = lastVowel(s);
  if (!v) return "i";
  const back = BACK.has(v);
  const round = ROUND.has(v);
  return back ? (round ? "u" : "ı") : (round ? "ü" : "i");
}
const syllables = (s) => [...s].filter(isVowel).length;

export const AORIST_EXCEPTIONS = new Set(["al", "bil", "bul", "dur", "gel", "gör", "kal", "ol", "öl", "san", "ver", "var", "vur"]);
const SOFTENING = new Set(["git", "et", "tat", "güt", "dit", "kastet", "hisset", "kaybet", "emret", "affet", "bahset",
  "keşfet", "reddet", "seyret", "sabret", "kaydet", "hallet", "zannet", "hapset", "şükret", "terket"]);
export const NOT_CONJUGATABLE = new Set(["-ebilmek", "-abilmek", "zorunda olmak", "ihtiyacı olmak", "adı olmak",
  "anlamına gelmek", "hoşuna gitmek", "mal olmak", "eksik olmak", "ait olmak", "tadı olmak", "yağmur yağmak", "kar yağmak", "kanamak",
  "yetmek", "acımak", "elinde tutmak", "yanına almak", "lezzetli olmak", "aklına gelmek", "başına gelmek",
  "ihtiyaç duymak", "gerekmek"]);

const lower = (t) => [...t].map((c) => (c === "I" ? "ı" : c === "İ" ? "i" : c.toLowerCase())).join("");
const soft = (s) => (s.endsWith("t") ? `${s.slice(0, -1)}d` : s);

export const IRREGULARITY_TITLES = { aorist: "Breite Zeit unregelmäßig", softening: "t wird zu d", vowelChange: "e wird zu i" };

/** Parses a dictionary form like "gelmek" or "yardım etmek"; null if not conjugatable. */
export function parseVerb(phrase) {
  const text = lower(phrase.trim());
  if (!text || NOT_CONJUGATABLE.has(text) || !(text.endsWith("mak") || text.endsWith("mek"))) return null;
  const words = text.split(" ");
  const last = words.at(-1);
  if (last.length <= 3 || !/^\p{L}+$/u.test(last)) return null;
  const stem = last.slice(0, -3);
  if (!lastVowel(stem)) return null;
  return makeVerb(words.slice(0, -1).map((w) => `${w} `).join(""), last, stem);
}

function makeVerb(prefix, infinitive, stem) {
  const softens = SOFTENING.has(stem);
  const narrows = stem === "de" || stem === "ye";
  const aoristIrregular = AORIST_EXCEPTIONS.has(stem);
  const irregularities = [aoristIrregular && "aorist", softens && "softening", narrows && "vowelChange"].filter(Boolean);

  function present(p) {
    let base;
    if (narrows) base = `${stem.slice(0, -1)}i`;
    else {
      base = softens ? soft(stem) : stem;
      const last = base.at(-1);
      if (isVowel(last)) {
        if (last === "a" || last === "e") {
          base = base.slice(0, -1);
          base += harmonyI(base);
        }
      } else base += harmonyI(base);
    }
    return `${base}yor${["um", "sun", "", "uz", "sunuz", "lar"][p]}`;
  }

  function past(p) {
    const c = VOICELESS.has(stem.at(-1)) ? "t" : "d";
    const v = harmonyI(stem);
    const a = harmonyA(v);
    const base = stem + c + v;
    return [base + "m", base + "n", base, base + "k", `${base}n${v}z`, `${base}l${a}r`][p];
  }

  function future(p) {
    let base = narrows ? `${stem.slice(0, -1)}i` : softens ? soft(stem) : stem;
    const back = harmonyA(base) === "a";
    if (isVowel(base.at(-1))) base += "y";
    const suffixes = back
      ? ["acağım", "acaksın", "acak", "acağız", "acaksınız", "acaklar"]
      : ["eceğim", "eceksin", "ecek", "eceğiz", "eceksiniz", "ecekler"];
    return base + suffixes[p];
  }

  function aorist(p) {
    let base;
    if (isVowel(stem.at(-1))) base = `${stem}r`;
    else {
      const s = softens ? soft(stem) : stem;
      const rootSyllables = softens && stem.endsWith("et") ? 1 : syllables(stem);
      base = aoristIrregular || rootSyllables > 1 ? `${s}${harmonyI(s)}r` : `${s}${harmonyA(s)}r`;
    }
    const i = harmonyI(base);
    const a = harmonyA(base);
    return [`${base}${i}m`, `${base}s${i}n`, base, `${base}${i}z`, `${base}s${i}n${i}z`, `${base}l${a}r`][p];
  }

  const forms = { present, past, future, aorist };
  const conjugate = (tense, person) => prefix + forms[tense](typeof person === "number" ? person : PERSONS.findIndex((x) => x.id === person));

  function stemBefore(tense) {
    if (tense === "past") return stem;
    if (tense === "aorist") return softens ? soft(stem) : stem;
    if (narrows) return stem.slice(0, -1);
    if (softens) return soft(stem);
    if (tense === "present" && (stem.at(-1) === "a" || stem.at(-1) === "e")) return stem.slice(0, -1);
    return stem;
  }

  return {
    prefix, infinitive, stem, irregularities,
    dictionaryForm: prefix + infinitive,
    ending: infinitive.slice(-3),
    isIrregular: irregularities.length > 0,
    conjugate,
    breakdown(tense, person) {
      const index = typeof person === "number" ? person : PERSONS.findIndex((x) => x.id === person);
      const full = forms[tense](index);
      const base = stemBefore(tense);
      return `${base} + ${full.slice(base.length)}`;
    },
    explanation(kind) {
      if (kind === "aorist") return `Breite Zeit: ${prefix}${aorist(2)} statt ${prefix}${stem}${harmonyA(stem)}r – eines der 13 Verben mit -ir.`;
      if (kind === "softening") return `Vor einem Vokal wird t zu d: ${prefix}${present(0)}, aber ${prefix}${past(0)}.`;
      return `Vor -yor und -yecek wird e zu i: ${prefix}${present(0)}, ${prefix}${future(0)}.`;
    },
  };
}

/** The conjugatable verb behind a word entry, or null. */
export function verbOf(word) {
  return word.partOfSpeech === "verb" ? parseVerb(word.translation) : null;
}
