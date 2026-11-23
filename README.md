![EchoWP](branding/echowp-banner.png)

# EchoWP Schichtplan

**Aktuelle Version: 0.2.0**

Gemeinsamer Schichtkalender für die Familie (Android). Jede Person trägt ihre Schichten selbst ein, alle Handys sehen sofort denselben Kalender.

## Funktionen

- Anmeldung mit Google-Konto, Familie per Einladungscode beitreten
- Schicht-Datenbank pro Person: Name, Kürzel, Beginn, Ende, Farbe, ganztägig, archivieren
- Nachtschichten über Mitternacht werden erkannt
- Monatskalender der ganzen Familie: pro Tag eine farbige Leiste je Person
- Bis zu zwei Schichten pro Person und Tag
- Offline nutzbar, Änderungen werden nachgereicht
- Startbildschirm-Widgets „Schichten heute“ (heute und morgen) und „Schichten Monatsübersicht“
- Update-Knopf unter *Familie*: prüft die GitHub-Releases und lädt die neue APK im Browser

## Technik

| Baustein | Wahl |
| --- | --- |
| App | Flutter (Android), Paket `de.echowp.schichtplan` |
| Anmeldung | Firebase Authentication (Google) |
| Daten | Cloud Firestore, Regeln in `firestore.rules` |
| Build | GitHub Actions: `flutter create`, Tests, signierte APK, Release |

Duplikate sind ausgeschlossen: Jeder Eintrag hat die feste Kennung `uid_JJJJMMTT_platz`.

Widgets: Die App schreibt die Daten (`lib/home_widgets.dart`, Paket `home_widget`), der Android-Teil liegt in `tool/android/` und wird im Build von `tool/patch_android.py` eingefügt. Die Widgets aktualisieren sich, solange die App läuft oder geöffnet wird; „heute“ springt auch ohne App um Mitternacht weiter (14 Tage Vorrat).

## Einrichtung (einmalig)

1. **Firebase-Zugang:** Secret `GOOGLE_SERVICES_JSON` = Inhalt der `google-services.json`.
2. **Signierschlüssel:** *Actions → Signierschlüssel erzeugen (einmalig) → Run workflow*. Aus dem Artefakt die beiden Textdateien als Secrets `SCHICHTPLAN_KEYSTORE_B64` und `SCHICHTPLAN_KEYSTORE_PASSWORD` anlegen, Artefakt danach löschen. Den SHA-1-Fingerabdruck aus der Zusammenfassung des Laufs in Firebase eintragen (*Projekteinstellungen → Meine Apps → Fingerabdruck hinzufügen*).
3. **Zugriffsregeln:** Inhalt von `firestore.rules` in der Firebase-Konsole unter *Firestore Database → Regeln* einfügen und veröffentlichen.

Ohne Signier-Secrets baut die Pipeline nur `EchoWP-Schichtplan-Test.apk` (Artefakt, kein Release).

## Download

Neueste Version: *Releases → `EchoWP-Schichtplan.apk`*. Play Protect: „Trotzdem installieren“.

## Versionsverlauf

- **0.2.0** – Update-Knopf, Startbildschirm-Widgets „Schichten heute“ und „Monatsübersicht“.
- **0.1.2** – Fehler „permission-denied“ direkt nach dem Anlegen oder Beitreten behoben; Fehlerseite mit „Erneut versuchen“.
- **0.1.1** – App-Symbol nach EchoWP Corporate Design (Elefant mit Kalenderblatt).
- **0.1.0** – Grundgerüst: Anmeldung, Familie, Schicht-Datenbank, Monatskalender.
