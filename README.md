![EchoWP](branding/echowp-banner.png)

# EchoWP Schichtplan

**Aktuelle Version: 0.1.0**

Gemeinsamer Schichtkalender für die Familie (Android). Jede Person trägt ihre Schichten selbst ein, alle Handys sehen sofort denselben Kalender.

## Funktionen (Version 1)

- Anmeldung mit Google-Konto, Familie per Einladungscode beitreten
- Schicht-Datenbank pro Person: Name, Kürzel, Beginn, Ende, Farbe, ganztägig, archivieren
- Nachtschichten über Mitternacht werden erkannt
- Monatskalender der ganzen Familie: pro Tag eine farbige Leiste je Person
- Bis zu zwei Schichten pro Person und Tag
- Offline nutzbar, Änderungen werden nachgereicht

## Technik

| Baustein | Wahl |
| --- | --- |
| App | Flutter (Android), Paket `de.echowp.schichtplan` |
| Anmeldung | Firebase Authentication (Google) |
| Daten | Cloud Firestore, Regeln in `firestore.rules` |
| Build | GitHub Actions: `flutter create`, Tests, signierte APK, Release |

Duplikate sind ausgeschlossen: Jeder Eintrag hat die feste Kennung `uid_JJJJMMTT_platz`.

## Einrichtung (einmalig)

1. **Firebase-Zugang:** Secret `GOOGLE_SERVICES_JSON` = Inhalt der `google-services.json`.
2. **Signierschlüssel:** *Actions → Signierschlüssel erzeugen (einmalig) → Run workflow*. Aus dem Artefakt die beiden Textdateien als Secrets `SCHICHTPLAN_KEYSTORE_B64` und `SCHICHTPLAN_KEYSTORE_PASSWORD` anlegen, Artefakt danach löschen. Den SHA-1-Fingerabdruck aus der Zusammenfassung des Laufs in Firebase eintragen (*Projekteinstellungen → Meine Apps → Fingerabdruck hinzufügen*).
3. **Zugriffsregeln:** Inhalt von `firestore.rules` in der Firebase-Konsole unter *Firestore Database → Regeln* einfügen und veröffentlichen.

Ohne Signier-Secrets baut die Pipeline nur `EchoWP-Schichtplan-Test.apk` (Artefakt, kein Release).

## Download

Neueste Version: *Releases → `EchoWP-Schichtplan.apk`*. Play Protect: „Trotzdem installieren“.

## Versionsverlauf

- **0.1.0** – Grundgerüst: Anmeldung, Familie, Schicht-Datenbank, Monatskalender.
