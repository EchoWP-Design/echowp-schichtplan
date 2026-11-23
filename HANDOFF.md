# Übergabe

## Ziel der Sitzung
Familien-Schichtkalender von 0 bis Version 0.3.0: Grundgerüst, App-Symbol, Startfehler, Update-Knopf, Widgets, Kalender-Export.

## Erledigt
- 0.1.x: Anmeldung, Familie/Einladungscode, Schicht-Datenbank, Monatskalender, App-Symbol; Fehler „permission-denied“ nach Familienanlage behoben (Jan bestätigt: läuft).
- 0.2.0 (Build 8): Update-Knopf (GitHub-Releases, Repo ist öffentlich), Widgets „Schichten heute“ und „Monatsübersicht“ (`home_widget`, Android-Teil in `tool/android/`).
- 0.3.0: Kalender-Export über `device_calendar_plus`, Kennung im Beschreibungstext, Abgleich in `planSync`.
- Lokal: Flutter 3.50.1 unter `/home/claude/tools/flutter` (pro Sitzung neu laden), `lib/firebase_options.dart` als Platzhalter nur lokal für `flutter analyze`.

## Offen / nächster Schritt
- Rückmeldung von Jan am Handy: Widgets (Aussehen, Größe), Update-Knopf, Kalender-Export.
- Idee: Widgets und Export auch ohne geöffnete App aktualisieren (WorkManager + Firestore im Hintergrund).
- Weitere Wünsche aus dem Plan: Erinnerungen, Notizen pro Schicht.

## Entscheidungen
- Kein fester Schichtrhythmus (Jan).
- Export schreibt in einen vorhandenen Kalender auf dem Handy (z. B. Google-Konto), keine Google-API/OAuth; Duplikatschutz über die Kennung.
- Widgets: „Heute“ nativ aus JSON (14 Tage Vorrat), „Monat“ als Bild aus Flutter.

## Bekannte Probleme
- Maven Central liefert in CI gelegentlich HTTP 429 → Lauf neu starten (`gh workflow run build.yml`).
- Widgets und Export aktualisieren sich nur, wenn die App läuft oder geöffnet wird.

## Zustand
Version 1.0.0 von Jan freigegeben (23.11.2026).
Branch `main`, Build über GitHub Actions, Release-Tag `v<version>-build-<lauf>`.
