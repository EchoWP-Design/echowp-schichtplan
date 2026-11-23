![EchoWP](branding/echowp-banner.png)

# EchoWP Schichtplan

**Aktuelle Version: 1.0.5**

Gemeinsamer Schichtkalender für die Familie (Android). Jede Person trägt ihre Schichten selbst ein, alle Handys sehen sofort denselben Kalender.

## Funktionen

- Anmeldung mit Google-Konto, Familie per Einladungscode beitreten
- Schicht-Datenbank pro Person: Name, Kürzel, Beginn, Ende, Farbe, ganztägig, archivieren
- Nachtschichten über Mitternacht werden erkannt
- Monatskalender der ganzen Familie: pro Tag eine farbige Leiste je Person
- Bis zu zwei Schichten pro Person und Tag
- Offline nutzbar, Änderungen werden nachgereicht
- Startbildschirm-Widgets „Schichten heute“ (heute und morgen) und „Schichten Monatsübersicht“
- Export in einen Kalender auf dem Handy (z. B. Google Kalender) unter *Familie → Google Kalender*: nur eigene Schichten oder die ganze Familie, automatischer Abgleich ohne Doppelungen
- Update-Knopf unter *Familie*: prüft die GitHub-Releases und lädt die neue APK im Browser

## Technik

| Baustein | Wahl |
| --- | --- |
| App | Flutter (Android), Paket `de.echowp.schichtplan` |
| Anmeldung | Firebase Authentication (Google) |
| Daten | Cloud Firestore, Regeln in `firestore.rules` |
| Build | GitHub Actions: `flutter create`, Tests, signierte APK, Release |

Duplikate sind ausgeschlossen: Jeder Eintrag hat die feste Kennung `uid_JJJJMMTT_platz`.

Kalender-Export (`lib/calendar_export.dart`, Paket `device_calendar_plus`): Jeder Termin trägt in der Beschreibung `EchoWP-Schichtplan-ID: <Eintrag> Gerät <Kennung>`. Jedes Handy ändert nur seine eigenen Termine; bei geteilten Kalendern legt nur das Handy mit der kleinsten Kennung eine Schicht an. Der Abgleich (zwei Wochen zurück, vier Monate voraus) legt fehlende Termine an, schreibt geänderte neu und löscht überzählige; Termine ohne Kennung bleiben unberührt. Die Einstellung liegt nur auf dem Handy.

Widgets: Die App schreibt die Daten (`lib/home_widgets.dart`, Paket `home_widget`), der Android-Teil liegt in `tool/android/` und wird im Build von `tool/patch_android.py` eingefügt. Die Widgets aktualisieren sich, solange die App läuft oder geöffnet wird; „heute“ springt auch ohne App um Mitternacht weiter (14 Tage Vorrat).

## Einrichtung (einmalig)

1. **Firebase-Zugang:** Secret `GOOGLE_SERVICES_JSON` = Inhalt der `google-services.json`.
2. **Signierschlüssel:** *Actions → Signierschlüssel erzeugen (einmalig) → Run workflow*. Aus dem Artefakt die beiden Textdateien als Secrets `SCHICHTPLAN_KEYSTORE_B64` und `SCHICHTPLAN_KEYSTORE_PASSWORD` anlegen, Artefakt danach löschen. Den SHA-1-Fingerabdruck aus der Zusammenfassung des Laufs in Firebase eintragen (*Projekteinstellungen → Meine Apps → Fingerabdruck hinzufügen*).
3. **Zugriffsregeln:** Inhalt von `firestore.rules` in der Firebase-Konsole unter *Firestore Database → Regeln* einfügen und veröffentlichen.

Ohne Signier-Secrets baut die Pipeline nur `EchoWP-Schichtplan-Test.apk` (Artefakt, kein Release).

## Download

Neueste Version: *Releases → `EchoWP-Schichtplan.apk`*. Play Protect: „Trotzdem installieren“.

## Versionsverlauf

- **1.0.5** – Prüfbericht für den Kalender-Export (*Familie → Google Kalender → Prüfbericht*), zum Kopieren.
- **1.0.4** – Kalender-Export mit mehreren Handys: Jedes Handy ändert nur seine eigenen Termine (Gerätekennung); schreiben mehrere in denselben Kalender, legt nur eines je Schicht an.
- **1.0.3** – Kalender-Export: Abgleich nur noch mit vollständigen Daten vom Server (vorher konnte ein unvollständiger Zwischenspeicher Termine löschen); Kontrolle nach jedem Abgleich mit Anzahl je Person.
- **1.0.2** – Kalender-Abgleich: erst anlegen, dann löschen; ein gescheiterter Termin hält den Rest nicht mehr auf; genaue Fehlermeldung auf der Karte.
- **1.0.1** – „Lizenzen und Hinweise“ unter *Familie* (Datenschutz in Kurzform, Open-Source-Lizenzen); Code unter MIT-Lizenz.
- **1.0.0** – Erste freigegebene Version: gemeinsamer Kalender, Schicht-Datenbank, Widgets, Google-Kalender-Export, Update-Knopf.
- **0.3.1** – Kalender-Export: Termin-Titel ist das Kürzel der Schicht, der Langname steht in der Beschreibung.
- **0.3.0** – Export in den Google Kalender (bzw. jeden Kalender auf dem Handy) ohne Doppelungen.
- **0.2.0** – Update-Knopf, Startbildschirm-Widgets „Schichten heute“ und „Monatsübersicht“.
- **0.1.2** – Fehler „permission-denied“ direkt nach dem Anlegen oder Beitreten behoben; Fehlerseite mit „Erneut versuchen“.
- **0.1.1** – App-Symbol nach EchoWP Corporate Design (Elefant mit Kalenderblatt).
- **0.1.0** – Grundgerüst: Anmeldung, Familie, Schicht-Datenbank, Monatskalender.

## Lizenz

Quellcode: [MIT-Lizenz](LICENSE). Die Lizenzen der verwendeten Pakete zeigt die App unter *Familie → Lizenzen und Hinweise*.
