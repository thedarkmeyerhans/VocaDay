// VocaDay web app (PWA). Same learning system as the native app, see core.js.
import * as C from "./core.js";

const STORE_KEY = "vocaday.progress.v1";
const app = document.getElementById("app");
const overlayRoot = document.getElementById("overlay");

const state = {
  bank: null,
  index: new Map(),
  progress: null,
  tab: "today",
  overlay: null,
  search: "",
  wordsMode: "letters",
  wordsLetter: null,
  showAllLetter: false,
  historyDays: 14,
  onboardingStep: 0,
  draft: null,
};

// MARK: Helpers

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const pct = (v) => `${Math.round(v * 100)} %`;
const today = () => C.dayKey(new Date());
const word = (id) => state.index.get(id);
const COLORS = {
  coral: "#ff8a5c", red: "#e0453a", sun: "#ffd166", correct: "#2eb872", wrong: "#e5484d", almost: "#f5a524",
  review: "#3b82f6", sentence: "#8b5cf6", test: "#14b8a6", practice: "#f59e0b", streak: "#ff7a1a",
};
const ARTICLE = { der: "var(--der)", die: "var(--die)", das: "var(--das)" };

const ICONS = {
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>',
  bubble: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
  chart: '<path d="M18 20V10M12 20V4M6 20v-6"/>',
  books: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>',
  sliders: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
  speaker: '<path d="M11 5 6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07M19.07 4.93a10 10 0 0 1 0 14.14"/>',
  play: '<path d="M7 4l13 8-13 8z" fill="currentColor"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  x: '<path d="M18 6 6 18M6 6l12 12"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  flame: '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
  checklist: '<path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>',
  shuffle: '<path d="M16 3h5v5M4 20 21 3M21 16v5h-5M15 15l6 6M4 4l5 5"/>',
  refresh: '<path d="M23 4v6h-6M1 20v-6h6"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>',
  calendar: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  book: '<path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2zM22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>',
  star: '<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>',
  bulb: '<path d="M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2z"/>',
  chevron: '<path d="M9 18l6-6-6-6"/>',
  target: '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
  share: '<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8M16 6l-4-4-4 4M12 2v13"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
  upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
  trash: '<path d="M3 6h18M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6M10 11v6M14 11v6M9 6V4h6v2"/>',
  keyboard: '<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10"/>',
  list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
  grad: '<path d="M22 10 12 5 2 10l10 5 10-5z"/><path d="M6 12v5c3 3 9 3 12 0v-5"/>',
  bell: '<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0"/>',
  layers: '<path d="M12 2 2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>',
  back: '<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-1"/>',
  info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
};

function ic(name, size = 22, extra = "") {
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" ${extra}>${ICONS[name] ?? ""}</svg>`;
}

function gradIcon(name, color, cls = "") {
  return `<div class="icon ${cls}" style="background:linear-gradient(135deg, color-mix(in srgb, ${color} 80%, white), ${color})">${ic(name, cls === "sm" ? 18 : cls === "lg" ? 28 : 22)}</div>`;
}

function ring(progress, size, stroke, colors = [COLORS.coral, COLORS.red], label = "") {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const id = `g${Math.random().toString(36).slice(2, 8)}`;
  const p = Math.min(Math.max(progress, 0), 1);
  return `<div class="ring" style="width:${size}px;height:${size}px">
    <svg width="${size}" height="${size}"><defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${colors[0]}"/><stop offset="1" stop-color="${colors[1]}"/></linearGradient></defs>
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="${colors[1]}" stroke-opacity="0.15" stroke-width="${stroke}"/>
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="url(#${id})" stroke-width="${stroke}" stroke-dasharray="${c}" stroke-dashoffset="${c}" data-offset="${c * (1 - p)}"/>
    </svg><div class="label">${label}</div></div>`;
}

function animateRings(root) {
  requestAnimationFrame(() => requestAnimationFrame(() => {
    root.querySelectorAll(".ring circle[data-offset]").forEach((el) => { el.style.strokeDashoffset = el.dataset.offset; });
  }));
}

function articleWord(w) {
  return w.article ? `<b style="color:${ARTICLE[w.article]}">${esc(w.article)}</b> ${esc(w.native)}` : esc(w.native);
}

function highlighted(w) {
  const z = C.parseCloze(w.exampleTarget);
  return `${esc(z.before)}<mark>${esc(z.answer)}</mark>${esc(z.after)}`;
}

function speakButton(text, white = false) {
  return `<button class="speak ${white ? "white" : ""}" data-action="speak" data-text="${esc(text)}" aria-label="Vorlesen">${ic("speaker", 19)}</button>`;
}

function duration(sec) {
  const s = Math.round(sec);
  if (s < 60) return `${s} Sek`;
  const m = Math.floor(s / 60);
  return m < 60 ? `${m} Min` : `${Math.floor(m / 60)} Std ${m % 60} Min`;
}

function relative(ms) {
  const diff = ms - Date.now();
  if (diff <= 0) return "jetzt fällig";
  const rtf = new Intl.RelativeTimeFormat("de", { numeric: "auto" });
  const min = diff / 60000;
  if (min < 60) return rtf.format(Math.round(min), "minute");
  if (min < 1440) return rtf.format(Math.round(min / 60), "hour");
  return rtf.format(Math.round(min / 1440), "day");
}

function intervalLabel(ms) {
  const m = ms / 60000;
  if (m < 60) return `${Math.max(1, Math.round(m))} Min`;
  if (m < 1440) return `${Math.round(m / 60)} Std`;
  const d = m / 1440;
  if (d < 31) return `${Math.round(d)} T`;
  if (d < 365) return `${Math.round(d / 30)} Mon`;
  return `${(d / 365).toFixed(1)} J`;
}

let voices = [];
function loadVoices() { voices = window.speechSynthesis?.getVoices?.() ?? []; }
loadVoices();
window.speechSynthesis?.addEventListener?.("voiceschanged", loadVoices);

function speak(text, lang = "tr-TR", slow = false) {
  const synth = window.speechSynthesis;
  if (!synth) return;
  synth.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.lang = lang;
  u.voice = voices.find((v) => v.lang?.toLowerCase().startsWith(lang.slice(0, 2))) ?? null;
  u.rate = slow ? 0.6 : 0.9;
  synth.speak(u);
}

function vibrate(ok) { navigator.vibrate?.(ok ? 15 : [30, 40, 30]); }

function toast(text) {
  document.querySelector(".toast")?.remove();
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = text;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2600);
}

function confetti() {
  const box = document.createElement("div");
  box.className = "confetti";
  const colors = Object.values(COLORS);
  for (let i = 0; i < 90; i++) {
    const p = document.createElement("i");
    p.style.left = `${Math.random() * 100}%`;
    p.style.background = colors[i % colors.length];
    p.style.animationDuration = `${2 + Math.random() * 2}s`;
    p.style.animationDelay = `${Math.random() * 0.8}s`;
    p.style.transform = `rotate(${Math.random() * 360}deg)`;
    box.appendChild(p);
  }
  document.body.appendChild(box);
  setTimeout(() => box.remove(), 5000);
}

// MARK: Storage

function load() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (error) {
    console.warn("progress unreadable", error);
  }
  return C.newProgress();
}

let plannedCache = null;

/** Word ids planned for any day (cached until the next save). */
function plannedSet() {
  plannedCache ??= new Set(Object.values(P().plans).flatMap((p) => p.wordIDs));
  return plannedCache;
}

function save() {
  plannedCache = null;
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state.progress));
  } catch (error) {
    toast("Speichern fehlgeschlagen – ist der Speicher voll?");
  }
}

function ensurePlans() {
  C.ensurePlans(state.progress, state.bank, today());
  save();
}

// MARK: Derived state

const P = () => state.progress;
const isStandalone = () => window.navigator.standalone === true || window.matchMedia("(display-mode: standalone)").matches;

function todaysWords() {
  const missed = C.pendingNewWords(P(), C.addDays(today(), -1));
  return [...missed, ...(P().plans[today()]?.wordIDs ?? [])].map(word).filter(Boolean);
}
const pendingNew = () => C.pendingNewWords(P(), today()).filter(word);
const dueCount = () => C.dueWordIDs(P()).filter(word).length;
const learnedCount = () => Object.keys(P().cards).filter(word).length;
const hasWork = () => pendingNew().length > 0 || dueCount() > 0;
const reviewsToday = () => P().stats[today()]?.reviews ?? 0;
const style = () => (P().settings.mixSentenceExercises ? "mixed" : "words");

function todayProgress() {
  const done = reviewsToday();
  const open = pendingNew().length * 3 + dueCount();
  return done + open === 0 ? 0 : done / (done + open);
}

function nextLetter() {
  const words = todaysWords();
  const w = words.find((x) => !C.isIntroduced(P(), x.id)) ?? words[0];
  return w ? C.letterFor(w.native) : C.LETTERS[P().letterCursor % 26];
}

function status(w) {
  const card = P().cards[w.id];
  if (!card) {
    return plannedSet().has(w.id)
      ? { key: "upcoming", name: "Geplant", color: "#8e8e93" }
      : { key: "new", name: "Noch nicht dran", color: "#d1d1d6" };
  }
  if (C.isMature(card)) return { key: "mature", name: "Gefestigt", color: COLORS.correct };
  if (card.phase !== "review") return { key: "learning", name: "Lernend", color: COLORS.practice };
  return { key: "review", name: "Wiederholen", color: COLORS.review };
}

// MARK: Rendering

function render() {
  if (!P().settings.onboardingCompleted) {
    app.innerHTML = renderOnboarding();
    overlayRoot.innerHTML = "";
    return;
  }
  const screens = { today: renderToday, practice: renderPractice, stats: renderStats, words: renderWords, settings: renderSettings };
  app.innerHTML = screens[state.tab]() + renderTabbar();
  animateRings(app);
  renderOverlay();
}

function renderTabbar() {
  const tabs = [["today", "sun", "Heute"], ["practice", "bubble", "Üben"], ["stats", "chart", "Statistik"], ["words", "books", "Wörter"], ["settings", "sliders", "Einstellungen"]];
  return `<nav class="tabbar">${tabs.map(([key, icon, label]) => `<button class="${state.tab === key ? "active" : ""}" data-action="tab" data-tab="${key}">${ic(icon, 24)}<span>${label}</span></button>`).join("")}</nav>`;
}

function titleBar(title, extra = "") {
  return `<div class="title-bar"><h1>${title}</h1><div class="spacer"></div>${extra}</div>`;
}

// Today

function greeting() {
  const h = new Date().getHours();
  if (h >= 5 && h < 11) return ["Günaydın!", "Guten Morgen"];
  if (h >= 11 && h < 18) return ["İyi günler!", "Guten Tag"];
  return ["İyi akşamlar!", "Guten Abend"];
}

