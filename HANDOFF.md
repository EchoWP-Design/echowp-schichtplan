# Übergabe – 2026-11-23, 22:16

## Ziel der Sitzung
Familien-Schichtkalender von null bis Version 1.0.5 gebaut; zuletzt den Google-Kalender-Export mit drei Handys (Jan, Lukas, Michaela) zum Laufen gebracht. Jan hat bestätigt: alles übertragen, keine Doppelungen mehr.

## Erledigt
- 0.1.x Grundgerüst, App-Symbol, Startfehler „permission-denied“
- 0.2.0 Update-Knopf, Widgets „Schichten heute“/„Monatsübersicht“ – `lib/updater.dart`, `lib/home_widgets.dart`, `tool/android/` – 982c75f
- 0.3.x Kalender-Export, Kürzel als Termin-Titel – `lib/calendar_export.dart`, `lib/screens/export_card.dart` – 36c6852
- 1.0.0 freigegeben (c1fdc20); 1.0.1 MIT-Lizenz + „Lizenzen und Hinweise“ (f6c32a7)
- 1.0.2 Abgleich robust: erst anlegen, dann löschen, Fehler pro Termin (73bf003)
- 1.0.3 Export nur mit Serverdaten (`Repo.entriesConfirmed`); vorher löschte ein unvollständiger Firestore-Zwischenspeicher Termine (354b227)
- 1.0.4 Gerätekennung im Termin: jedes Handy verwaltet nur eigene Termine, im geteilten Kalender legt nur das Handy mit kleinster Kennung an (a55b184)
- 1.0.5 Prüfbericht (*Familie → Google Kalender → Prüfbericht*) (85a8ef7)

## Offen / nächster Schritt
1. Nichts Dringendes. Auf Jans nächste Rückmeldung warten (Widgets am Handy noch nicht bewertet).
2. Idee: Widgets und Export ohne geöffnete App aktualisieren (WorkManager + Firestore im Hintergrund).
3. Weitere Plan-Wünsche: Erinnerungen, Notizen pro Schicht.

## Entscheidungen
- Export in vorhandenen Kalender auf dem Handy (`device_calendar_plus`), keine Google-API/OAuth.
- Familien-Einrichtung: Google-Kalender „Familie“ gehört Jan, Google-Familiengruppe hat Bearbeitungsrechte; alle Handys exportieren „nur meine“ dorthin. Android zeigt ihn je Handy unter dem eigenen Konto.
- Termin-Titel = Kürzel, bei „ganze Familie“ `Name: Kürzel`.
- Repo öffentlich (für den Update-Knopf), Code unter MIT.

## Bekannte Probleme
- Fehlende Termine trotz sauberem Prüfbericht = Google-Synchronisierung des Handys hängt → im Google Kalender Synchronisierung aus-/einschalten (half bei Lukas).
- Jan nutzt HyperOS (Xiaomi): Menüpfade weichen ab („Konten und Synchronisierung“).
- Export-Zeitraum: 2 Wochen zurück bis 120 Tage voraus; Schichten außerhalb fehlen absichtlich.
- Deinstalliertes Handy ohne *Ausschalten* hinterlässt seine Termine.
- CI: Maven Central gelegentlich HTTP 429 → Lauf neu starten.
- Lokal: Flutter 3.50.1 nach `/home/claude/tools/flutter` laden; für `flutter analyze` Platzhalter `lib/firebase_options.dart` anlegen (gitignored).

## Zustand
- Branch `main`, letzter Code-Commit 85a8ef7, Arbeitsverzeichnis sauber
- Build 45264483995 grün, Release v1.0.5-build-16; lokal 45 Tests grün
