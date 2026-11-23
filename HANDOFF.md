# Übergabe – 2026-11-23, 21:25

## Ziel der Sitzung
Familien-Schichtkalender von null bis Version 1.0.3 gebaut, zuletzt den Google-Kalender-Export repariert (Termine fehlten bzw. wurden gelöscht).

## Erledigt
- 0.1.x Grundgerüst, App-Symbol, Startfehler „permission-denied“ (Jan bestätigt: läuft)
- 0.2.0 Update-Knopf + Widgets „Schichten heute“/„Monatsübersicht“ – `lib/updater.dart`, `lib/home_widgets.dart`, `tool/android/` – 982c75f
- 0.3.x Kalender-Export, Kürzel als Titel – `lib/calendar_export.dart`, `lib/screens/export_card.dart` – 36c6852
- 1.0.0 freigegeben (c1fdc20), 1.0.1 MIT-Lizenz + „Lizenzen und Hinweise“ (f6c32a7)
- 1.0.2 Abgleich robust: erst anlegen, dann löschen, Fehler pro Termin (73bf003)
- 1.0.3 Hauptfehler behoben: Export lief mit Firestore-Zwischenspeicher (nur angesehener Monat) und löschte alle anderen Termine. Jetzt `Repo.entriesConfirmed` (nur Serverstände), Kontrolle nach dem Abgleich, Anzahl je Person – 354b227

## Offen / nächster Schritt
1. Jans Rückmeldung zu 1.0.3 abwarten: Sind nach „Jetzt abgleichen“ alle Schichten aller Personen im Google Kalender? Er schickt ggf. Screenshot der Karte *Familie → Google Kalender* (Zeile mit Anzahl je Person oder roter Fehler).
2. Falls weiter Termine fehlen: Fehlermeldung der Karte auswerten (Löschen scheiterte unter 1.0.1 aus ungeklärtem Grund, siehe unten).
3. Widgets am Handy prüfen lassen (Aussehen, Größe) – bisher keine Rückmeldung.
4. Idee: Widgets und Export ohne geöffnete App aktualisieren (WorkManager + Firestore im Hintergrund).

## Entscheidungen
- Export in einen vorhandenen Kalender auf dem Handy (`device_calendar_plus`), keine Google-API/OAuth. Duplikatschutz über `EchoWP-Schichtplan-ID: <entryId>` in der Beschreibung; Kennung wird per Regex gelesen (Google kann HTML einpacken).
- Termin-Titel = Schicht-Kürzel (Jans Wunsch), bei „ganze Familie“ `Name: Kürzel`.
- Repo öffentlich (Jan), damit der Update-Knopf ohne Anmeldung lädt.
- Kein Impressum nötig, solange privat in der Familie (Einschätzung, keine Rechtsberatung).

## Bekannte Probleme
- Unter 1.0.1 scheiterte das Löschen alter Termine ohne sichtbare Meldung; Ursache unklar (vermutlich Folge des Zwischenspeicher-Fehlers). Ab 1.0.2 steht jede Fehlermeldung rot auf der Karte.
- Jan hat HyperOS (Xiaomi): Menüpfade weichen von Standard-Android ab.
- Widgets/Export aktualisieren sich nur bei laufender oder geöffneter App.
- CI: Maven Central gelegentlich HTTP 429 → Lauf neu starten.
- Lokal: Flutter 3.50.1 nach `/home/claude/tools/flutter` laden; für `flutter analyze` einen Platzhalter `lib/firebase_options.dart` anlegen (gitignored).

## Zustand
- Branch `main`, letzter Commit 354b227, Arbeitsverzeichnis sauber
- Build 45257634496 grün, Release v1.0.3-build-14; lokal 42 Tests grün