function renderToday() {
  const [tr, de] = greeting();
  const date = new Date().toLocaleDateString("de-DE", { weekday: "long", day: "numeric", month: "long" });
  const words = todaysWords();
  const work = hasWork();
  const newCount = pendingNew().length;
  const due = dueCount();
  const summary = [newCount ? (newCount === 1 ? "1 neues Wort" : `${newCount} neue Wörter`) : "", due ? (due === 1 ? "1 Wiederholung" : `${due} Wiederholungen`) : ""].filter(Boolean).join(" · ");
  const learned = learnedCount();
  const stats = C.statistics(P(), state.bank, state.index);

  const wordsHTML = words.length
    ? words.map((w, i) => (i === 0 ? heroCard(w) : compactCard(w))).join("")
    : `<div class="card secondary">Du hast alle Wörter der Datenbank geplant – stark!</div>`;

  const goal = `<div class="card pad row">
      ${ring(work ? todayProgress() : 1, 84, 11, [COLORS.coral, COLORS.red], work ? `<span class="small">${pct(todayProgress())}</span>` : `<span style="color:var(--correct)">${ic("check", 26)}</span>`)}
      <div class="stack tight" style="flex:1">
        <h3>${work ? "Tagesziel" : "Alles erledigt!"}</h3>
        <div class="small secondary">${work ? summary : "Deine Wörter sind für heute versorgt."}</div>
        ${work ? `<button class="btn" data-action="start-daily">${ic("play", 16)} ${newCount ? "Jetzt lernen" : "Wiederholen"}</button>` : ""}
      </div></div>`;

  const quick = `<div class="grid two">
      ${quickAction("extra-word", "plus", COLORS.coral, "Noch ein Wort", state.draft?.added ? `+ ${esc(state.draft.added)}` : "zusätzlich lernen")}
      ${quickAction("start-sentences", "bubble", COLORS.sentence, "Satztrainer", "Wörter im Satz", !learned)}
      ${quickAction("open-test", "checklist", COLORS.test, "Wortschatz-Test", "alle Wörter prüfen", !learned)}
      ${quickAction("start-free", "shuffle", COLORS.practice, "Freies Üben", "schwächste zuerst", !learned)}
    </div>`;

  const install = isStandalone() || localStorage.getItem("vocaday.hideInstall") ? "" : `<div class="card install row top">
      ${gradIcon("share", COLORS.review, "sm")}
      <div class="small"><b>Als App installieren:</b> Tippe in Safari auf <b>Teilen</b> ${ic("share", 14)} und dann auf <b>„Zum Home-Bildschirm“</b>. Dann startet VocaDay im Vollbild und deine Daten bleiben sicher gespeichert.</div>
      <button class="close-x" data-action="hide-install" aria-label="Hinweis ausblenden">${ic("x", 14)}</button></div>`;
  const lastBackup = Number(localStorage.getItem("vocaday.lastBackup") ?? 0);
  const snooze = Number(localStorage.getItem("vocaday.backupSnooze") ?? 0);
  const fortnight = 14 * 86_400_000;
  const backup = learned >= 10 && Date.now() - Math.max(lastBackup, snooze) > fortnight ? `<div class="card row top">
      ${gradIcon("download", COLORS.test, "sm")}<div class="small" style="flex:1"><b>Lernstand sichern?</b> ${learned} Wörter stecken schon in VocaDay. Eine Sicherung schützt sie, falls du das Gerät wechselst.
      <div class="row" style="margin-top:8px;gap:8px"><button class="pill" style="color:var(--test);font-size:13px" data-action="export">Jetzt sichern</button><button class="pill" style="color:var(--secondary);font-size:13px" data-action="backup-later">Später</button></div></div></div>` : "";

  const letter = nextLetter();
  const alphabet = `<div class="card stack tight">
      <h2>Dein Alphabet</h2><div class="small secondary">Jeden Tag der nächste Buchstabe – reihum von A bis Z</div>
      <div class="alphabet" id="alphabet">${stats.letters.map((l) => `<div class="l ${l.letter === letter ? "current" : ""}" data-letter="${l.letter}">
        ${ring(l.learned / l.total, 44, 4, l.letter === letter ? [COLORS.coral, COLORS.red] : [COLORS.review, COLORS.test], `<span style="${l.letter === letter ? "color:var(--red)" : ""}">${l.letter}</span>`)}
        <span class="caption secondary">${l.learned}</span></div>`).join("")}</div></div>`;

  return `<div class="screen stack">
    <div class="row" style="margin-top:8px">
      <div style="flex:1">
        <div class="caption secondary bold" style="text-transform:uppercase">${esc(date)}</div>
        <div style="font-size:34px;font-weight:800;letter-spacing:-0.5px">${tr}</div>
        <div class="small secondary">${de} · 🇩🇪 → 🇹🇷</div>
      </div>
      <button data-action="speak" data-text="${tr}" style="color:var(--sun);filter:drop-shadow(0 0 10px rgba(255,209,102,.7))">${ic("sun", 40)}</button>
    </div>
    ${install}
    ${backup}
    ${weekStrip()}
    <div class="today-columns">
      <div class="stack">
        <div><h2>${words.length > 1 ? "Deine Wörter für heute" : "Dein Wort des Tages"}</h2><div class="small secondary">Buchstabe ${letter} · aus den häufigsten Wörtern</div></div>
        ${wordsHTML}
      </div>
      <div class="stack">${goal}${quick}</div>
    </div>
    ${alphabet}
  </div>`;
}

function weekStrip() {
  const t = today();
  const monday = C.addDays(t, -((new Date().getDay() + 6) % 7));
  const names = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
  const s = C.streak(P(), t);
  const days = names.map((n, i) => {
    const key = C.addDays(monday, i);
    const on = (P().stats[key]?.reviews ?? 0) > 0;
    return `<div class="day ${key === t ? "today" : ""}">${n}<div class="dot ${on ? "on" : ""}">${on ? ic("check", 14) : ""}</div></div>`;
  }).join("");
  return `<div class="card week">
    <div class="flame"><span style="color:${s ? COLORS.streak : "var(--secondary)"}">${ic("flame", 26)}</span><div><b>${s}</b><div class="caption secondary">${s === 1 ? "Tag" : "Tage"}</div></div></div>
    ${days}</div>`;
}

function heroCard(w) {
  const learned = C.isIntroduced(P(), w.id);
  return `<div class="hero stack tight pressable" data-action="word" data-id="${w.id}" role="button">
    <div class="row"><span class="pill white">${C.POS_NAMES[w.partOfSpeech]}</span>${learned ? `<span class="pill white">${ic("check", 12)} gelernt</span>` : ""}<div class="spacer"></div>${speakButton(w.translation, true)}</div>
    <div class="big rounded">${esc(w.translation)}</div>
    <div class="sub">${esc(C.withArticle(w))}</div>
    <hr>
    <div style="font-weight:500">${highlighted(w)}</div>
    <div class="muted">${esc(w.exampleNative)}</div>
  </div>`;
}

function compactCard(w) {
  return `<div class="card row pressable" data-action="word" data-id="${w.id}" role="button">
    <div class="icon" style="background:var(--sunrise);font-weight:800">${esc(w.native[0].toUpperCase())}</div>
    <div style="flex:1"><div style="font-size:20px;font-weight:700">${esc(w.translation)}</div><div class="small secondary">${articleWord(w)}</div></div>
    ${C.isIntroduced(P(), w.id) ? `<span style="color:var(--correct)">${ic("check")}</span>` : ""}
    ${speakButton(w.translation)}
  </div>`;
}

function quickAction(action, icon, color, title, subtitle, disabled = false) {
  return `<button class="card qa pressable" data-action="${action}" ${disabled ? "disabled" : ""}>
    ${gradIcon(icon, color, "sm")}<div><div class="t">${title}</div><div class="caption secondary">${subtitle}</div></div></button>`;
}

// Practice

function renderPractice() {
  const due = dueCount();
  const learned = learnedCount();
  const last = P().tests.at(-1);
  const card = (action, icon, color, title, text, badge, disabled) => `<button class="card pad pressable stack" data-action="${action}" ${disabled ? "disabled" : ""}>
      <div class="row top">${gradIcon(icon, color, "lg")}<div class="spacer"></div>${badge ? `<span class="pill" style="color:${color};font-size:14px">${badge}</span>` : ""}</div>
      <div><h3 style="font-size:20px">${title}</h3><div class="small secondary">${text}</div></div>
      <div class="row"><div class="spacer"></div><span style="color:${color}">${ic("play", 26)}</span></div></button>`;
  return `<div class="screen stack">${titleBar("Üben")}
    <div class="grid">
      ${card("start-daily", "refresh", COLORS.review, "Tägliche Wiederholung", due ? `${due} Wörter sind jetzt dran.` : "Gerade ist nichts fällig – gut gemacht!", due || "", !hasWork())}
      ${card("open-test", "checklist", COLORS.test, "Wortschatz-Test", "Alle gelernten Wörter auf einmal abfragen – mit Auswertung und Fehlerrunde.", last ? pct(last.correctFirstTry / Math.max(1, last.total)) : "", !learned)}
      ${card("start-sentences", "bubble", COLORS.sentence, "Satztrainer", "Wörter aktiv im Satz verwenden: Lückentexte und Sätze bauen.", "", !learned)}
      ${card("start-free", "shuffle", COLORS.practice, "Freies Üben", "Die Wörter, die du am ehesten vergisst – auch wenn sie noch nicht fällig sind.", "", !learned)}
    </div>
    <button class="card row pressable" data-action="method">${gradIcon("grad", COLORS.coral)}<div style="flex:1"><h3>So lernst du mit VocaDay</h3><div class="small secondary">Die Wissenschaft hinter den Übungen</div></div><span class="secondary">${ic("chevron")}</span></button>
    ${learned ? "" : `<div class="small secondary">Lerne zuerst dein Wort des Tages im Tab „Heute“.</div>`}
  </div>`;
}

// Statistics

