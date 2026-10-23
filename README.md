# VocaDay

**Jeden Tag mindestens ein neues Wort.** VocaDay ist eine iPhone- und iPad-App zum Vokabellernen. Sie wählt die Wörter nach Häufigkeit aus, wiederholt sie wissenschaftlich fundiert und übt sie aktiv in Sätzen.

Erste Sprachrichtung: **Deutsch → Türkisch** (1.102 Wörter).

## So funktioniert die App

- **Muttersprache und Lernsprache** wählt man beim ersten Start. Start: Deutsch → Türkisch.
- **Standard-Modus:** Grundlage ist eine Häufigkeitsanalyse der Muttersprache. Jeden Tag kommt ein zufälliges Wort aus den häufigsten Wörtern des nächsten Buchstabens: A, B, C … Z, dann wieder A. Buchstaben ohne passende Wörter (X, Y) werden übersprungen. Weitere Modi lassen sich über `SelectionMode` ergänzen.
- **Anzahl pro Tag** ist einstellbar (1–20). „Noch ein Wort“ holt jederzeit ein zusätzliches Wort, ohne die A–Z-Reihenfolge zu stören.
- **Verpasste Tage** gehen nicht verloren: Ihre Wörter kommen am nächsten Lerntag dazu.
- **Benachrichtigungen:** Morgens das Wort des Tages direkt in der Mitteilung („ev – das Haus“), abends eine Erinnerung, aber nur wenn noch etwas offen ist. Alles lokal, ohne Server.
- **Aussprache** über die türkische Systemstimme, auch langsam.

## Lernsystem

| Prinzip | Umsetzung |
| --- | --- |
| Verteilte Wiederholung | **FSRS-5**, der Algorithmus, den auch Anki nutzt. Jedes Wort hat Stabilität und Schwierigkeit. Es wird abgefragt, kurz bevor die Erinnerungswahrscheinlichkeit unter das Behaltensziel fällt (Standard 90 %, einstellbar). |
| Abrufen statt Lesen (Testing-Effekt) | Jede Wiederholung ist eine Abfrage. Die Antwort bestimmt den nächsten Abstand. |
| Wachsende Schwierigkeit | Neue Wörter: erst Erkennen (Auswahl). Je stabiler ein Wort, desto mehr muss man selbst produzieren: tippen, Lücke füllen, Satz bauen. |
| Lernen im Kontext | Jedes Wort hat einen Beispielsatz. Der **Satztrainer** übt Lückentexte (Auswahl/Tippen) und das Zusammensetzen ganzer Sätze. |
| Interleaving | Neue Wörter werden zwischen Wiederholungen gestreut. Falsche Antworten kommen in derselben Einheit etwas später noch einmal. |
| Aussprechen | Vorlesefunktion und Hinweis zum lauten Nachsprechen (Produktionseffekt). |

Tippantworten werden tolerant geprüft: Groß-/Kleinschreibung mit türkischem I/ı, fehlende Sonderzeichen (`ogretmen` statt `öğretmen`) und kleine Tippfehler zählen als „fast richtig“. Eine Leiste liefert die Zeichen ç ğ ı İ ö ş ü.

## Projektaufbau

```
App/                       SwiftUI-App (iOS 17+, iPhone & iPad)
  Model/AppModel.swift     Zustand, Speicherung, Sessions
  Views/                   Heute, Üben, Wörter, Einstellungen, Onboarding, Übungen
  Support/                 Benachrichtigungen, Sprachausgabe, Layout
  Resources/               Wortdatenbank (JSON), App-Icon
Packages/VocaDayCore/      Plattformunabhängige Logik + Tests
  WordSelection.swift      Standard-Modus (A–Z-Rotation)
  Planner.swift            Tagesplanung, „Noch ein Wort“, verpasste Tage
  Scheduler.swift          FSRS-5
  Session.swift            Ablauf einer Lerneinheit
  Exercises.swift          Übungsauswahl, Antwortoptionen
  AnswerChecker.swift      Türkisch-taugliche Antwortprüfung
  Reminders.swift          Inhalte der Benachrichtigungen
data/                      Häufigkeitsliste + kuratierte Wortlisten (siehe data/README.md)
tools/                     Skripte für Wortdaten und App-Icon
fastlane/                  Signierung und TestFlight-Upload
.github/workflows/         CI und TestFlight
project.yml                Xcode-Projekt (XcodeGen)
```

## Entwicklung

```sh
# Kernlogik testen (macOS mit Xcode oder Linux/Docker)
swift test --package-path Packages/VocaDayCore
docker run --rm -v "$PWD:/repo" -w /repo/Packages/VocaDayCore swift:6.1-noble swift test

# Xcode-Projekt erzeugen und öffnen (macOS)
brew install xcodegen
xcodegen generate
open VocaDay.xcodeproj

# Wortdatenbank neu bauen
python3 tools/data/build_dataset.py
```

## TestFlight

Jeder Push auf `main` wird automatisch gebaut und zu TestFlight hochgeladen, für **iPhone und iPad**. Die einmalige Einrichtung (Apple Developer Account, API-Schlüssel, Secrets) steht Schritt für Schritt in **[docs/TESTFLIGHT.md](docs/TESTFLIGHT.md)**.

## Ideen für später

- Weitere Sprachpaare (Datenformat und Code sind darauf ausgelegt)
- Weitere Modi: nach Themen, streng nach Häufigkeit, eigene Wortlisten
- Widget mit dem Wort des Tages
- iCloud-Sync zwischen iPhone und iPad
- Hörverständnis-Übungen

## Quellen

Worthäufigkeit: [FrequencyWords](https://github.com/hermitdave/FrequencyWords) von Hermit Dave (CC BY-SA 4.0). Lernalgorithmus: [FSRS](https://github.com/open-spaced-repetition) (MIT).
