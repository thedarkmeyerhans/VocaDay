#!/usr/bin/env python3
"""Extracts German meaning explanations ("Bedeutungen") from the German Wiktionary.

For every word of the bank it picks the sense that fits the Turkish translation:
Wiktionary lists translations per sense (``*{{tr}}: [1] {{Ü|tr|ev}}``), so the sense
whose Turkish translation matches ours is used. Without a match the first sense
of the matching part of speech is taken.

Input:  data/<native>-<target>/*.txt (the curated entries)
        Wiktionary wikitext, either fetched live from de.wiktionary.org or read from
        a cache file (JSON: {"title": "wikitext", ...}) via --cache
Output: data/<native>_definitions.tsv (native, pos, sense, matched, definition)

The definitions are licensed CC BY-SA 4.0 (Wiktionary contributors).

Usage:
    python3 tools/data/build_definitions.py                 # fetch from Wiktionary
    python3 tools/data/build_definitions.py --cache p.json  # use downloaded pages
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_dataset import ROOT, parse_entries  # noqa: E402

API = "https://de.wiktionary.org/w/api.php"
# Hand-checked choices where the automatic one picks a rare or technical meaning:
# (index of the matching part-of-speech section, sense), a replacement text, or None (no definition).
SENSE_OVERRIDES = {
    "Gesetz": (0, "1"), "reagieren": (0, "1"), "fertig": (0, "1"), "draußen": (0, "1"),
    "Hals": (0, "1"), "Aufgabe": (0, "1"), "Rest": (0, "1"), "Art": (0, "1"), "abbiegen": (0, "2"),
    "beibringen": (0, "3"), "beschreiben": (0, "2"), "beschweren": (0, "2"), "buchen": (0, "3"),
    "durchfallen": (0, "2a"), "entspannen": (0, "2"), "erfüllen": (0, "2"), "entlassen": (0, "2"),
    "Droge": (0, "2"), "ganz": (0, "2"), "landen": (0, "2"), "lassen": (0, "7"), "mögen": (1, "1"),
    "passieren": (0, "3"), "reichen": (0, "5"), "schaffen": (1, "1"), "rühren": (0, "2"), "speichern": (0, "2"),
    "warum": (0, "2"), "vor": (0, "2"), "unser": (1, "1"), "unterhalten": (0, "2"), "wehen": (0, "2"),
    "wechseln": (0, "2"), "Bar": (1, "1"), "Januar": "erster, 31-tägiger Monat im Kalenderjahr",
    "gehen": "sich (zu Fuß) irgendwohin begeben; einen Ort verlassen", "verbinden": (0, "2"), "erklären": (0, "1"), "Ordnung": (0, "3"),
    "kosten": "einen bestimmten Preis haben; etwas verlangt einen bestimmten Einsatz",
    "verbringen": None, "so": None, "alle": None, "leid": None,
}
WORTART = {
    "n": ["Substantiv"],
    "v": ["Verb", "Hilfsverb", "Modalverb"],
    "adj": ["Adjektiv", "Partizip II", "Partizip I"],
    "adv": ["Adverb", "Temporaladverb", "Lokaladverb", "Modaladverb", "Kausaladverb", "Pronominaladverb",
            "Interrogativadverb", "Gradpartikel", "Fokuspartikel", "Partikel"],
    "pron": ["Personalpronomen", "Pronomen", "Demonstrativpronomen", "Possessivpronomen", "Indefinitpronomen",
             "Interrogativpronomen", "Relativpronomen", "Reflexivpronomen"],
    "prep": ["Präposition"],
    "conj": ["Konjunktion", "Subjunktion"],
    "num": ["Numerale", "Kardinalzahl", "Ordinalzahl", "Ordnungszahl"],
    "intj": ["Interjektion", "Grußformel", "Antwortpartikel"],
    "phr": ["Redewendung", "Wortverbindung", "Grußformel", "Sprichwort"],
    "x": [],
}
LABELS = {
    "ugs.": "umgangssprachlich", "übertr.": "übertragen", "trans.": "transitiv", "intrans.": "intransitiv",
    "refl.": "reflexiv", "Pl.": "Plural", "Sg.": "Singular", "va.": "veraltet", "geh.": "gehoben",
    "fachspr.": "fachsprachlich", "abw.": "abwertend", "scherzh.": "scherzhaft", "kPl.": "kein Plural",
    "intr.": "intransitiv", "unpers.": "unpersönlich", "Hilfsverb haben": "mit „haben“",
    "Hilfsverb sein": "mit „sein“", "salopp": "salopp", "derb": "derb",
}


def fetch(titles: list) -> dict:
    pages = {}
    for i in range(0, len(titles), 50):
        query = urllib.parse.urlencode({
            "action": "query", "prop": "revisions", "rvprop": "content", "rvslots": "main",
            "format": "json", "formatversion": 2, "redirects": 1, "titles": "|".join(titles[i:i + 50]),
        })
        request = urllib.request.Request(f"{API}?{query}", headers={"User-Agent": "VocaDay/1.0 (word bank build)"})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = json.load(response)
        for page in data["query"]["pages"]:
            if "revisions" in page:
                pages[page["title"]] = page["revisions"][0]["slots"]["main"]["content"]
        time.sleep(1)
    return pages


def german_section(text: str) -> str:
    match = re.search(r"^== .*\{\{Sprache\|Deutsch\}\}.*==\s*$", text, re.M)
    if not match:
        return ""
    rest = text[match.end():]
    end = re.search(r"^== [^=]", rest, re.M)
    return rest[:end.start()] if end else rest


def pos_sections(section: str) -> list:
    """[((wortart names, heading), text)] for every === heading of the German section."""
    parts = re.split(r"^=== (.*?) ===\s*$", section, flags=re.M)
    result = []
    for heading, body in zip(parts[1::2], parts[2::2]):
        names = re.findall(r"\{\{Wortart\|([^|}]+)\|Deutsch\}\}", heading)
        result.append(((names, heading), body))
    return result


def template_args(inner: str) -> list:
    return [a.strip() for a in inner.split("|")]


def clean(text: str) -> str:
    text = re.sub(r"<ref[^>]*/>|<ref[^>]*>.*?</ref>", "", text, flags=re.S)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = text.replace("&nbsp;", " ")
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\s*\[\d+[a-z]?(?:,\s*\d+[a-z]?)*\]", "", text)  # references to other senses

    def label(match):
        args = template_args(match.group(1))[1:]
        words = []
        for a in args:
            if a.startswith("ft="):
                words.append(a[3:])
            elif "=" not in a and a:
                words.append(LABELS.get(a, a.rstrip(".") if a.endswith(".") and len(a) < 6 else a))
        return f"({', '.join(words)}) " if words else ""

    # Labels like {{K|ugs.|trans.}} become "(umgangssprachlich, transitiv)".
    for _ in range(3):
        text = re.sub(r"\{\{K\|([^{}]*)\}\}", label, text)
    text = re.sub(r"\{\{(ugs\.|übertr\.|trans\.|intrans\.|refl\.|Pl\.|Sg\.|va\.|kPl\.)\}\}",
                  lambda m: f"({LABELS[m.group(1)]}) ", text)
    text = re.sub(r"\{\{(?:QS [^{}]*|Ref-[^{}]*|Lit-[^{}]*)\}\}", "", text)
    text = re.sub(r"\{\{[^{}|]*\|([^{}|]*)\}\}", r"\1", text)  # {{Ü|…}}-like one-argument templates
    text = re.sub(r"\{\{[^{}]*\}\}", "", text)
    text = re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", text)
    text = re.sub(r"'''?", "", text)
    text = re.sub(r"\s+", " ", text).strip(" ;:,")
    text = re.sub(r"\(\s*\)", "", text)
    text = re.sub(r"\s+([,.;:)])", r"\1", text).strip()
    text = re.sub(r";+", ";", text)
    return text


def senses(body: str) -> list:
    """[(sense label, raw text)] from the {{Bedeutungen}} block."""
    match = re.search(r"\{\{Bedeutungen\}\}\s*\n(.*?)(?:\n\s*\n|\n\{\{(?!K\|)[A-ZÄÖÜ])", body, re.S)
    if not match:
        return []
    result = []
    for line in match.group(1).splitlines():
        m = re.match(r"^:+\s*\[([^\]]+)\]\s*(.*)$", line)
        if m and m.group(2).strip():
            result.append((m.group(1).strip(), m.group(2)))
    return result


def turkish_senses(body: str) -> dict:
    """{normalized Turkish word: [sense labels]} from the translation tables.

    Translations are grouped per sense in {{Ü-Tabelle|<sense>|…}} blocks; lines may
    also carry inline sense labels like ``[1, 2]``.
    """
    found, table = {}, "1"
    for line in body.splitlines():
        start = re.search(r"\{\{Ü-Tabelle\|([^|}]+)", line)
        if start:
            table = start.group(1).strip()
        if not line.startswith("*{{tr}}:"):
            continue
        current = [table]
        for token in re.finditer(r"\[([^\]]+)\]|\{\{Ü[^|]*\|tr\|([^}|]+)(?:\|[^}]*)?\}\}", line):
            if token.group(1):
                current = [x.strip() for x in re.split(r"[,–-]", token.group(1)) if x.strip()]
            elif token.group(2):
                found.setdefault(norm(token.group(2)), []).extend(current)
    return found


def norm(text: str) -> str:
    text = text.replace("I", "ı").replace("İ", "i").lower()
    text = text.replace("â", "a").replace("î", "i").replace("û", "u")
    return re.sub(r"[^a-zçğıöşü ]", "", text).strip()


def definition_for(entry: dict, text: str) -> tuple:
    section = german_section(text)
    if not section:
        return None
    sections = pos_sections(section)
    wanted = WORTART.get(entry["pos"], [])
    gender = {"der": "{{m}}", "die": "{{f}}", "das": "{{n}}"}.get(entry["article"])
    chosen = [(heading, body) for heading, body in sections if any(n in wanted for n in heading[0])]
    if gender and any(gender in h[1] for h, _ in chosen):
        chosen = [(h, b) for h, b in chosen if gender in h[1]]
    if not chosen:
        chosen = sections
    ours = [entry["translation"]] + [a.strip() for a in entry["alternatives"].split(";") if a.strip()]

    candidates = []
    for _, body in chosen:
        meaning = senses(body)
        if not meaning:
            continue
        labels = [label for label, _ in meaning]
        table = turkish_senses(body)
        sense = None
        for candidate in ours:
            for label in table.get(norm(candidate), []):
                sense = label if label in labels else next((x for x in labels if x.startswith(label)), None)
                if sense:
                    break
            if sense:
                break
        candidates.append((sense is not None, sense or labels[0], meaning))
    # Prefer a section whose Turkish translation matches ours.
    candidates.sort(key=lambda c: not c[0])
    if entry["native"] in SENSE_OVERRIDES:
        override = SENSE_OVERRIDES[entry["native"]]
        if override is None or isinstance(override, str):
            return ("1", True, override) if override else None
        index, sense = override
        bodies = [body for (names, _), body in sections if any(n in wanted for n in names) and senses(body)]
        if index >= len(bodies) or sense not in dict(senses(bodies[index])):
            raise SystemExit(f"override for {entry['native']} does not fit the Wiktionary entry")
        meaning = dict(senses(bodies[index]))
        return sense, True, clean(meaning[sense])
    for matched, sense, meaning in candidates:
        cleaned = clean(dict(meaning)[sense])
        if len(cleaned) < 3:
            continue
        if len(cleaned) > 240:
            cleaned = cleaned[:237].rsplit(" ", 1)[0] + " …"
        return sense, matched, cleaned
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pair", default="de-tr")
    parser.add_argument("--cache", help="JSON file with downloaded pages instead of fetching")
    args = parser.parse_args()
    native, _ = args.pair.split("-")
    entries = parse_entries(os.path.join(ROOT, "data", args.pair))
    titles = sorted({e["native"] for e in entries})
    pages = json.load(open(args.cache, encoding="utf-8")) if args.cache else fetch(titles)

    rows, unmatched, missing = [], [], []
    for e in entries:
        result = definition_for(e, pages.get(e["native"], ""))
        if not result:
            missing.append(e["native"])
            continue
        sense, matched, text = result
        if not matched:
            unmatched.append(f"{e['native']} → {e['translation']}")
        rows.append(f"{e['native']}\t{e['pos']}\t{sense}\t{int(matched)}\t{text}")

    out = os.path.join(ROOT, "data", f"{native}_definitions.tsv")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("native\tpos\tsense\tmatched\tdefinition\n")
        fh.write("\n".join(sorted(rows)) + "\n")
    print(f"{len(rows)} definitions, {len(rows) - len(unmatched)} matched via Turkish translation, "
          f"{len(missing)} without entry")
    if missing:
        print("without definition:", ", ".join(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
