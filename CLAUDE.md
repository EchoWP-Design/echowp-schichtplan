# Hinweise für Claude

## Sitzungsübergabe
- Liegt im Repo eine `HANDOFF.md`, lies sie zu Beginn jeder Sitzung zuerst und arbeite beim Abschnitt „Offen / nächster Schritt“ weiter. Prüfe kurz mit `git log -3`, ob der dort genannte Zustand noch stimmt.
- Wird eine Sitzung lang (viele Build-/Testläufe, große Logs, Themenwechsel), schlage Jan `/handoff` vor, statt weiterzuarbeiten.
- `HANDOFF.md` ist ein Arbeitszettel, keine Dokumentation: Dauerhaftes gehört in README.md.

## Projekt
- Flutter, nur Android. `android/` entsteht in CI per `flutter create`, `tool/patch_android.py` passt es an.
- `lib/firebase_options.dart` wird in CI aus dem Secret `GOOGLE_SERVICES_JSON` erzeugt und nie eingecheckt.
- Reine Logik (`lib/logic.dart`, `lib/models.dart`) und Widgets ohne Firebase (`MonthGrid`, `ShiftEditorScreen`) sind getestet; Firestore-Zugriff steckt ausschließlich in `lib/repo.dart`.
- Änderungen am Datenmodell immer auch in `firestore.rules` nachziehen und Jan auf das erneute Einspielen hinweisen.

## Version
- Neue Version: `pubspec.yaml` und die Zeile `**Aktuelle Version: X.Y.Z**` in README.md plus Eintrag im Versionsverlauf. versionCode = Lauf-Nummer (steigt automatisch).
