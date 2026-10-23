#!/usr/bin/env python3
"""Builds the German lemma frequency ranking that VocaDay uses as its word pool.

Source: hermitdave/FrequencyWords (OpenSubtitles 2018, CC BY-SA 4.0).
Word forms are lemmatized with simplemma and their counts summed per lemma,
so "ist", "war" and "bin" all count towards "sein".

Usage:
    pip install simplemma
    python3 tools/data/build_frequency.py [--top 6000] [--out data/de_lemma_frequency.tsv]
"""
import argparse
import collections
import sys
import urllib.request

import simplemma

SOURCE_URL = (
    "https://raw.githubusercontent.com/hermitdave/FrequencyWords/"
    "master/content/2018/de/de_50k.txt"
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--top", type=int, default=6000)
    parser.add_argument("--out", default="data/de_lemma_frequency.tsv")
    parser.add_argument("--source", help="local copy of de_50k.txt (skips download)")
    args = parser.parse_args()

    if args.source:
        with open(args.source, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    else:
        with urllib.request.urlopen(SOURCE_URL) as resp:
            lines = resp.read().decode("utf-8").splitlines()

    counts: collections.Counter[str] = collections.Counter()
    for line in lines:
        parts = line.split()
        if len(parts) != 2 or not parts[1].isdigit():
            continue
        form, count = parts[0], int(parts[1])
        if not form.isalpha() or len(form) < 2:
            continue
        lemma = simplemma.lemmatize(form, lang="de").lower()
        counts[lemma] += count

    total = sum(counts.values())
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write("rank\tlemma\tcount\tper_million\n")
        for rank, (lemma, count) in enumerate(counts.most_common(args.top), start=1):
            fh.write(f"{rank}\t{lemma}\t{count}\t{count / total * 1e6:.1f}\n")
    print(f"wrote {args.top} lemmas to {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
