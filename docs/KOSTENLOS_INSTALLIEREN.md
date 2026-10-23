# VocaDay kostenlos auf iPhone und iPad

Es gibt drei kostenlose Wege, keiner braucht das Apple Developer Program:

| Weg | Computer nötig? | Mitteilungen | Einschränkung |
| --- | --- | --- | --- |
| **A. Web-App** | nein | über Kalender-Erinnerungen | keine echten App-Mitteilungen |
| **B. Windows-PC** (Sideloadly/AltStore) | einmal pro Woche | ja, echte Mitteilungen | App alle 7 Tage neu signieren |
| **C. Mac** (Sideloadly oder Xcode) | einmal pro Woche | ja, echte Mitteilungen | App alle 7 Tage neu signieren |

Mit dem bezahlten Apple Developer Program (99 €/Jahr) entfällt die 7-Tage-Grenze, dann geht es über TestFlight, siehe [TESTFLIGHT.md](TESTFLIGHT.md).

---

## A. Web-App: sofort, ohne Computer

1. Öffne auf dem iPhone in **Safari**: **https://thedarkmeyerhans.github.io/VocaDay/**
2. Tippe auf **Teilen** (Quadrat mit Pfeil) → **„Zum Home-Bildschirm“** → **Hinzufügen**.
3. Starte VocaDay ab jetzt über das neue Symbol auf dem Home-Bildschirm. Die App läuft im Vollbild und offline.
4. Auf dem iPad genauso. Achtung: iPhone und iPad haben jeweils einen **eigenen** Lernstand. Unter *Einstellungen › Daten* kannst du ihn sichern und auf dem anderen Gerät wiederherstellen.

**Erinnerungen:** *Einstellungen › Erinnerungen › „Wörter der nächsten 30 Tage in den Kalender“*, dann „Alle hinzufügen“. Dein Kalender meldet sich jeden Morgen zur eingestellten Uhrzeit mit dem Wort des Tages. Nach „Noch ein Wort“ oder einer geänderten Wortanzahl exportierst du einfach neu; alte Termine kannst du im Kalender löschen.

> **Wichtig:** Nutze die Web-App immer über das Symbol auf dem Home-Bildschirm. In einem normalen Safari-Tab kann iOS gespeicherte Daten nach einigen Wochen ohne Nutzung löschen.

> Die Seite ist nur erreichbar, wenn GitHub Pages aktiv ist. Falls sie nicht lädt: Repo → **Settings → Pages** → *Build and deployment* → Source **„Deploy from a branch“**, Branch **`gh-pages`** / **`/ (root)`** → **Save**. Nach 1–2 Minuten ist sie online.

---

## B. Windows-PC

Die App-Datei wird bei jedem Push automatisch gebaut:
**https://github.com/thedarkmeyerhans/VocaDay/releases/download/app-latest/VocaDay.ipa**

### Mit Sideloadly (am einfachsten)

1. **iTunes** und **iCloud** von apple.com installieren, die Versionen von der Apple-Website, nicht aus dem Microsoft Store.
2. **Sideloadly** von https://sideloadly.io installieren und starten.
3. iPhone per Kabel verbinden und am iPhone „Diesem Computer vertrauen“ bestätigen.
4. `VocaDay.ipa` in Sideloadly ziehen, deine **Apple-ID** eintragen und auf **Start** klicken.
5. Am iPhone: *Einstellungen › Allgemein › VPN & Geräteverwaltung* → deine Apple-ID → **Vertrauen**.
6. Ab iOS 16: *Einstellungen › Datenschutz & Sicherheit › Entwicklermodus* einschalten und neu starten. Der Schalter erscheint erst nach dem ersten Installationsversuch.
7. **Nach 7 Tagen** wiederholen. Der Lernstand bleibt erhalten. Sideloadly kann das auch automatisch per WLAN erledigen, solange der PC läuft.

### Alternativ AltStore

AltStore (https://altstore.io, „AltStore Classic“) installiert die App ähnlich. Es frischt sie automatisch alle 7 Tage auf, wenn AltServer auf dem PC läuft und iPhone und PC im selben WLAN sind.

> Sideloadly und AltStore sind Programme von Drittanbietern und brauchen deine Apple-ID. Wer vorsichtig sein will, legt dafür eine eigene kostenlose Apple-ID an.

Mit einer kostenlosen Apple-ID kannst du höchstens 3 selbst installierte Apps pro Gerät gleichzeitig haben.

---

## C. Mac

**Einfach:** Sideloadly gibt es auch für macOS. Die Schritte sind wie unter B, iTunes und iCloud brauchst du dort nicht.

**Mit Xcode (kostenlos im Mac App Store):**

```sh
git clone https://github.com/thedarkmeyerhans/VocaDay.git
cd VocaDay
brew install xcodegen
xcodegen generate
open VocaDay.xcodeproj
```

1. In Xcode: *Settings › Accounts* → deine Apple-ID hinzufügen.
2. Projekt *VocaDay* → Target *VocaDay* → **Signing & Capabilities** → *Team*: „(Dein Name) (Personal Team)“. Falls die Bundle-ID vergeben ist, hänge etwas an, z. B. `.deniz`.
3. iPhone per Kabel verbinden, oben als Ziel auswählen und **▶ Run** klicken.
4. Am iPhone wie unter B Schritt 5 und 6 bestätigen.
5. Nach 7 Tagen einfach erneut auf **Run** klicken.
