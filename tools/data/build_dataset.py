#!/usr/bin/env python3
"""Validates the curated word lists and builds the JSON word bank the app ships.

Input:  data/<native>-<target>/*.txt   (curated entries, see data/README.md)
        data/de_lemma_frequency.tsv    (from build_frequency.py)
Output: App/Resources/words_<native>_<target>.json

Usage:
    python3 tools/data/build_dataset.py            # build
    python3 tools/data/build_dataset.py --check    # fail if the JSON is out of date
"""
import argparse
import glob
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
POS = {
    "n": "noun", "v": "verb", "adj": "adjective", "adv": "adverb", "pron": "pronoun",
    "prep": "preposition", "conj": "conjunction", "num": "numeral", "intj": "interjection",
    "phr": "phrase", "x": "other",
}
ARTICLES = {"", "der", "die", "das"}
FIELDS = ["native", "article", "pos", "translation", "alternatives", "example_native",
          "example_target", "note", "keys"]
ATTRIBUTION = (
    "Worthäufigkeit: FrequencyWords von Hermit Dave (OpenSubtitles 2018), CC BY-SA 4.0. "
    "Lemmatisierung: simplemma. Übersetzungen und Beispielsätze: VocaDay."
)


def slug(text: str) -> str:
    text = text.lower()
    for a, b in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        text = text.replace(a, b)
    text = unicodedata.normalize("NFKD", text)
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def load_frequency(path: str) -> dict:
    ranks = {}
    with open(path, encoding="utf-8") as fh:
        next(fh)
        for line in fh:
            rank, lemma, _count, _pm = line.rstrip("\n").split("\t")
            ranks.setdefault(lemma, int(rank))
    return ranks


def parse_entries(pair_dir: str) -> list:
    entries = []
    for path in sorted(glob.glob(os.path.join(pair_dir, "*.txt"))):
        with open(path, encoding="utf-8") as fh:
            for number, raw in enumerate(fh, start=1):
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                parts = [p.strip() for p in line.split("|")]
                if len(parts) < 7 or len(parts) > len(FIELDS):
                    raise SystemExit(f"{path}:{number}: expected 7-9 fields, got {len(parts)}")
                parts += [""] * (len(FIELDS) - len(parts))
                entry = dict(zip(FIELDS, parts))
                entry["where"] = f"{os.path.basename(path)}:{number}"
                entries.append(entry)
    return entries


def build(native: str, target: str) -> dict:
    ranks = load_frequency(os.path.join(ROOT, "data", f"{native}_lemma_frequency.tsv"))
    entries = parse_entries(os.path.join(ROOT, "data", f"{native}-{target}"))
    errors, words, seen_ids, seen_natives = [], [], set(), {}
    fallback = len(ranks) + 1

    for e in entries:
        where = e["where"]
        if e["pos"] not in POS:
            errors.append(f"{where}: unknown part of speech '{e['pos']}'")
            continue
        if e["article"] not in ARTICLES:
            errors.append(f"{where}: bad article '{e['article']}'")
        if e["pos"] == "n" and not e["article"] and not e["note"]:
            errors.append(f"{where}: noun '{e['native']}' without article")
        if e["example_target"].count("[") != 1 or e["example_target"].count("]") != 1:
            errors.append(f"{where}: example_target needs exactly one [marked] word")
        if not e["translation"] or not e["example_native"]:
            errors.append(f"{where}: translation and example_native are required")

        key = (e["native"].lower(), e["pos"])
        if key in seen_natives:
            errors.append(f"{where}: duplicate of {seen_natives[key]}")
        seen_natives[key] = where

        word_id = slug(e["native"])
        if word_id in seen_ids:
            word_id = f"{word_id}-{POS[e['pos']]}"
        if word_id in seen_ids:
            errors.append(f"{where}: id collision '{word_id}'")
        seen_ids.add(word_id)

        rank = None
        keys = [k for k in e["keys"].split(",") if k] or [e["native"].lower()]
        for k in keys:
            if k.startswith("#"):
                rank = int(k[1:])
                break
            if k in ranks:
                rank = min(rank or ranks[k], ranks[k])
        if rank is None:
            rank = fallback
            fallback += 1

        words.append({
            "id": word_id,
            "rank": rank,
            "native": e["native"],
            "article": e["article"] or None,
            "partOfSpeech": POS[e["pos"]],
            "translation": e["translation"],
            "alternatives": [a.strip() for a in e["alternatives"].split(";") if a.strip()],
            "exampleNative": e["example_native"],
            "exampleTarget": e["example_target"],
            "note": e["note"] or None,
        })

    if errors:
        raise SystemExit("\n".join(errors))
    words.sort(key=lambda w: (w["rank"], w["id"]))
    return {
        "pair": {"native": native, "target": target},
        "version": 1,
        "attribution": ATTRIBUTION,
        "words": words,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pair", default="de-tr")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    native, target = args.pair.split("-")

    bank = build(native, target)
    out = os.path.join(ROOT, "App", "Resources", f"words_{native}_{target}.json")
    text = json.dumps(bank, ensure_ascii=False, indent=1) + "\n"

    if args.check:
        current = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
        if current != text:
            print(f"{out} is out of date, run tools/data/build_dataset.py", file=sys.stderr)
            return 1
        print(f"{len(bank['words'])} words, up to date")
        return 0

    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(text)
    letters = {}
    for w in bank["words"]:
        first = w["native"][0].upper().translate(str.maketrans("ÄÖÜ", "AOU"))
        letters[first] = letters.get(first, 0) + 1
    print(f"wrote {len(bank['words'])} words to {os.path.relpath(out, ROOT)}")
    print("per letter:", " ".join(f"{k}:{v}" for k, v in sorted(letters.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