function renderStats() {
  const s = C.statistics(P(), state.bank, state.index);
  const tile = (icon, color, value, unit, label) => `<div class="card stack tight">${gradIcon(icon, color, "sm")}
      <div><span class="rounded" style="font-size:28px;font-weight:800">${value}</span> ${unit ? `<span class="caption secondary">${unit}</span>` : ""}</div><div class="small secondary">${label}</div></div>`;
  const card = (title, icon, color, body) => `<div class="card pad stack"><h3 class="row" style="color:${color};gap:8px">${ic(icon, 20)} ${title}</h3>${body}</div>`;

  const maxAct = Math.max(1, ...s.recent.map((d) => d.stats.reviews));
  const activity = `<div class="bars">${s.recent.map((d) => {
    const right = d.stats.correct / maxAct * 100;
    const wrong = (d.stats.reviews - d.stats.correct) / maxAct * 100;
    return `<div class="b" title="${d.key}: ${d.stats.reviews}" style="height:${Math.max(2, right + wrong)}%"><div style="height:${(right / Math.max(right + wrong, 0.001)) * 100}%;background:var(--correct)"></div><div style="flex:1;background:var(--wrong);opacity:.7"></div></div>`;
  }).join("")}</div><div class="axis"><span>${s.recent[0].date.toLocaleDateString("de-DE", { day: "numeric", month: "short" })}</span><span>heute</span></div>
  <div class="row caption secondary"><span>${s.recent.reduce((a, d) => a + d.stats.reviews, 0)} Antworten</span><div class="spacer"></div>${s.accuracy30 != null ? `<span>Trefferquote ${pct(s.accuracy30)}</span>` : ""}</div>`;

  const maxHeat = Math.max(1, ...s.heatmap.map((d) => d.stats.reviews));
  const weeks = [];
  for (let i = 0; i < s.heatmap.length; i += 7) weeks.push(s.heatmap.slice(i, i + 7));
  const heat = `<div class="heat"><div class="col">${["M", "D", "M", "D", "F", "S", "S"].map((l) => `<div class="lab">${l}</div>`).join("")}</div>
    ${weeks.map((week) => `<div class="col">${week.map((d) => `<div class="cell" style="${d.stats.reviews ? `background:color-mix(in srgb, var(--red) ${25 + (d.stats.reviews / maxHeat) * 75}%, transparent)` : ""}"></div>`).join("")}</div>`).join("")}</div>
    <div class="caption secondary">${s.activeDays} Lerntage</div>`;

  const maxF = Math.max(1, ...s.forecast.map((f) => f.count));
  const forecast = `<div class="bars" style="height:120px">${s.forecast.map((f) => `<div class="b" style="height:${Math.max(2, (f.count / maxF) * 100)}%;background:linear-gradient(var(--sentence), color-mix(in srgb, var(--sentence) 70%, white))" title="${f.count}"></div>`).join("")}</div>
    <div class="axis"><span>heute</span><span>${s.forecast.at(-1).date.toLocaleDateString("de-DE", { weekday: "short", day: "numeric" })}</span></div>
    <div class="caption secondary">So viele Wörter fragt die Wiederholungsplanung an den nächsten 14 Tagen ab.</div>`;

  const total = Math.max(1, s.learned);
  const a = (s.stages.learning / total) * 360;
  const b = a + (s.stages.young / total) * 360;
  const stages = s.learned ? `<div class="row" style="gap:20px">
      <div class="donut" style="background:conic-gradient(var(--practice) 0 ${a}deg, var(--review) ${a}deg ${b}deg, var(--correct) ${b}deg 360deg)"><div><div><b style="font-size:22px">${s.learned}</b><div class="caption secondary">Wörter</div></div></div></div>
      <div class="stack tight">${[["learning", "Lernend", "gerade neu oder vergessen", "var(--practice)"], ["young", "Jung", "sitzt für einige Tage", "var(--review)"], ["mature", "Gefestigt", "sitzt drei Wochen und länger", "var(--correct)"]]
        .map(([k, n, t, c]) => `<div class="row top" style="gap:8px"><span class="legend-dot" style="background:${c}"></span><div><div class="small bold">${n}: ${s.stages[k]}</div><div class="caption secondary">${t}</div></div></div>`).join("")}</div></div>`
    : `<div class="secondary">Noch keine Wörter gelernt.</div>`;

  const retention = s.retention30 != null && s.retentionSamples30 >= 5
    ? `<div><span class="rounded" style="font-size:40px;font-weight:800;color:var(--test)">${pct(s.retention30)}</span> <span class="small secondary bold">Ziel ${pct(s.desiredRetention)}</span></div>
       <div style="position:relative;height:12px;border-radius:99px;background:var(--fill)"><div style="height:100%;width:${s.retention30 * 100}%;border-radius:99px;background:var(--test)"></div><div style="position:absolute;top:-3px;left:calc(${s.desiredRetention * 100}% - 1px);width:2px;height:18px;background:var(--text)"></div></div>
       <div class="caption secondary">${Math.abs(s.retention30 - s.desiredRetention) <= 0.05 ? "Genau im Ziel: Die Abstände passen zu deinem Gedächtnis." : s.retention30 > s.desiredRetention ? "Über dem Ziel – ein niedrigeres Behaltensziel spart Wiederholungen." : "Unter dem Ziel – wiederhole möglichst täglich."}</div>`
    : `<div class="small secondary">Wie viele fällige Wörter du wirklich noch weißt – erscheint nach den ersten Wiederholungen. Der FSRS-Algorithmus plant die Abstände so, dass du dein Ziel triffst.</div>`;

  const letters = `<div class="letters">${s.letters.map((l) => `<div class="stack tight" style="align-items:center;gap:4px">${ring(l.learned / l.total, 40, 4, [COLORS.coral, COLORS.red], `<span class="small">${l.letter}</span>`)}<span class="caption secondary" style="font-size:9px">${l.learned}/${l.total}</span></div>`).join("")}</div>`;

  const tests = s.tests.slice(-12);
  const testsBody = tests.length
    ? `<svg viewBox="0 0 300 100" style="width:100%;height:110px" preserveAspectRatio="none">
        <polyline fill="none" stroke="var(--test)" stroke-width="2.5" stroke-linejoin="round" points="${tests.map((t, i) => `${tests.length === 1 ? 150 : (i / (tests.length - 1)) * 290 + 5},${95 - (t.correctFirstTry / Math.max(1, t.total)) * 90}`).join(" ")}"/>
        ${tests.map((t, i) => `<circle cx="${tests.length === 1 ? 150 : (i / (tests.length - 1)) * 290 + 5}" cy="${95 - (t.correctFirstTry / Math.max(1, t.total)) * 90}" r="3.5" fill="var(--test)"/>`).join("")}
      </svg>${testRow(tests.at(-1))}`
    : `<div class="small secondary">Prüfe alle gelernten Wörter auf einmal und verfolge hier deine Ergebnisse.</div>`;

  const facts = [["Lerntage gesamt", s.activeDays], ["Antworten gesamt", s.totalReviews], ["Trefferquote (30 Tage)", s.accuracy30 != null ? pct(s.accuracy30) : "–"],
    ["Ø Gedächtnis-Stabilität", `${s.averageStability.toFixed(1)} Tage`], ["Schon geplante Wörter", s.plannedAhead], ["Tests absolviert", s.tests.length]]
    .map(([l, v]) => `<div class="row small"><span class="secondary">${l}</span><div class="spacer"></div><b>${v}</b></div>`).join("");

  return `<div class="screen stack">${titleBar("Statistik")}
    <div class="grid tiles">
      ${tile("book", COLORS.coral, s.learned, `von ${s.totalWords}`, "Wörter gelernt")}
      ${tile("layers", COLORS.correct, s.stages.mature, "", "gefestigt")}
      ${tile("flame", COLORS.streak, s.currentStreak, `Rekord ${s.longestStreak}`, "Tage in Folge")}
      ${tile("clock", COLORS.sentence, duration(s.totalSeconds), "", "Lernzeit gesamt")}
    </div>
    <div class="grid">
      ${card("Textabdeckung", "target", COLORS.red, `<div class="row" style="gap:18px">${ring(s.coverage, 100, 14, [COLORS.coral, COLORS.red], pct(s.coverage))}<div class="stack tight"><div class="small">So viel eines typischen deutschen Alltagsgesprächs besteht aus Wörtern, die du schon auf Türkisch kennst.</div><div class="caption secondary">Mit allen ${s.totalWords} Wörtern: ${pct(s.maximumCoverage)}</div></div></div>`)}
      ${card("Aktivität · 30 Tage", "chart", COLORS.review, activity)}
      ${card("Lernkalender", "calendar", COLORS.coral, heat)}
      ${card("Wiederholungen · 14 Tage", "clock", COLORS.sentence, forecast)}
      ${card("Wortstatus", "layers", COLORS.correct, stages)}
      ${card("Behaltensquote", "target", COLORS.test, retention)}
      ${card("Fortschritt A–Z", "list", COLORS.coral, letters)}
      ${card("Wortschatz-Tests", "checklist", COLORS.test, `${testsBody}<button class="btn" style="background:var(--test)" data-action="open-test">${ic("play", 16)} Test starten</button>`)}
      ${card("Kennzahlen", "info", "var(--secondary)", `<div class="stack tight">${facts}</div>`)}
    </div></div>`;
}

function testRow(t) {
  const score = t.correctFirstTry / Math.max(1, t.total);
  return `<div class="card row" style="padding:12px;box-shadow:none;background:var(--fill)">${ring(score, 44, 5, [COLORS.test, COLORS.correct], `<span class="caption">${Math.round(score * 100)}</span>`)}
    <div style="flex:1"><div class="small bold">${C.grade(score)}</div><div class="caption secondary">${t.correctFirstTry} von ${t.total} · ${C.SCOPES[t.scope]?.name ?? ""} · ${duration(t.seconds)}</div></div>
    <span class="caption secondary">${new Date(t.date).toLocaleDateString("de-DE", { day: "numeric", month: "short" })}</span></div>`;
}

// Words

const STAGES = [
  ["learning", "Lernend", COLORS.practice, "gerade neu oder vergessen"],
  ["review", "Wiederholen", COLORS.review, "sitzt für einige Tage"],
  ["mature", "Gefestigt", COLORS.correct, "sitzt drei Wochen und länger"],
  ["upcoming", "Geplant", "#8e8e93", "kommt in den nächsten Tagen"],
];

function wordsByStage() {
  const groups = { learning: [], review: [], mature: [], upcoming: [] };
  const ids = Object.keys(P().cards).filter(word).sort((a, b) => P().cards[b].lastReview - P().cards[a].lastReview);
  for (const id of ids) groups[status(word(id)).key].push(id);
  groups.upcoming = Object.keys(P().plans).filter((d) => d >= today()).sort()
    .flatMap((d) => P().plans[d].wordIDs).filter((id) => word(id) && !P().cards[id]);
  return groups;
}

function wordTile(w, opts = {}) {
  const st = status(w);
  const card = P().cards[w.id];
  const recall = card ? C.cardRecall(card) : null;
  const rc = recall == null ? "" : recall >= 0.9 ? "var(--correct)" : recall >= 0.75 ? "var(--almost)" : "var(--wrong)";
  return `<button class="wtile ${st.key === "new" ? "locked" : ""} ${opts.wide ? "wide" : ""}" data-action="word" data-id="${w.id}">
    <span class="sdot" style="background:${st.color}" title="${st.name}"></span>
    <div class="tr">${esc(w.translation)}</div>
    <div class="de">${articleWord(w)}</div>
    ${recall != null ? `<div class="recall"><div style="width:${recall * 100}%;background:${rc}"></div></div>` : `<div class="caption secondary">${st.key === "new" ? "noch nicht dran" : st.name}</div>`}
  </button>`;
}

function renderWordsBody() {
  if (state.search.trim()) return renderSearch();
  if (state.wordsLetter) return renderLetterPage(state.wordsLetter);
  const groups = wordsByStage();
  const learned = learnedCount();
  const total = state.bank.words.length;
  const stats = C.statistics(P(), state.bank, state.index);
  const head = `<div class="card pad stack">
      <div class="row" style="gap:16px">${ring(learned / total, 86, 11, [COLORS.coral, COLORS.red], `<div class="small">${learned}</div>`)}
        <div style="flex:1"><h2>${learned} von ${total} Wörtern</h2><div class="small secondary">Deine Wörter machen ${pct(stats.coverage)} eines Alltagsgesprächs aus.</div></div></div>
      <div class="grid stages">${STAGES.map(([k, n, c]) => `<button class="stage" data-action="group" data-stage="${k}" style="--sc:${c}" ${groups[k].length ? "" : "disabled"}><b>${groups[k].length}</b><span>${n}</span></button>`).join("")}</div>
      ${learned ? `<button class="btn" data-action="cards" data-set="learned">${ic("layers", 18)} Karteikarten üben</button>` : ""}
    </div>`;
  const modes = [["letters", "A–Z"], ["status", "Status"], ["history", "Verlauf"]];
  const seg = `<div class="seg">${modes.map(([k, n]) => `<button class="${state.wordsMode === k ? "on" : ""}" data-action="words-mode" data-mode="${k}">${n}</button>`).join("")}</div>`;
  let body = "";
  if (state.wordsMode === "letters") {
    body = `<div class="lettergrid">${stats.letters.map((l) => `<button class="ltile" data-action="letter" data-letter="${l.letter}">
        ${ring(l.learned / l.total, 52, 5, l.learned ? [COLORS.coral, COLORS.red] : ["#c7c7cc", "#c7c7cc"], `<b style="font-size:20px">${l.letter}</b>`)}
        <span class="caption secondary">${l.learned}/${l.total}</span></button>`).join("")}</div>
      <div class="caption secondary center">Tippe auf einen Buchstaben, um seine Wörter zu sehen.</div>`;
  } else if (state.wordsMode === "status") {
    body = STAGES.map(([k, n, c, t]) => {
      const ids = groups[k];
      if (!ids.length) return "";
      return `<div class="stack tight"><div class="row"><span class="legend-dot" style="background:${c};margin-top:0"></span><div style="flex:1"><h3>${n} <span class="secondary">${ids.length}</span></h3><div class="caption secondary">${t}</div></div>
          <button class="btn link" style="width:auto;color:var(--red)" data-action="group" data-stage="${k}">Alle ›</button></div>
        <div class="hscroll">${ids.slice(0, 12).map((id) => wordTile(word(id))).join("")}</div></div>`;
    }).join("") || emptyWords();
  } else {
    const days = C.plannedDays(P());
    const byDay = {};
    for (const id of Object.keys(P().cards)) {
      if (!word(id)) continue;
      const d = days[id] ?? C.dayKey(new Date(P().cards[id].lastReview));
      (byDay[d] ??= []).push(id);
    }
    const keys = Object.keys(byDay).sort().reverse();
    body = keys.length ? keys.slice(0, state.historyDays).map((d) => `<div class="card stack tight"><div class="row"><b style="flex:1">${dayLabel(d)}</b><span class="caption secondary">${byDay[d].length} ${byDay[d].length === 1 ? "Wort" : "Wörter"}</span></div>
        <div class="chips">${byDay[d].map((id) => { const w = word(id); return `<button class="wchip" data-action="word" data-id="${id}" style="--sc:${status(w).color}">${esc(w.translation)} <span class="secondary">${esc(w.native)}</span></button>`; }).join("")}</div></div>`).join("")
        + (keys.length > state.historyDays ? `<button class="btn flat" data-action="more-history">Ältere Tage anzeigen</button>` : "")
      : emptyWords();
  }
  return `${head}${seg}${body}`;
}

