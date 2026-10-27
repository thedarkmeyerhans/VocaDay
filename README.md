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
- **Wortschatz-Test:** fragt alle gelernten Wörter ab (oder die schwächsten 20, 20 zufällige, die der Woche). Richtung und Antwortart (Auswählen/Eintippen) sind wählbar.
- **Wortschatz:** keine lange Liste, sondern eine Übersicht mit Fortschritt und Status-Kacheln. Darunter drei Ansichten: **A–Z** (Buchstaben-Raster → Wörter des Buchstabens), **Status** (wischbare Reihen: Lernend, Wiederholen, Gefestigt, Geplant) und **Verlauf** (nach Lerntagen). Die Suche durchsucht das ganze Wörterbuch. Jedes noch nicht geplante Wort lässt sich mit **„Heute lernen“** vorziehen, ohne die A–Z-Reihenfolge zu stören.
- **Karteikarten:** Jede Gruppe (alle gelernten, ein Buchstabe, ein Status) lässt sich als Kartenstapel durchwischen: antippen zum Umdrehen, mit Aussprache und Mischen.
- **Grundform zuerst, Endungen später:** Neue Wörter lernt man immer in der Grundform (gitmek, ev). Unregelmäßige Verben sind schon beim Lernen markiert (⚠︎ unregelmäßig) – mit Erklärung, z. B. „t wird zu d: gidiyorum“ oder „Breite Zeit mit -ir: gelir“. Satzübungen mit gebeugten Formen kommen erst, wenn das Präsens sitzt.
- **Grammatik-Lernpfad:** 7 Stufen – Personalpronomen (ich → ben …), Verbendungen -mak/-mek (Stamm und Vokalharmonie), Präsens-Endungen an Musterverben, dann Präsens, Vergangenheit, Zukunft und Breite Zeit mit den eigenen gelernten Verben. Jede Stufe hat eine kurze Lektion mit Tabellen und wird geübt, bis jede Aufgabe 2× hintereinander sitzt (erst Auswahl, dann Eintippen). Jedes Verb zeigt eine Konjugationstabelle mit hervorgehobenen Endungen.
- **Festigen:** die schwächsten gelernten Wörter so lange, bis jedes sitzt.
- **Widget (nur native App):** Homescreen- und Sperrbildschirm-Widget mit einem neuen Wort zu einstellbaren Uhrzeiten oder sobald man an einem gespeicherten Ort ankommt (Zuhause, Bahnhof …). Antippen → Wort wird vorgestellt und abgefragt, bis es X-mal (einstellbar) richtig war; danach kommt wahlweise sofort das nächste Wort oder es gilt bis zur nächsten Uhrzeit als erledigt.
- **Zwangsmodus (nur native App):** Vor Instagram, TikTok & Co. kommt erst eine Vokabel. Richtig → die App ist X Minuten frei, falsch → nächstes Wort. Die Quiz-Wörter rotieren über den Tag, bis sie sitzen, dann kommen neue. Umsetzung über App Intents + Kurzbefehle-Automation (Anleitung in der App unter *Einstellungen › Zwangsmodus*).
- **Statistik:** Textabdeckung, Aktivität, Lernkalender, Prognose der Wiederholungen, Wortstatus, gemessene Behaltensquote, Fortschritt A–Z, Test-Verlauf, Lernzeit und Serien.

## Lernsystem

| Prinzip | Umsetzung |
| --- | --- |
| Verteilte Wiederholung | **FSRS-5**, der Algorithmus, den auch Anki nutzt. Jedes Wort hat Stabilität und Schwierigkeit. Es wird abgefragt, kurz bevor die Erinnerungswahrscheinlichkeit unter das Behaltensziel fällt (Standard 90 %, einstellbar). |
| Abrufen statt Lesen (Testing-Effekt) | Jede Wiederholung ist eine Abfrage. Die Antwort bestimmt den nächsten Abstand. |
| Wachsende Schwierigkeit | Neue Wörter: erst Erkennen (Auswahl). Je stabiler ein Wort, desto mehr muss man selbst produzieren: tippen, Lücke füllen, Satz bauen. |
| Lernen im Kontext | Jedes Wort hat einen Beispielsatz. Der **Satztrainer** übt Lückentexte (Auswahl/Tippen) und das Zusammensetzen ganzer Sätze. |
| Interleaving | Neue Wörter werden zwischen Wiederholungen gestreut. Falsche Antworten kommen in derselben Einheit etwas später noch einmal. |
| Aussprechen | Vorlesefunktion und Hinweis zum lauten Nachsprechen (Produktionseffekt). |
| Wortschatz-Test (Mastery Learning) | Jedes Wort einmal, gemischt. Nur der erste Versuch zählt für das Ergebnis und fließt in FSRS ein, so ist der Test eine ehrliche Messung. Falsche Wörter kommen in einer Fehlerrunde mit leichterer Übung zurück, bis sie sitzen. |
| Meisterschaftslernen (Grammatik, Festigen) | Eine Aufgabe ist erst gemeistert, wenn sie mehrmals hintereinander richtig war. Falsche kommen nach zwei, richtige nach vier anderen Aufgaben wieder. Erste Runde Auswahl, danach Eintippen (Abruf statt Wiedererkennen). |
| Messen statt schätzen | Die Statistik vergleicht die tatsächliche Behaltensquote fälliger Wörter mit dem eingestellten Ziel. Die Textabdeckung zeigt, welchen Anteil eines Alltagstexts die gelernten Wörter ausmachen. |

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
  VocabularyTest.swift     Wortschatz-Test (Mastery-Schleife)
  Statistics.swift         Kennzahlen für die Statistik
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

## Installieren

**Kostenlos:** [docs/KOSTENLOS_INSTALLIEREN.md](docs/KOSTENLOS_INSTALLIEREN.md)
- **Web-App ohne Computer:** https://thedarkmeyerhans.github.io/VocaDay/ → in Safari „Zum Home-Bildschirm“
- **Windows/Mac:** fertige App-Datei unter [Releases › app-latest](https://github.com/thedarkmeyerhans/VocaDay/releases/tag/app-latest), Installation mit Sideloadly/AltStore oder Xcode und kostenloser Apple-ID

### Web-App

`web/` enthält eine Web-Version mit demselben Lernsystem (`web/js/core.js` entspricht dem Swift-Kern), ohne Build-Schritt und ohne Abhängigkeiten. Sie ist offline-fähig, speichert den Lernstand lokal und bietet Kalender-Export für Erinnerungen. Sie wird bei jedem Push auf `main` nach GitHub Pages veröffentlicht. Tests: `node --test web/tests/core.test.mjs`.

## TestFlight

Jeder Push auf `main` wird automatisch gebaut und zu TestFlight hochgeladen, für **iPhone und iPad**. Die einmalige Einrichtung (Apple Developer Account, API-Schlüssel, Secrets) steht Schritt für Schritt in **[docs/TESTFLIGHT.md](docs/TESTFLIGHT.md)**.

## Ideen für später

- Weitere Sprachpaare (Datenformat und Code sind darauf ausgelegt)
- Weitere Modi: nach Themen, streng nach Häufigkeit, eigene Wortlisten
- iCloud-Sync zwischen iPhone und iPad
- Hörverständnis-Übungen

## Quellen

Worthäufigkeit: [FrequencyWords](https://github.com/hermitdave/FrequencyWords) von Hermit Dave (CC BY-SA 4.0). Lernalgorithmus: [FSRS](https://github.com/open-spaced-repetition) (MIT).
