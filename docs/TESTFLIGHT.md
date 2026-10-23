# VocaDay auf TestFlight (iPhone & iPad)

Jeder Push auf `main` baut die App automatisch in GitHub Actions (macOS-Runner) und lädt sie zu TestFlight hoch. Du brauchst **keinen Mac**. Die Einrichtung musst du einmal machen und brauchst dafür etwa 30 Minuten, zuzüglich der Wartezeit auf die Freischaltung durch Apple.

VocaDay ist eine Universal-App: **derselbe Build läuft auf iPhone und iPad.** Du installierst ihn auf beiden Geräten über die TestFlight-App.

---

## 1. Apple Developer Program beitreten

1. Unter <https://developer.apple.com/programs/enroll/> mit deiner Apple-ID anmelden und als **Einzelperson** beitreten (99 €/Jahr).
2. Die Freischaltung dauert meist ein paar Stunden, manchmal bis zu 48 Stunden.
3. Danach findest du unter <https://developer.apple.com/account> → **Mitgliedschaftsdetails** deine **Team-ID** (10 Zeichen, z. B. `AB12CD34EF`). Notiere sie.

## 2. Bundle-ID registrieren

1. <https://developer.apple.com/account/resources/identifiers/list> → **+** → **App IDs** → **App**.
2. Beschreibung: `VocaDay`, Bundle ID **Explicit**: `com.thedarkmeyerhans.vocaday`.
3. Keine zusätzlichen Capabilities nötig, denn die Benachrichtigungen sind lokal und brauchen kein Push. Speichern.

> Falls die ID schon vergeben ist, nimm eine andere (z. B. `de.deinname.vocaday`) und trage sie in `Config/Shared.xcconfig` ein.

## 3. App in App Store Connect anlegen

1. <https://appstoreconnect.apple.com> → **Apps** → **+** → **Neue App**.
2. Plattform **iOS**, Name `VocaDay`. Der Name muss im Store eindeutig sein; ist er vergeben, z. B. `VocaDay Türkisch`. Primäre Sprache **Deutsch**, Bundle-ID aus Schritt 2, SKU `vocaday`, Vollzugriff.

## 4. App Store Connect API-Schlüssel erstellen

1. App Store Connect → **Benutzer und Zugriff** → **Integrationen** → **App Store Connect API** → **Team-Schlüssel** → **+**.
2. Name `GitHub CI`, Zugriff **Admin**. Admin ist nötig, damit Zertifikate und Profile automatisch erstellt werden können.
3. Notiere die **Schlüssel-ID** und die **Issuer-ID** (steht über der Tabelle).
4. Lade die `.p8`-Datei herunter. **Das geht nur einmal!**
5. Wandle die Datei in Base64 um:
   - macOS / Linux: `base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'`
   - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8"))`

## 5. Privates Repo für die Zertifikate

fastlane *match* erstellt das Signierzertifikat und das Provisioning-Profil beim ersten Lauf selbst. Es speichert beides verschlüsselt in einem eigenen Repo, damit jeder Build dieselben verwendet.

1. Neues **privates**, leeres GitHub-Repo anlegen, z. B. `thedarkmeyerhans/vocaday-certificates`.
2. Einen Token erstellen: GitHub → Settings → Developer settings → **Fine-grained tokens** → Generate. Gib ihm nur Zugriff auf dieses Repo, mit der Berechtigung **Contents: Read and write**.
3. Den Wert für `MATCH_GIT_BASIC_AUTHORIZATION` bilden (Benutzername:Token als Base64):
   - macOS / Linux: `printf 'thedarkmeyerhans:DEIN_TOKEN' | base64`
   - Windows: `[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("thedarkmeyerhans:DEIN_TOKEN"))`
4. Ein eigenes, langes Passwort ausdenken. Es verschlüsselt die Zertifikate (`MATCH_PASSWORD`).

## 6. Secrets in GitHub eintragen

Repo **VocaDay** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Inhalt |
| --- | --- |
| `APPLE_TEAM_ID` | Team-ID aus Schritt 1 |
| `ASC_KEY_ID` | Schlüssel-ID aus Schritt 4 |
| `ASC_ISSUER_ID` | Issuer-ID aus Schritt 4 |
| `ASC_KEY_P8_BASE64` | Base64 der `.p8`-Datei |
| `MATCH_GIT_URL` | `https://github.com/thedarkmeyerhans/vocaday-certificates.git` |
| `MATCH_PASSWORD` | dein Passwort aus Schritt 5 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64 aus Schritt 5 |

## 7. Ersten Build starten

1. Repo → **Actions** → **TestFlight** → **Run workflow** (oder einfach etwas auf `main` pushen).
2. Der Build dauert etwa 10–20 Minuten. Danach verarbeitet Apple ihn noch 5–30 Minuten.
3. Nach dem ersten erfolgreichen Lauf liegen die Zertifikate im Repo. Lege dann unter **Settings → Secrets and variables → Actions → Variables** die Variable `MATCH_READONLY` = `true` an, damit spätere Läufe nichts Neues erzeugen.

## 8. Auf iPhone und iPad installieren

1. App Store Connect → deine App → **TestFlight** → **Interne Tests** → **+**. Gruppe `Ich` anlegen, dich selbst als Tester hinzufügen und **Automatische Verteilung** aktivieren.
2. Die App **TestFlight** aus dem App Store auf **iPhone und iPad** installieren und mit derselben Apple-ID anmelden.
3. VocaDay erscheint auf beiden Geräten. Jeder neue Build wird dort automatisch angeboten.

---

## Häufige Fehler

| Meldung | Lösung |
| --- | --- |
| `TestFlight upload skipped, missing secrets` | Secrets aus Schritt 6 fehlen oder sind falsch geschrieben. |
| `Could not find App with bundle identifier` | Die App aus Schritt 3 fehlt oder hat eine andere Bundle-ID. |
| `Maximum number of certificates generated` | Unter developer.apple.com → Certificates ein altes „Apple Distribution“-Zertifikat widerrufen, dann neu starten. |
| `Authentication credentials are missing or invalid` | API-Schlüssel prüfen: Base64 ohne Zeilenumbrüche, Rolle **Admin**. |
| Build erscheint nicht in TestFlight | Apple verarbeitet noch. Bei Problemen kommt eine E-Mail von App Store Connect. |