function emptyWords() {
  return `<div class="card center secondary" style="padding:36px 16px">${ic("books", 40)}<div style="margin-top:8px">Dein erstes Wort wartet im Tab „Heute“.</div></div>`;
}

function dayLabel(key) {
  if (key === today()) return "Heute";
  if (key === C.addDays(today(), -1)) return "Gestern";
  return C.keyToDate(key).toLocaleDateString("de-DE", { weekday: "long", day: "numeric", month: "long" });
}

function renderLetterPage(letter) {
  const words = state.bank.words.filter((w) => C.letterFor(w.native) === letter);
  const learned = words.filter((w) => P().cards[w.id]).sort((a, b) => a.translation.localeCompare(b.translation, "tr"));
  const planned = words.filter((w) => !P().cards[w.id] && status(w).key === "upcoming");
  const rest = words.filter((w) => status(w).key === "new");
  const shownRest = state.showAllLetter ? rest : rest.slice(0, 12);
  const section = (title, list, hint = "") => (list.length ? `<div class="stack tight"><h3>${title} <span class="secondary">${list.length}</span></h3>${hint ? `<div class="caption secondary">${hint}</div>` : ""}<div class="wgrid">${list.map((w) => wordTile(w)).join("")}</div></div>` : "");
  return `<button class="btn link" style="width:auto;align-self:flex-start;color:var(--red);padding:4px 0" data-action="letter" data-letter="">‹ Alle Buchstaben</button>
    <div class="card pad row" style="gap:16px">${ring(learned.length / Math.max(1, words.length), 76, 9, [COLORS.coral, COLORS.red], `<b style="font-size:30px">${letter}</b>`)}
      <div style="flex:1"><h2>Buchstabe ${letter}</h2><div class="small secondary">${learned.length} gelernt · ${planned.length} geplant · ${words.length} insgesamt</div></div></div>
    ${learned.length ? `<button class="btn" data-action="cards" data-set="letter">${ic("layers", 18)} Als Karteikarten üben</button>` : ""}
    ${section("Gelernt", learned)}
    ${section("Geplant", planned, "Diese Wörter kommen in den nächsten Tagen.")}
    ${rest.length ? `<div class="stack tight"><h3>Noch nicht dran <span class="secondary">${rest.length}</span></h3><div class="caption secondary">Tippe ein Wort an und wähle „Jetzt lernen“, wenn du es nicht abwarten willst.</div>
      <div class="wgrid">${shownRest.map((w) => wordTile(w)).join("")}</div>
      ${rest.length > shownRest.length ? `<button class="btn flat" data-action="show-all-letter">Alle ${rest.length} anzeigen</button>` : ""}</div>` : ""}`;
}

function renderSearch() {
  const q = C.normalize(state.search);
  const hits = state.bank.words.filter((w) => C.normalize(w.native).includes(q) || C.normalize(C.withArticle(w)).includes(q)
    || C.normalize(w.translation).includes(q) || C.foldDiacritics(C.normalize(w.translation)).includes(C.foldDiacritics(q))
    || (w.alternatives ?? []).some((a) => C.normalize(a).includes(q)));
  const rank = (w) => (P().cards[w.id] ? 0 : status(w).key === "upcoming" ? 1 : 2);
  hits.sort((a, b) => rank(a) - rank(b) || a.rank - b.rank);
  const shown = hits.slice(0, 60);
  return hits.length ? `<div class="caption secondary">${hits.length} Treffer im Wörterbuch${hits.length > 60 ? " – die ersten 60" : ""}</div><div class="wgrid">${shown.map((w) => wordTile(w)).join("")}</div>`
    : `<div class="card center secondary" style="padding:36px 16px">${ic("books", 40)}<div style="margin-top:8px">Kein Wort gefunden.</div></div>`;
}

function renderWords() {
  return `<div class="screen narrow stack">${titleBar("Wortschatz")}
    <input class="search" type="search" placeholder="Wort suchen – Deutsch oder Türkisch" value="${esc(state.search)}" data-input="search">
    <div id="word-results" class="stack">${renderWordsBody()}</div>
  </div>`;
}

function groupIds(stage) {
  return wordsByStage()[stage] ?? [];
}

function renderGroup(o) {
  const [, name, color, hint] = STAGES.find(([k]) => k === o.stage);
  let ids = groupIds(o.stage);
  const sorts = [["recent", "Zuletzt"], ["alpha", "A–Z"], ["weak", "Schwächste"], ["freq", "Häufigste"]];
  if (o.sort === "alpha") ids = [...ids].sort((a, b) => word(a).translation.localeCompare(word(b).translation, "tr"));
  if (o.sort === "weak") ids = [...ids].sort((a, b) => (P().cards[a] ? C.cardRecall(P().cards[a]) : 2) - (P().cards[b] ? C.cardRecall(P().cards[b]) : 2));
  if (o.sort === "freq") ids = [...ids].sort((a, b) => word(a).rank - word(b).rank);
  return `<div class="overlay">${bar(name)}<div class="body stack">
    <div class="row"><span class="legend-dot" style="background:${color};margin-top:0"></span><div class="small secondary" style="flex:1">${ids.length} Wörter · ${hint}</div></div>
    <div class="filters">${sorts.map(([k, n]) => `<button class="${o.sort === k ? "on" : ""}" data-action="group-sort" data-sort="${k}">${n}</button>`).join("")}</div>
    ${o.stage !== "upcoming" && ids.length ? `<button class="btn" data-action="cards" data-set="group">${ic("layers", 18)} Als Karteikarten üben</button>` : ""}
    <div class="wgrid">${ids.map((id) => wordTile(word(id))).join("")}</div></div></div>`;
}

// Flashcard browser: swipe through words, tap to flip.

function openCards(ids, title) {
  if (!ids.length) return;
  openOverlay({ type: "cards", ids, index: 0, flipped: false, title });
}

function renderCards(o) {
  const w = word(o.ids[o.index]);
  const z = C.parseCloze(w.exampleTarget);
  const card = P().cards[w.id];
  const slide = o.slide ? `slide-${o.slide}` : "";
  o.slide = null;
  return `<div class="overlay">${bar("", (o.index + 1) / o.ids.length, `<span class="caption secondary bold">${o.index + 1}/${o.ids.length}</span>`)}
    <div class="body stack" style="padding-top:12px">
      <div class="caption secondary center">${esc(o.title)} · Tippen zum Umdrehen, wischen zum Weiterblättern</div>
      <div class="flip ${o.flipped ? "flipped" : ""} ${slide}" data-action="flip" id="flipcard" role="button" aria-label="Karte umdrehen">
        <div class="face front"><span class="pill white">🇹🇷 Türkisch</span><div class="big rounded">${esc(w.translation)}</div>
          ${card ? `<div class="muted">Erinnerung ${pct(C.cardRecall(card))}</div>` : ""}<div class="spacer"></div><div class="muted">Was heißt das auf Deutsch?</div></div>
        <div class="face back"><span class="pill">🇩🇪 Deutsch</span><div class="big rounded" style="color:var(--text)">${articleWord(w)}</div>
          <div style="font-size:18px">${esc(z.before)}<mark>${esc(z.answer)}</mark>${esc(z.after)}</div><div class="secondary">${esc(w.exampleNative)}</div>
          ${w.note ? `<div class="small secondary row top" style="gap:6px"><span style="color:var(--almost)">${ic("bulb", 16)}</span>${esc(w.note)}</div>` : ""}</div>
      </div>
      <div class="row" style="justify-content:center;gap:14px">
        <button class="roundbtn" data-action="card-step" data-delta="-1" ${o.index ? "" : "disabled"} aria-label="Zurück">${ic("chevron", 22, 'style="transform:scaleX(-1)"')}</button>
        <button class="roundbtn big" data-action="speak" data-text="${esc(w.translation)}" aria-label="Vorlesen">${ic("speaker", 24)}</button>
        <button class="roundbtn" data-action="card-shuffle" aria-label="Mischen">${ic("shuffle", 20)}</button>
        <button class="roundbtn" data-action="card-step" data-delta="1" ${o.index < o.ids.length - 1 ? "" : "disabled"} aria-label="Weiter">${ic("chevron", 22)}</button>
      </div>
      <button class="btn flat" data-action="word" data-id="${w.id}">Details zum Wort</button>
    </div></div>`;
}

// Settings

function renderSettings() {
  const s = P().settings;
  const time = `${String(s.notificationHour).padStart(2, "0")}:${String(s.notificationMinute).padStart(2, "0")}`;
  const sw = (key) => `<button class="switch ${s[key] ? "on" : ""}" data-action="toggle" data-key="${key}" aria-pressed="${s[key]}"></button>`;
  return `<div class="screen narrow">${titleBar("Einstellungen")}
    <div class="group-title">Sprachen</div>
    <div class="list"><div class="setting"><span>Muttersprache</span><div class="spacer"></div><span class="secondary">🇩🇪 Deutsch</span></div>
      <div class="setting"><span>Ich lerne</span><div class="spacer"></div><span class="secondary">🇹🇷 Türkisch</span></div></div>
    <div class="group-footer">Weitere Sprachen folgen.</div>

    <div class="group-title">Lernen</div>
    <div class="list">
      <div class="setting"><span>Modus</span><div class="spacer"></div><span class="secondary">Standard</span></div>
      <div class="setting"><span>Neue Wörter pro Tag</span><div class="spacer"></div><div class="stepper"><button data-action="per-day" data-delta="-1">−</button><b>${s.newWordsPerDay}</b><button data-action="per-day" data-delta="1">+</button></div></div>
      <div class="setting"><span>Satzübungen einmischen</span><div class="spacer"></div>${sw("mixSentenceExercises")}</div>
      <div class="setting"><span>Behaltensziel</span><div class="spacer"></div><select data-input="retention">
        ${[[0.85, "85 %"], [0.9, "90 % (empfohlen)"], [0.95, "95 %"]].map(([v, n]) => `<option value="${v}" ${s.desiredRetention === v ? "selected" : ""}>${n}</option>`).join("")}</select></div>
    </div>
    <div class="group-footer">Standard: Jeden Tag ein zufälliges Wort aus den häufigsten Wörtern – reihum von A bis Z. Ein höheres Behaltensziel bedeutet häufigere Wiederholungen.</div>

    <div class="group-title">Erinnerungen</div>
    <div class="list">
      <div class="setting"><span>Uhrzeit</span><div class="spacer"></div><input type="time" value="${time}" data-input="time"></div>
      <button class="setting" style="width:100%;color:var(--red)" data-action="calendar">${ic("calendar", 20)}<span>Wörter der nächsten 30 Tage in den Kalender</span></button>
    </div>
    <div class="group-footer">Die Web-App kann unter iOS keine eigenen Mitteilungen planen. Stattdessen legst du deine geplanten Wörter als Kalendertermine mit Hinweis an – dein Kalender meldet sich dann z. B. mit „ev – das Haus“. Nach „Noch ein Wort“ oder geänderter Wortanzahl einfach neu exportieren.</div>

    <div class="group-title">Daten</div>
    <div class="list">
      <button class="setting" style="width:100%" data-action="export">${ic("download", 20)}<span>Lernstand sichern (Datei)</span></button>
      <label class="setting" style="width:100%;cursor:pointer">${ic("upload", 20)}<span>Lernstand wiederherstellen</span><input type="file" accept="application/json,.json" data-input="import" hidden></label>
      <button class="setting" style="width:100%;color:var(--wrong)" data-action="reset">${ic("trash", 20)}<span>Lernfortschritt zurücksetzen</span></button>
    </div>
    <div class="group-footer">Dein Lernstand liegt nur auf diesem Gerät. Die Sicherung kannst du z. B. in iCloud Drive ablegen.</div>

    <div class="group-title">Info</div>
    <div class="list">
      <button class="setting" style="width:100%" data-action="method"><span>So funktioniert das Lernen</span><div class="spacer"></div><span class="secondary">${ic("chevron", 18)}</span></button>
      <div class="setting"><span>Wörter in der Datenbank</span><div class="spacer"></div><span class="secondary">${state.bank.words.length}</span></div>
    </div>
    <div class="group-footer">${esc(state.bank.attribution)} Lernalgorithmus: FSRS-5 (open-spaced-repetition, MIT).</div>
  </div>`;
}

