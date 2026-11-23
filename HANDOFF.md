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
1. Kalender-Export läuft seit 1.0.4/1.0.5 (Prüfberichte aller drei Handys sauber). Letzter Fehler war Lukas' Handy: Google-Synchronisierung hing, Aus-/Einschalten half (Jan, 23.11. 22:10).
2. Offen: Jan sah Michaelas Termine zeitweise doppelt – vermutlich Reste alter Versionen in einem zweiten Kalender; Rückmeldung abwarten.
3. Widgets am Handy prüfen lassen; Idee: Hintergrund-Aktualisierung (WorkManager).

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
- Branch `main`, Release v1.0.5-build-16 (Prüfbericht), lokal 45 Tests grün
- Geteilter Google-Kalender „Familie“ gehört Jan, Familiengruppe hat Bearbeitungsrechte; alle Handys exportieren „nur meine“ dorthin
