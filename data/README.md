# Wortdaten

Die Wortdatenbank entsteht in zwei Schritten:

1. **Häufigkeit** – `tools/data/build_frequency.py` lädt die deutsche Häufigkeitsliste aus
   [FrequencyWords](https://github.com/hermitdave/FrequencyWords) (OpenSubtitles 2018, CC BY-SA 4.0).
   Sie führt jede Wortform mit [simplemma](https://github.com/adbar/simplemma) auf ihre Grundform zurück
   („ist“, „war“, „bin“ → „sein“) und summiert die Häufigkeiten pro Grundform.
   Das Ergebnis ist `de_lemma_frequency.tsv` (Rang, Grundform, Anzahl, pro Million).
2. **Kuratierte Einträge** – `de-tr/*.txt` enthält die deutschen Wörter in der Reihenfolge dieser Rangliste,
   jeweils mit türkischer Übersetzung und Beispielsätzen. Namen, englische Wörter, Füllwörter und
   Kraftausdrücke aus den Untertiteln sind herausgefiltert; Lemmatisierungsfehler sind korrigiert
   (z. B. „tagen“ → Tag).

3. **Bedeutungen** – `tools/data/build_definitions.py` holt für jedes Wort die deutsche Bedeutungserklärung
   aus dem [Wiktionary](https://de.wiktionary.org) (CC BY-SA 4.0). Weil das Wiktionary die Übersetzungen
   nach Bedeutungen ordnet, wird die Bedeutung gewählt, zu der unsere türkische Übersetzung passt
   (z. B. *Bar* → Lokal statt Maßeinheit). Wo das nicht greift, sind Bedeutungen von Hand festgelegt
   (`SENSE_OVERRIDES`). Ergebnis: `de_definitions.tsv`.

   Warum nicht Duden oder DWDS? Deren Bedeutungsangaben sind urheberrechtlich geschützt und dürfen nicht
   in eine App übernommen werden. Das Wiktionary steht unter einer freien Lizenz.

`tools/data/build_dataset.py` prüft die Einträge und erzeugt daraus `App/Resources/words_de_tr.json`,
die mit der App ausgeliefert wird. Die CI schlägt fehl, wenn die JSON-Datei nicht zu den Einträgen passt.

## Format der Einträge

Eine Zeile pro Wort, Felder durch `|` getrennt:

```
Deutsch | Artikel | Wortart | Übersetzung | weitere Übersetzungen (;) | Beispiel DE | Beispiel TR mit [Lücke] | Hinweis | Häufigkeits-Schlüssel (,)
Haus | das | n | ev |  | Unser Haus ist klein. | [Evimiz] küçük. |  | haus,hausen
```

- **Wortart**: `n` Nomen, `v` Verb, `adj`, `adv`, `pron`, `prep`, `conj`, `num`, `intj`, `phr` (Wendung), `x`.
- **Beispiel TR**: Genau ein Wort steht in eckigen Klammern. Daraus werden Lückentext und Satzbau-Übung gebaut.
  Die Klammer enthält das Wort so, wie es im Satz steht, also mit Endungen.
- **Häufigkeits-Schlüssel**: Grundformen aus `de_lemma_frequency.tsv`, aus denen der Rang kommt
  (Standard: das Wort in Kleinbuchstaben). `#900` setzt den Rang direkt.

## Wörter hinzufügen oder korrigieren

```sh
# Einträge in data/de-tr/*.txt bearbeiten, dann:
python3 tools/data/build_dataset.py
```

Die Übersetzungen und Beispielsätze wurden für VocaDay erstellt und sollten von Muttersprachlern
gegengelesen werden. Korrekturen sind willkommen.

## Lizenz

`de_lemma_frequency.tsv` ist aus FrequencyWords abgeleitet und steht wie die Quelle unter
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Die Quelle wird in der App
unter *Einstellungen › Quellen & Lizenzen* genannt.