// Onboarding

function renderOnboarding() {
  const step = state.onboardingStep;
  const s = P().settings;
  const pages = [
    `<div class="hero stack"><div style="color:var(--sun)">${ic("sun", 56)}</div><div style="font-size:34px;font-weight:800">Willkommen bei VocaDay</div><div style="font-size:19px;opacity:.92">Jeden Tag mindestens ein neues Wort – ausgewählt aus den häufigsten Wörtern, reihum von A bis Z.</div></div>
     <div class="stack">${[["bell", COLORS.coral, "Wort des Tages", "Jeden Tag ein neues Wort – auf Wunsch als Kalender-Erinnerung."], ["layers", COLORS.review, "Wissenschaftlich wiederholen", "Der FSRS-Algorithmus fragt jedes Wort ab, kurz bevor du es vergessen würdest."], ["bubble", COLORS.sentence, "Aktiv in Sätzen", "Lückentexte und Satzbau trainieren die Wörter im Zusammenhang."], ["checklist", COLORS.test, "Wortschatz-Test & Statistik", "Prüfe alles Gelernte auf einmal und sieh, wie dein Wortschatz wächst."]]
      .map(([i, c, t, d]) => `<div class="row top">${gradIcon(i, c, "sm")}<div><b>${t}</b><div class="small secondary">${d}</div></div></div>`).join("")}</div>`,
    `<h1 style="margin:0">Welche Sprachen?</h1><b>Deine Muttersprache</b><div class="lang on"><span class="flag">🇩🇪</span>Deutsch<div class="spacer"></div><span style="color:var(--red)">${ic("check")}</span></div>
     <b>Diese Sprache möchtest du lernen</b><div class="lang on"><span class="flag">🇹🇷</span>Türkisch<div class="spacer"></div><span style="color:var(--red)">${ic("check")}</span></div><div class="small secondary">Weitere Sprachen folgen.</div>`,
    `<h1 style="margin:0">Dein Tempo</h1>
     <div class="card stack tight"><b>Modus: Standard</b><div class="small secondary">Jeden Tag ein zufälliges Wort aus den häufigsten Wörtern – reihum von A bis Z, danach wieder ab A.</div></div>
     <div class="card stack tight"><div class="row"><span>Neue Wörter pro Tag</span><div class="spacer"></div><div class="stepper"><button data-action="per-day" data-delta="-1">−</button><b>${s.newWordsPerDay}</b><button data-action="per-day" data-delta="1">+</button></div></div>
       <div class="small secondary">Das sind ${s.newWordsPerDay * 7} Wörter pro Woche. Mit „Noch ein Wort“ geht jederzeit mehr.</div></div>
     <div class="card row"><div style="flex:1"><div>Satzübungen einmischen</div><div class="small secondary">Wörter auch in Lückentexten und beim Satzbau wiederholen.</div></div><button class="switch ${s.mixSentenceExercises ? "on" : ""}" data-action="toggle" data-key="mixSentenceExercises"></button></div>`,
    `<h1 style="margin:0">Fast geschafft</h1>
     <div class="card stack tight"><div class="row">${gradIcon("share", COLORS.review, "sm")}<b>Auf den Home-Bildschirm</b></div><div class="small secondary">Tippe in Safari auf <b>Teilen</b> und dann auf <b>„Zum Home-Bildschirm“</b>. So startet VocaDay wie eine App und dein Lernstand bleibt dauerhaft gespeichert.</div></div>
     <div class="card stack tight"><div class="row">${gradIcon("calendar", COLORS.coral, "sm")}<b>Erinnerungen</b></div><div class="small secondary">Unter Einstellungen kannst du die Wörter der nächsten 30 Tage als Kalendertermine anlegen – dann meldet sich dein iPhone jeden Morgen mit dem neuen Wort.</div></div>`,
  ];
  return `<div class="onboarding">
    <div class="progress"><div style="width:${(step / 3) * 100}%"></div></div>
    <div class="stack exercise" style="flex:1">${pages[step]}</div>
    <div class="row">${step ? `<button class="btn flat" style="width:auto;padding:16px 22px" data-action="onb-back">Zurück</button>` : ""}<button class="btn" data-action="onb-next">${step === 3 ? "Los geht's" : "Weiter"}</button></div>
  </div>`;
}

// MARK: Overlays

function openOverlay(o, { stacked = false } = {}) {
  o.fresh = true;
  if (stacked && state.overlay) o.parent = state.overlay;
  state.overlay = o;
  document.body.style.overflow = "hidden";
  renderOverlay();
}

function closeOverlay() {
  const parent = state.overlay?.parent;
  if (parent) {
    state.overlay = parent;
    renderOverlay();
    return;
  }
  state.overlay = null;
  document.body.style.overflow = "";
  overlayRoot.innerHTML = "";
  render();
}

function renderOverlay() {
  const o = state.overlay;
  if (!o) { overlayRoot.innerHTML = ""; return; }
  const scrollTop = overlayRoot.firstElementChild?.scrollTop ?? 0;
  const views = {
    session: renderSessionOverlay, test: renderTestOverlay, testSetup: renderTestSetup, word: renderWordDetail,
    method: renderMethod, group: renderGroup, cards: renderCards,
  };
  overlayRoot.innerHTML = views[o.type](o);
  const root = overlayRoot.firstElementChild;
  // Animate only when the overlay opens or a new exercise appears, not on every tap.
  if (!o.fresh) root.classList.add("still");
  if (!o.fresh && !o.newItem) root.querySelectorAll(".exercise, .feedback.seen").forEach((el) => el.classList.add("still"));
  o.fresh = false;
  o.newItem = false;
  animateRings(overlayRoot);
  if (o.keepScroll) root.scrollTop = scrollTop;
  o.keepScroll = false;
  const input = overlayRoot.querySelector("input[data-input='answer']");
  if (input && !o.ctx?.verdict) setTimeout(() => input.focus(), 50);
}

function bar(title, progress = null, extra = "") {
  return `<div class="bar"><button class="close" data-action="close" aria-label="Schließen">${ic("x", 16)}</button>
    ${progress != null ? `<div class="progress"><div style="width:${progress * 100}%"></div></div>${extra}` : `<b style="flex:1;text-align:center">${title}</b><div style="width:34px"></div>`}</div>`;
}

// Exercise context

function makeCtx(item) {
  const w = word(item.wordID);
  if (!w) return null;
  const ctx = { item, word: w, cloze: C.parseCloze(w.exampleTarget), selected: null, verdict: null, revealed: false, chosen: [], built: null };
  const choices = (answerOf, pool) => {
    const others = C.distractors(w, pool, answerOf);
    ctx.options = C.shuffle([...others.map(answerOf), answerOf(w)]);
    ctx.correct = ctx.options.indexOf(answerOf(w));
  };
  if (item.kind === "chooseNative") choices(C.withArticle, state.bank.words);
  if (item.kind === "chooseTarget") choices((x) => x.translation, state.bank.words);
  if (item.kind === "clozeChoice") choices((x) => C.parseCloze(x.exampleTarget).answer, state.bank.words.filter((x) => C.parseCloze(x.exampleTarget).hasGap));
  if (item.kind === "sentenceBuilder") {
    const tokens = ctx.cloze.plain.split(" ").filter(Boolean);
    let shuffled = C.shuffle(tokens);
    for (let i = 0; i < 10 && new Set(tokens).size > 1 && shuffled.join(" ") === tokens.join(" "); i++) shuffled = C.shuffle(tokens);
    ctx.tokens = shuffled;
  }
  if (item.kind === "introduction") speak(w.translation);
  return ctx;
}

function promptCard(kind, text, sub = "", speakText = "") {
  return `<div class="card pad prompt"><div class="row"><div class="kicker">${C.KIND_TITLES[kind]}</div><div class="spacer"></div>${speakText ? speakButton(speakText) : ""}</div>
    <div class="text rounded ${text.length > 24 ? "long" : ""}">${esc(text)}</div>${sub ? `<div class="secondary" style="font-size:19px;margin-top:6px">${esc(sub)}</div>` : ""}</div>`;
}

function feedbackPanel(outcome, detail, w) {
  const color = { correct: COLORS.correct, almost: COLORS.almost, wrong: COLORS.wrong }[outcome];
  const title = outcome === "correct" ? ["Richtig!", "Super!", "Genau!", "Klasse!"][Math.floor(Math.random() * 4)] : outcome === "almost" ? "Fast richtig" : "Noch nicht ganz";
  return `<div class="feedback" style="--fb:${color}">
    <div class="head"><span>${ic(outcome === "wrong" ? "x" : "check", 16)}</span>${title}</div>
    ${detail ? `<div class="small bold">${esc(detail)}</div>` : ""}
    <div class="row top"><div style="flex:1"><div><b>${esc(w.translation)}</b> – ${articleWord(w)}</div><div class="small">${highlighted(w)}</div><div class="small secondary">${esc(w.exampleNative)}</div></div>${speakButton(C.parseCloze(w.exampleTarget).plain)}</div>
    <button class="btn" data-action="continue">Weiter</button></div>`;
}

function renderExercise(ctx, card) {
  const { item, word: w } = ctx;
  const k = item.kind;
  if (k === "introduction") {
    return `<div class="exercise">
      <div class="hero stack tight"><div class="row"><span class="pill white">✨ Neues Wort</span><div class="spacer"></div>${speakButton(w.translation, true)}</div>
        <div class="big rounded">${esc(w.translation)}</div><div class="sub">${esc(C.withArticle(w))}</div>
        ${w.alternatives?.length ? `<div class="muted">auch: ${esc(w.alternatives.join(", "))}</div>` : ""}</div>
      <div class="card stack tight"><h3>Im Satz</h3><div class="row top"><div style="flex:1;font-size:20px">${highlighted(w)}</div>${speakButton(ctx.cloze.plain)}</div><div class="secondary">${esc(w.exampleNative)}</div></div>
      ${w.note ? `<div class="card row top small"><span style="color:var(--almost)">${ic("bulb", 20)}</span><div>${esc(w.note)}</div></div>` : ""}
      <div class="caption secondary">Sprich das Wort laut nach – das hilft beim Merken.</div>
      <button class="btn" data-action="continue">Verstanden</button></div>`;
  }
  if (k === "chooseNative" || k === "chooseTarget" || k === "clozeChoice") {
    const prompt = k === "chooseNative" ? promptCard(k, w.translation, "", w.translation)
      : k === "chooseTarget" ? promptCard(k, C.withArticle(w))
      : promptCard(k, `${ctx.cloze.before}_____${ctx.cloze.after}`, w.exampleNative);
    const opts = ctx.options.map((o, i) => {
      let cls = "";
      if (ctx.selected != null) cls = i === ctx.correct ? "correct" : i === ctx.selected ? "wrong" : "dim";
      return `<button class="option ${cls}" data-action="choose" data-index="${i}" ${ctx.selected != null ? "disabled" : ""}><span class="badge">${"ABCDE"[i]}</span><span style="flex:1">${esc(o)}</span>${cls === "correct" ? `<span style="color:var(--correct)">${ic("check")}</span>` : cls === "wrong" ? `<span style="color:var(--wrong)">${ic("x")}</span>` : ""}</button>`;
    }).join("");
    const fb = ctx.selected != null ? feedbackPanel(ctx.selected === ctx.correct ? "correct" : "wrong", ctx.selected === ctx.correct ? "" : `Richtig ist: ${ctx.options[ctx.correct]}`, w) : "";
    return `<div class="exercise">${prompt}<div class="stack tight">${opts}</div>${fb}</div>`;
  }
  if (k === "typeTarget" || k === "typeNative" || k === "clozeType") {
    const german = k === "typeNative";
    const prompt = k === "typeTarget" ? promptCard(k, C.withArticle(w)) : k === "typeNative" ? promptCard(k, w.translation, "", w.translation)
      : promptCard(k, `${ctx.cloze.before}_____${ctx.cloze.after}`, w.exampleNative);
    const chars = german ? ["ä", "ö", "ü", "ß"] : ["ç", "ğ", "ı", "İ", "ö", "ş", "ü"];
    const v = ctx.verdict;
    let fb = "";
    if (v) {
      const outcome = v.verdict === "correct" ? "correct" : v.verdict === "wrong" ? "wrong" : "almost";
      const detail = v.verdict === "diacritics" ? `Achte auf die Sonderzeichen: ${v.expected}` : v.verdict === "typo" ? `Kleiner Tippfehler – richtig: ${v.expected}` : v.verdict === "wrong" ? `Richtig ist: ${v.expected}` : "";
      fb = feedbackPanel(outcome, detail, w) + (v.verdict === "wrong" && ctx.input ? `<button class="btn link" data-action="override">Meine Antwort war richtig</button>` : "");
    }
    return `<div class="exercise">${prompt}
      <div class="input-wrap"><span>${german ? "🇩🇪" : "🇹🇷"}</span><input data-input="answer" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false" placeholder="Auf ${german ? "Deutsch" : "Türkisch"} …" value="${esc(ctx.input ?? "")}" ${v ? "disabled" : ""} enterkeyhint="done"></div>
      ${v ? "" : `<div class="chars">${chars.map((c) => `<button data-action="char" data-char="${c}">${c}</button>`).join("")}</div>
        ${k === "clozeType" ? `<button class="btn link" style="color:var(--red)" data-action="hint">${ctx.hint ? `Grundform: ${esc(w.translation)}` : "💡 Tipp anzeigen"}</button>` : ""}
        <button class="btn" data-action="check">Prüfen</button><button class="btn link" data-action="dont-know">Weiß ich nicht</button>`}
      ${fb}</div>`;
  }
  if (k === "flashcard") {
    const now = Date.now();
    const colors = { 1: COLORS.wrong, 2: COLORS.almost, 3: COLORS.correct, 4: COLORS.review };
    return `<div class="exercise">${promptCard(k, C.withArticle(w), "Sag das türkische Wort laut, dann deck auf.")}
      ${ctx.revealed
        ? `<div class="hero stack tight" style="animation:pop .35s"><div class="row"><div class="big rounded" style="font-size:38px;flex:1">${esc(w.translation)}</div>${speakButton(w.translation, true)}</div><div>${highlighted(w)}</div><div class="muted">${esc(w.exampleNative)}</div></div>
           <h3>Wie gut wusstest du es?</h3>
           <div class="ratings">${[1, 2, 3, 4].map((r) => `<button style="--rc:${colors[r]}" data-action="rate" data-rating="${r}">${C.RATING_NAMES[r]}<small>${intervalLabel(C.schedule(card, r, now, P().settings.desiredRetention).due - now)}</small></button>`).join("")}</div>`
        : `<button class="tap-reveal" data-action="reveal">👆<span>Antwort zeigen</span></button>`}</div>`;
  }
  if (k === "sentenceBuilder") {
    const chosen = ctx.chosen.map((i) => `<button class="chip on" data-action="unpick" data-index="${i}">${esc(ctx.tokens[i])}</button>`).join("");
    const rest = ctx.tokens.map((t, i) => (ctx.chosen.includes(i) ? "" : `<button class="chip" data-action="pick" data-index="${i}">${esc(t)}</button>`)).join("");
    const done = ctx.built != null;
    return `<div class="exercise">${promptCard(k, w.exampleNative, "Tippe die Wörter in der richtigen Reihenfolge an.")}
      <div class="builder chips ${done ? (ctx.built ? "ok" : "bad") : ""}">${chosen}</div>
      <div class="chips">${rest}</div>
      ${done ? feedbackPanel(ctx.built ? "correct" : "wrong", ctx.built ? "" : `Richtig ist: ${ctx.cloze.plain}`, w)
        : `<button class="btn" data-action="build-check" ${ctx.chosen.length !== ctx.tokens.length ? "disabled" : ""}>Prüfen</button>`}</div>`;
  }
  return "";
}

// Sessions

function startSession(title, session) {
  if (!session.items.length) {
    toast("Gerade gibt es nichts zu üben.");
    return;
  }
  const o = { type: "session", title, session, startedAt: Date.now(), ctx: null };
  o.ctx = nextCtx(o.session);
  openOverlay(o);
}

function nextCtx(runner) {
  while (runner.current) {
    const ctx = makeCtx(runner.current);
    if (ctx) return ctx;
    if (runner instanceof C.VocabularyTest) runner.record(true); else runner.advance(null);
  }
  return null;
}

function renderSessionOverlay(o) {
  const s = o.session;
  if (s.finished) {
    const acc = s.answered ? s.correct / s.answered : 1;
    const secs = (Date.now() - o.startedAt) / 1000;
    return `<div class="overlay">${bar(o.title)}<div class="body stack" style="align-items:center;text-align:center;padding-top:20px">
      ${ring(acc, 170, 16, [COLORS.correct, COLORS.test], `<div class="rounded" style="font-size:36px">${pct(acc)}</div><div class="small secondary">richtig</div>`)}
      <h1 style="margin:0">Geschafft!</h1>
      <div class="grid" style="grid-template-columns:repeat(3,1fr);width:100%;gap:12px">
        ${[["✨", s.newWordIDs.length, "neue Wörter"], ["✅", s.answered, "Antworten"], ["⏱", duration(secs), "Lernzeit"]].map(([i, v, l]) => `<div class="card stack tight" style="align-items:center;padding:12px"><span>${i}</span><b style="font-size:20px">${v}</b><span class="caption secondary">${l}</span></div>`).join("")}
      </div>
      <div class="secondary">Die Wörter kommen genau dann wieder, wenn du sie sonst vergessen würdest.</div>
      <button class="btn" data-action="close">Fertig</button></div></div>`;
  }
  return `<div class="overlay">${bar(o.title, s.progress, `<span class="caption secondary bold">${s.remaining}</span>`)}<div class="body">${renderExercise(o.ctx, P().cards[o.ctx.word.id] ?? null)}</div></div>`;
}

function finishExercise(rating) {
  const o = state.overlay;
  if (!o?.ctx) return;
  const item = o.ctx.item;
  if (o.type === "session") {
    if (rating != null) {
      C.record(P(), item.wordID, C.capRating(item.kind, rating));
      save();
    }
    o.session.advance(rating);
    o.ctx = nextCtx(o.session);
    o.newItem = true;
    if (o.session.finished) {
      C.addStudyTime(P(), (Date.now() - o.startedAt) / 1000);
      save();
      confetti();
      vibrate(true);
    }
  } else if (o.type === "test") {
    const answer = rating ?? C.RATING.good;
    if (o.test.isFirstAttempt) {
      C.record(P(), item.wordID, C.capRating(item.kind, answer));
    }
    o.test.record(answer !== C.RATING.again);
    o.ctx = nextCtx(o.test);
    o.newItem = true;
    if (o.test.finished && !o.saved) {
      const result = o.test.result();
      P().tests.push(result);
      C.addStudyTime(P(), result.seconds);
      o.saved = true;
      if (o.test.score >= 0.8) confetti();
    }
    save();
  }
  renderOverlay();
  overlayRoot.firstElementChild?.scrollTo({ top: 0 });
}

// Tests

function renderTestSetup(o) {
  const counts = Object.fromEntries(["all", "weakest", "random", "recent"].map((s) => [s, C.testWordIDs(s, P(), state.index).length]));
  const scopes = [["all", "▦", "Alle Wörter"], ["weakest", "⚠︎", "Die 20 schwächsten"], ["random", "⇄", "20 zufällige"], ["recent", "🗓", "Diese Woche"]];
  const choice = (group, value, title, detail, on) => `<button class="choice ${on ? "on" : ""}" data-action="setup" data-group="${group}" data-value="${value}"><div class="bold small">${title}</div>${detail ? `<div class="d">${detail}</div>` : ""}</button>`;
  const count = counts[o.scope];
  return `<div class="overlay">${bar("Wortschatz-Test")}<div class="body stack">
    <div class="card pad row top">${gradIcon("checklist", COLORS.test, "lg")}<div><h3>Wie gut sitzt dein Wortschatz?</h3><div class="small secondary">Jedes Wort wird einmal abgefragt – gewertet zählt nur der erste Versuch. Falsche Wörter kommen danach in einer Fehlerrunde wieder, bis du sie kannst. Deine Antworten fließen in die Wiederholungsplanung ein.</div></div></div>
    <h3>Welche Wörter?</h3><div class="grid two">${scopes.map(([k, i, n]) => choice("scope", k, `${i} ${n}`, `${counts[k]} Wörter`, o.scope === k)).join("")}</div>
    <h3>Richtung</h3><div class="grid" style="grid-template-columns:repeat(3,1fr);gap:10px">${[["toTarget", "Deutsch → Türkisch"], ["toNative", "Türkisch → Deutsch"], ["mixed", "Gemischt"]].map(([k, n]) => choice("direction", k, n, "", o.direction === k)).join("")}</div>
    <h3>Antworten</h3><div class="grid two">${choice("mode", "choice", "☰ Auswählen", "erkennen", o.mode === "choice")}${choice("mode", "typing", "⌨︎ Eintippen", "selbst abrufen", o.mode === "typing")}</div>
    ${P().tests.length ? `<h3>Letzte Ergebnisse</h3>${P().tests.slice(-3).reverse().map(testRow).join("")}` : ""}
    <button class="btn" style="background:var(--test)" data-action="start-test" ${count ? "" : "disabled"}>${ic("play", 16)} ${count ? `Test starten · ${count} Wörter` : "Keine Wörter in dieser Auswahl"}</button>
  </div></div>`;
}

function startTest(scope, direction, mode, ids = []) {
  const wordIDs = C.testWordIDs(scope, P(), state.index, Date.now(), ids);
  const test = new C.VocabularyTest(scope, direction, mode, wordIDs);
  const o = { type: "test", test, saved: false, ctx: null };
  o.ctx = nextCtx(test);
  openOverlay(o);
}

function renderTestOverlay(o) {
  const t = o.test;
  if (t.finished) {
    const msg = t.score >= 0.9 ? "Dein Wortschatz sitzt richtig gut." : t.score >= 0.75 ? "Fast alles gewusst – stark!" : t.score >= 0.6 ? "Solide Basis. Die Fehler kommen bald wieder dran." : "Kein Problem – genau dafür ist der Test da. Die Wörter werden jetzt öfter wiederholt.";
    const mistakes = t.mistakes.map(word).filter(Boolean);
    return `<div class="overlay">${bar(C.SCOPES[t.scope].name)}<div class="body stack" style="align-items:center;text-align:center;padding-top:20px">
      ${ring(t.score, 190, 18, [COLORS.test, COLORS.correct], `<div class="rounded" style="font-size:40px;font-weight:800">${pct(t.score)}</div><div class="caption secondary">beim 1. Versuch</div>`)}
      <h1 style="margin:0">${C.grade(t.score)}</h1><div class="secondary">${msg}</div>
      <div class="grid" style="grid-template-columns:repeat(3,1fr);width:100%;gap:12px">
        ${[["✅", `${t.correctFirstTry}/${t.wordCount}`, "gewusst"], ["❌", t.mistakes.length, "Fehler"], ["⏱", duration((Date.now() - t.startedAt) / 1000), "Dauer"]].map(([i, v, l]) => `<div class="card stack tight" style="align-items:center;padding:12px"><span>${i}</span><b style="font-size:20px">${v}</b><span class="caption secondary">${l}</span></div>`).join("")}
      </div>
      ${mistakes.length ? `<div class="card stack tight" style="width:100%;text-align:left"><h3>Diese Wörter üben wir weiter</h3>${mistakes.map((w) => `<div class="row"><b style="flex:1">${esc(w.translation)}</b><span class="secondary">${articleWord(w)}</span>${speakButton(w.translation)}</div>`).join("")}</div>
        <button class="btn" style="background:var(--test)" data-action="retest">${ic("refresh", 16)} Fehler noch einmal testen (${mistakes.length})</button>` : ""}
      <button class="btn" data-action="close">Fertig</button></div></div>`;
  }
  const header = `${t.inMistakesRound ? `<span class="pill" style="color:var(--almost)">↺ Fehlerrunde</span>` : `<span class="caption secondary bold">${Math.min(t.position + 1, t.wordCount)}/${t.wordCount}</span>`}
    <span class="caption bold" style="color:var(--correct)">✓ ${t.correctFirstTry}</span><span class="caption bold" style="color:var(--wrong)">✗ ${t.answeredFirstTry - t.correctFirstTry}</span>`;
  return `<div class="overlay">${bar("", t.progress, header)}<div class="body">${renderExercise(o.ctx, P().cards[o.ctx.word.id] ?? null)}</div></div>`;
}

// Word detail

function renderWordDetail(o) {
  const w = word(o.id);
  const card = P().cards[w.id];
  const planned = C.plannedDays(P())[w.id];
  let memory;
  if (planned && planned <= today()) {
    memory = `<div class="card pad stack tight"><div class="row">${gradIcon("star", COLORS.coral, "sm")}<div style="flex:1"><h3>Steht heute auf deinem Plan</h3><div class="small secondary">Lerne es jetzt – danach wiederholt VocaDay es automatisch.</div></div></div>
      <button class="btn" data-action="learn-now-start">${ic("play", 16)} Jetzt lernen</button></div>`;
  } else {
    memory = `<div class="card pad stack tight"><div class="row">${gradIcon("calendar", "#8e8e93", "sm")}<div style="flex:1"><h3>${planned ? `Geplant für ${dayLabel(planned)}` : "Noch nicht dran"}</h3>
        <div class="small secondary">${planned ? "Es kommt automatisch an die Reihe." : `Platz ${w.rank} der Häufigkeitsliste – es kommt dran, wenn der Buchstabe ${C.letterFor(w.native)} wieder an der Reihe ist.`}</div></div></div>
      <button class="btn" data-action="learn-now" data-id="${w.id}">${ic("plus", 16)} Heute lernen</button></div>`;
  }
  if (card) {
    const recall = C.cardRecall(card);
    const st = status(w);
    const span = Math.max(7, Math.min(120, ((card.due - card.lastReview) / 86_400_000) * 2));
    const pts = Array.from({ length: 41 }, (_, i) => {
      const d = (span * i) / 40;
      return [d, C.retrievability(d, card.stability)];
    });
    const X = (d) => 10 + (d / span) * 280;
    const Y = (r) => 110 - r * 100;
    const path = pts.map(([d, r], i) => `${i ? "L" : "M"}${X(d).toFixed(1)},${Y(r).toFixed(1)}`).join(" ");
    const dueDay = (card.due - card.lastReview) / 86_400_000;
    const nowDay = (Date.now() - card.lastReview) / 86_400_000;
    const target = P().settings.desiredRetention;
    memory = `<div class="card pad stack">
      <div class="row" style="gap:16px">${ring(recall, 76, 10, [COLORS.test, COLORS.correct], `<span class="small">${pct(recall)}</span>`)}
        <div class="stack tight"><h3>Erinnerung gerade</h3><span class="pill" style="color:${st.color};align-self:flex-start">${st.name}</span><span class="small secondary">Nächste Wiederholung ${relative(card.due)}</span></div></div>
      <div class="row" style="justify-content:space-around;text-align:center">${[[`${card.stability.toFixed(1)} T`, "Stabilität"], [card.difficulty.toFixed(1), "Schwierigkeit"], [card.reps, "Abfragen"], [`${card.lapses}×`, "Vergessen"]].map(([v, l]) => `<div><b>${v}</b><div class="caption secondary">${l}</div></div>`).join("")}</div></div>
    <div class="card pad stack tight"><h3 class="row" style="color:var(--sentence);gap:8px">${ic("chart", 20)} Vergessenskurve</h3>
      <svg viewBox="0 0 300 125" style="width:100%">
        <defs><linearGradient id="fc" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8b5cf6" stop-opacity=".35"/><stop offset="1" stop-color="#8b5cf6" stop-opacity="0"/></linearGradient></defs>
        <path d="${path} L${X(span)},110 L${X(0)},110 Z" fill="url(#fc)"/>
        <path d="${path}" fill="none" stroke="#8b5cf6" stroke-width="2.5"/>
        <line x1="10" x2="290" y1="${Y(target)}" y2="${Y(target)}" stroke="#14b8a6" stroke-dasharray="4 3"/>
        <text x="290" y="${Y(target) - 4}" font-size="9" text-anchor="end" fill="#14b8a6">Ziel ${pct(target)}</text>
        ${dueDay <= span && X(dueDay) > 30 ? `<line x1="${X(dueDay)}" x2="${X(dueDay)}" y1="10" y2="110" stroke="#e0453a" stroke-width="1.5"/><text x="${X(dueDay) + (X(dueDay) > 220 ? -3 : 3)}" y="${Y(target) + 14}" font-size="9" text-anchor="${X(dueDay) > 220 ? "end" : "start"}" fill="#e0453a">Wiederholung</text>` : ""}
        ${nowDay <= span ? `<circle cx="${X(nowDay)}" cy="${Y(C.retrievability(nowDay, card.stability))}" r="5" fill="#ff8a5c"/>` : ""}
        <text x="10" y="123" font-size="9" fill="currentColor" opacity=".5">heute</text><text x="290" y="123" font-size="9" text-anchor="end" fill="currentColor" opacity=".5">${Math.round(span)} Tage</text>
      </svg>
      <div class="caption secondary">Ohne Wiederholung sinkt die Erinnerung. VocaDay fragt das Wort ab, kurz bevor sie unter dein Ziel fällt – jede richtige Antwort macht die Kurve flacher.</div></div>`;
  }
  return `<div class="overlay">${bar(w.translation)}<div class="body stack">
    ${heroCard(w).replace('data-action="word"', "")}
    ${w.alternatives?.length || w.note ? `<div class="card stack tight small">${w.alternatives?.length ? `<div>= auch: ${esc(w.alternatives.join(", "))}</div>` : ""}${w.note ? `<div class="row top"><span style="color:var(--almost)">${ic("bulb", 18)}</span><div>${esc(w.note)}</div></div>` : ""}</div>` : ""}
    <div class="grid two"><button class="btn" data-action="speak" data-text="${esc(C.parseCloze(w.exampleTarget).plain)}">${ic("play", 14)} Satz anhören</button><button class="btn" style="background:var(--sentence)" data-action="speak-slow" data-text="${esc(C.parseCloze(w.exampleTarget).plain)}">🐢 Langsam</button></div>
    ${memory}
    <div class="caption secondary center">${C.POS_NAMES[w.partOfSpeech]} · Platz ${w.rank} der häufigsten deutschen Wörter</div>
  </div></div>`;
}

function renderMethod() {
  const items = [
    ["chart", "Häufige Wörter zuerst", "Die Wörter stammen aus einer Häufigkeitsanalyse deutscher Untertitel. Die häufigsten Wörter decken einen Großteil der Alltagssprache ab – du lernst zuerst, was du am meisten brauchst."],
    ["list", "Reihum von A bis Z", "Im Standard-Modus kommt jeden Tag ein zufälliges Wort aus den häufigsten Wörtern des nächsten Buchstabens. So entsteht Abwechslung."],
    ["clock", "Verteilte Wiederholung (FSRS)", "VocaDay berechnet für jedes Wort, wann du es mit 90 % Wahrscheinlichkeit noch weißt, und fragt es genau dann ab. Jede erfolgreiche Wiederholung verlängert den Abstand – von Minuten über Tage bis zu Monaten."],
    ["target", "Abrufen statt Lesen", "Aktives Erinnern (Testing-Effekt) verankert Wörter deutlich stärker als wiederholtes Lesen. Deine Antworten steuern die nächsten Abstände."],
    ["layers", "Wachsende Schwierigkeit", "Neue Wörter erkennst du zuerst unter Auswahlmöglichkeiten. Je sicherer ein Wort sitzt, desto mehr musst du selbst produzieren: tippen, Lücken füllen, Sätze bauen."],
    ["bubble", "Lernen im Kontext", "Jedes Wort kommt mit einem Beispielsatz. Der Satztrainer übt Endungen und Satzstellung – so, wie du die Wörter wirklich verwendest."],
    ["checklist", "Wortschatz-Test", "Nur der erste Versuch zählt – so misst der Test ehrlich. Falsche Wörter wiederholst du sofort in einer Fehlerrunde (Mastery Learning)."],
    ["speaker", "Mischen und Aussprechen", "Neue und alte Wörter werden gemischt (Interleaving). Laut Nachsprechen verknüpft Klang und Bedeutung (Produktionseffekt)."],
  ];
  return `<div class="overlay">${bar("So lernst du")}<div class="body stack">${items.map(([i, t, d]) => `<div class="card row top">${gradIcon(i, COLORS.coral, "sm")}<div><h3>${t}</h3><div class="small secondary">${d}</div></div></div>`).join("")}</div></div>`;
}

// MARK: Actions

function downloadFile(name, type, text) {
  const blob = new Blob([text], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

function updateSettings(change) {
  const before = P().settings.newWordsPerDay;
  change(P().settings);
  P().settings.newWordsPerDay = Math.min(20, Math.max(1, P().settings.newWordsPerDay));
  const after = P().settings.newWordsPerDay;
  if (before !== after && P().settings.onboardingCompleted) {
    C.replanFuture(P(), state.bank, today());
    const missing = after - (P().plans[today()]?.wordIDs.length ?? 0);
    if (after > before && missing > 0) C.addExtraWords(missing, P(), state.bank, today());
  }
  save();
}

const actions = {
  tab: (d) => { state.tab = d.tab; window.scrollTo(0, 0); render(); },
  speak: (d) => speak(d.text),
  "speak-slow": (d) => speak(d.text, "tr-TR", true),
  word: (d) => openOverlay({ type: "word", id: d.id }, { stacked: ["group", "cards"].includes(state.overlay?.type) }),
  "words-mode": (d) => { state.wordsMode = d.mode; render(); },
  letter: (d) => { state.wordsLetter = d.letter || null; state.showAllLetter = false; render(); window.scrollTo(0, 0); },
  "show-all-letter": () => { state.showAllLetter = true; render(); },
  "more-history": () => { state.historyDays += 14; render(); },
  group: (d) => openOverlay({ type: "group", stage: d.stage, sort: "recent" }),
  "group-sort": (d) => { state.overlay.sort = d.sort; state.overlay.keepScroll = true; renderOverlay(); },
  cards: (d) => {
    let ids = [];
    if (d.set === "learned") ids = Object.keys(P().cards).filter(word).sort((a, b) => C.cardRecall(P().cards[a]) - C.cardRecall(P().cards[b]));
    if (d.set === "letter") ids = state.bank.words.filter((w) => C.letterFor(w.native) === state.wordsLetter && P().cards[w.id]).map((w) => w.id);
    if (d.set === "group") ids = groupIds(state.overlay.stage);
    const title = d.set === "letter" ? `Buchstabe ${state.wordsLetter}` : d.set === "group" ? STAGES.find(([k]) => k === state.overlay.stage)[1] : "Gelernte Wörter";
    openCards(ids, title);
  },
  flip: () => {
    if (swipeHandled) { swipeHandled = false; return; }
    const o = state.overlay;
    o.flipped = !o.flipped;
    document.getElementById("flipcard")?.classList.toggle("flipped", o.flipped);
    if (o.flipped) speak(word(o.ids[o.index]).translation);
  },
  "card-step": (d) => stepCard(Number(d.delta)),
  "card-shuffle": () => { const o = state.overlay; o.ids = C.shuffle(o.ids); o.index = 0; o.flipped = false; renderOverlay(); toast("Gemischt"); },
  "learn-now": (d) => {
    if (C.addSpecificWord(d.id, P(), state.bank, today())) {
      save();
      vibrate(true);
      toast("Zu heute hinzugefügt – los geht's im Tab „Heute“.");
    }
    state.overlay.keepScroll = true;
    renderOverlay();
  },
  "learn-now-start": () => {
    state.overlay = null;
    document.body.style.overflow = "";
    state.tab = "today";
    render();
    actions["start-daily"]();
  },
  "hide-install": () => { localStorage.setItem("vocaday.hideInstall", "1"); render(); },
  "backup-later": () => { localStorage.setItem("vocaday.backupSnooze", String(Date.now())); render(); },
  method: () => openOverlay({ type: "method" }),
  close: () => {
    const o = state.overlay;
    if (o?.type === "session" && !o.session.finished && o.session.answered) C.addStudyTime(P(), (Date.now() - o.startedAt) / 1000);
    if (o?.type === "test" && !o.saved && o.test.answeredFirstTry) C.addStudyTime(P(), (Date.now() - o.test.startedAt) / 1000);
    save();
    closeOverlay();
  },
  "start-daily": () => startSession("Heute lernen", C.dailySession(P(), state.index, Date.now(), style())),
  "start-sentences": () => {
    let s = C.dailySession(P(), state.index, Date.now(), "sentences", false);
    if (!s.items.length) s = C.practiceSession(P(), state.index, Date.now(), "sentences");
    startSession("Satztrainer", s);
  },
  "start-free": () => startSession("Freies Üben", C.practiceSession(P(), state.index, Date.now(), style())),
  "extra-word": () => {
    const [w] = C.addExtraWords(1, P(), state.bank, today());
    save();
    state.draft = { added: w?.translation };
    vibrate(true);
    toast(w ? `Neues Wort: ${w.translation} – ${C.withArticle(w)}` : "Alle Wörter sind schon geplant.");
    render();
  },
  "open-test": () => openOverlay({ type: "testSetup", scope: "all", direction: "mixed", mode: "choice" }),
  setup: (d) => { state.overlay[d.group] = d.value; state.overlay.keepScroll = true; renderOverlay(); },
  "start-test": () => { const o = state.overlay; startTest(o.scope, o.direction, o.mode); },
  retest: () => { const t = state.overlay.test; startTest("mistakes", t.direction, t.mode, t.mistakes); },
  continue: () => {
    const ctx = state.overlay.ctx;
    const k = ctx.item.kind;
    if (k === "introduction") return finishExercise(null);
    if (ctx.selected != null) return finishExercise(ctx.selected === ctx.correct ? C.RATING.good : C.RATING.again);
    if (ctx.verdict) return finishExercise(C.ratingForVerdict(ctx.verdict.verdict));
    if (ctx.built != null) return finishExercise(ctx.built ? C.RATING.good : C.RATING.again);
  },
  choose: (d) => {
    const ctx = state.overlay.ctx;
    if (ctx.selected != null) return;
    ctx.selected = Number(d.index);
    vibrate(ctx.selected === ctx.correct);
    state.overlay.keepScroll = true;
    renderOverlay();
  },
  char: (d) => {
    const input = overlayRoot.querySelector("input[data-input='answer']");
    if (!input) return;
    input.value += d.char;
    state.overlay.ctx.input = input.value;
    input.focus();
  },
  hint: () => { state.overlay.ctx.hint = true; state.overlay.ctx.input = currentInput(); state.overlay.keepScroll = true; renderOverlay(); },
  check: () => checkTyped(),
  "dont-know": () => {
    const ctx = state.overlay.ctx;
    ctx.input = "";
    ctx.verdict = { verdict: "wrong", expected: typedAccepted(ctx)[0] };
    vibrate(false);
    renderOverlay();
  },
  override: () => finishExercise(C.RATING.hard),
  reveal: () => { state.overlay.ctx.revealed = true; speak(state.overlay.ctx.word.translation); state.overlay.keepScroll = true; renderOverlay(); },
  rate: (d) => finishExercise(Number(d.rating)),
  pick: (d) => { state.overlay.ctx.chosen.push(Number(d.index)); state.overlay.keepScroll = true; renderOverlay(); },
  unpick: (d) => {
    const ctx = state.overlay.ctx;
    if (ctx.built != null) return;
    ctx.chosen = ctx.chosen.filter((i) => i !== Number(d.index));
    state.overlay.keepScroll = true;
    renderOverlay();
  },
  "build-check": () => {
    const ctx = state.overlay.ctx;
    ctx.built = C.normalize(ctx.chosen.map((i) => ctx.tokens[i]).join(" ")) === C.normalize(ctx.cloze.plain);
    vibrate(ctx.built);
    state.overlay.keepScroll = true;
    renderOverlay();
  },
  "per-day": (d) => { updateSettings((s) => { s.newWordsPerDay += Number(d.delta); }); render(); },
  toggle: (d) => { updateSettings((s) => { s[d.key] = !s[d.key]; }); render(); },
  calendar: () => {
    C.ensurePlans(P(), state.bank, today());
    save();
    downloadFile("VocaDay-Erinnerungen.ics", "text/calendar", C.calendarICS(P(), state.index, location.href.split("#")[0]));
    toast("Kalenderdatei erstellt – tippe auf „Alle hinzufügen“.");
  },
  export: () => {
    localStorage.setItem("vocaday.lastBackup", String(Date.now()));
    downloadFile(`VocaDay-Sicherung-${today()}.json`, "application/json", JSON.stringify(P(), null, 1));
  },
  reset: () => {
    if (!confirm("Wirklich alle gelernten Wörter und Statistiken löschen?")) return;
    const settings = P().settings;
    state.progress = C.newProgress(settings);
    ensurePlans();
    render();
  },
  "onb-next": () => {
    if (state.onboardingStep < 3) { state.onboardingStep++; render(); return; }
    P().settings.onboardingCompleted = true;
    ensurePlans();
    render();
  },
  "onb-back": () => { state.onboardingStep = Math.max(0, state.onboardingStep - 1); render(); },
};

function stepCard(delta) {
  const o = state.overlay;
  if (o?.type !== "cards") return;
  const next = o.index + delta;
  if (next < 0 || next >= o.ids.length) return;
  o.index = next;
  o.flipped = false;
  o.slide = delta > 0 ? "next" : "prev";
  renderOverlay();
}

let swipeStart = null;
let swipeHandled = false;

document.addEventListener("touchstart", (event) => {
  if (!event.target.closest?.("#flipcard")) return;
  swipeStart = { x: event.touches[0].clientX, y: event.touches[0].clientY };
}, { passive: true });

document.addEventListener("touchend", (event) => {
  if (!swipeStart) return;
  const dx = event.changedTouches[0].clientX - swipeStart.x;
  const dy = event.changedTouches[0].clientY - swipeStart.y;
  swipeStart = null;
  if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy)) {
    swipeHandled = true;
    setTimeout(() => { swipeHandled = false; }, 400);
    stepCard(dx < 0 ? 1 : -1);
  }
});

document.addEventListener("keydown", (event) => {
  if (state.overlay?.type !== "cards") return;
  if (event.key === "ArrowRight") stepCard(1);
  if (event.key === "ArrowLeft") stepCard(-1);
  if (event.key === " ") { event.preventDefault(); actions.flip(); }
});

function currentInput() {
  return overlayRoot.querySelector("input[data-input='answer']")?.value ?? "";
}

function typedAccepted(ctx) {
  const w = ctx.word;
  if (ctx.item.kind === "typeNative") return [w.native, C.withArticle(w)];
  if (ctx.item.kind === "clozeType") return [ctx.cloze.answer];
  return C.accepted(w);
}

function checkTyped() {
  const ctx = state.overlay?.ctx;
  if (!ctx || ctx.verdict) return;
  const value = currentInput();
  if (!value.trim()) return;
  ctx.input = value;
  ctx.verdict = C.checkAnswer(value, typedAccepted(ctx));
  vibrate(ctx.verdict.verdict !== "wrong");
  document.activeElement?.blur();
  renderOverlay();
}

document.addEventListener("click", (event) => {
  const el = event.target.closest("[data-action]");
  if (!el || el.disabled) return;
  const handler = actions[el.dataset.action];
  if (handler) {
    event.preventDefault();
    handler(el.dataset);
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && event.target.matches?.("input[data-input='answer']")) {
    event.preventDefault();
    checkTyped();
  }
});

document.addEventListener("input", (event) => {
  const el = event.target;
  if (el.dataset?.input === "search") {
    state.search = el.value;
    const results = document.getElementById("word-results");
    if (results) {
      results.innerHTML = renderWordsBody();
      animateRings(results);
    }
  }
  if (el.dataset?.input === "answer" && state.overlay?.ctx) state.overlay.ctx.input = el.value;
});

document.addEventListener("change", async (event) => {
  const el = event.target;
  if (el.dataset?.input === "retention") { updateSettings((s) => { s.desiredRetention = Number(el.value); }); render(); }
  if (el.dataset?.input === "time") {
    const [h, m] = el.value.split(":").map(Number);
    updateSettings((s) => { s.notificationHour = h || 0; s.notificationMinute = m || 0; });
  }
  if (el.dataset?.input === "import" && el.files?.[0]) {
    try {
      const data = JSON.parse(await el.files[0].text());
      if (!data.settings || !data.cards || !data.plans) throw new Error("kein VocaDay-Lernstand");
      state.progress = { ...C.newProgress(), ...data };
      ensurePlans();
      toast("Lernstand wiederhergestellt.");
      render();
    } catch (error) {
      toast(`Datei konnte nicht gelesen werden: ${error.message}`);
    }
  }
});

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && state.bank && P().settings.onboardingCompleted) {
    ensurePlans();
    if (!state.overlay) render();
  }
});

// MARK: Boot

async function boot() {
  try {
    const response = await fetch("words_de_tr.json");
    state.bank = await response.json();
  } catch (error) {
    app.innerHTML = `<div class="onboarding"><h1>Keine Verbindung</h1><p class="secondary">Die Wortdatenbank konnte nicht geladen werden. Bitte einmal mit Internet öffnen – danach funktioniert VocaDay auch offline.</p></div>`;
    return;
  }
  state.bank.words.sort((a, b) => a.rank - b.rank);
  state.index = new Map(state.bank.words.map((w) => [w.id, w]));
  state.progress = load();
  state.progress.tests ??= [];
  if (state.progress.settings.onboardingCompleted) ensurePlans();
  render();
  setTimeout(() => app.querySelector(".alphabet .current")?.scrollIntoView({ inline: "center", block: "nearest" }), 300);
  navigator.storage?.persist?.();
  if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(() => {});
}

boot();
