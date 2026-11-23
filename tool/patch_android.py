"""Passt die von `flutter create` erzeugten Android-Dateien an (läuft nur im GitHub-Build)."""
import os
import pathlib
import re
import shutil
import sys

root = pathlib.Path(__file__).resolve().parent.parent
LABEL = "Schichtplan"
STORE = "../../keystore/schichtplan.jks"
PW = os.environ.get("SCHICHTPLAN_KEYSTORE_PASSWORD", "")
SIGNED = (root / "keystore" / "schichtplan.jks").exists() and bool(PW)


def patch(path: pathlib.Path, fn):
    if not path.exists():
        print(f"::error::Datei fehlt: {path.relative_to(root)}")
        sys.exit(1)
    old = path.read_text(encoding="utf-8")
    new = fn(old)
    if new != old:
        path.write_text(new, encoding="utf-8")
        print(f"angepasst: {path.relative_to(root)}")


def manifest(t: str) -> str:
    t = re.sub(r'android:label="[^"]*"', f'android:label="{LABEL}"', t, count=1)
    # Keine Android-Sicherung der App-Daten (Anmeldung liegt bei Firebase)
    if "android:allowBackup" not in t:
        t = t.replace("<application", '<application\n        android:allowBackup="false"', 1)
    if "android.permission.INTERNET" not in t:
        t = t.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    # Kalender-Export in einen Kalender auf dem Handy
    for perm in ("READ_CALENDAR", "WRITE_CALENDAR"):
        if f"android.permission.{perm}" not in t:
            t = t.replace("<application", f'<uses-permission android:name="android.permission.{perm}"/>\n    <application', 1)
    # Update-Knopf öffnet den Download im Browser (Android 11+ braucht dafür eine Abfrage-Freigabe)
    if 'android:scheme="https"' not in t:
        queries = (
            "    <queries>\n"
            "        <intent>\n"
            '            <action android:name="android.intent.action.VIEW"/>\n'
            '            <data android:scheme="https"/>\n'
            "        </intent>\n"
            "    </queries>\n"
        )
        if "</queries>" in t:
            intent = "".join(queries.splitlines(keepends=True)[1:-1])
            t = t.replace("    </queries>", intent + "    </queries>", 1)
        else:
            t = t.replace("</manifest>", queries + "</manifest>", 1)
    # Startbildschirm-Widgets (Kotlin und Layouts aus tool/android/)
    if ".HeuteWidget" not in t:
        receivers = "".join(
            f'''        <receiver android:name=".{cls}" android:label="{label}" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/{info}"/>
        </receiver>
'''
            for cls, label, info in WIDGETS
        )
        t = t.replace("    </application>", receivers + "    </application>", 1)
    return t


WIDGETS = [
    ("HeuteWidget", "Schichten heute", "widget_heute_info"),
    ("MonatWidget", "Schichten Monatsübersicht", "widget_monat_info"),
]


def copy_widget_files():
    src = root / "tool" / "android"
    main = root / "android" / "app" / "src" / "main"
    kotlin_dir = main / "kotlin" / "de" / "echowp" / "schichtplan"
    if not (kotlin_dir / "MainActivity.kt").exists():
        print(f"::error::MainActivity.kt nicht gefunden in {kotlin_dir.relative_to(root)}")
        sys.exit(1)
    for f in sorted((src / "kotlin").glob("*.kt")):
        shutil.copy(f, kotlin_dir / f.name)
        print(f"kopiert: {f.name}")
    for f in sorted((src / "res").rglob("*.xml")):
        target = main / "res" / f.relative_to(src / "res")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(f, target)
        print(f"kopiert: res/{f.relative_to(src / 'res')}")


def gradle_kts(t: str) -> str:
    # Firebase braucht mindestens Android 7 (API 24)
    t = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", t)
    if SIGNED and 'create("release")' not in t:
        signing = (
            "    signingConfigs {\n"
            '        create("release") {\n'
            f'            storeFile = file("{STORE}")\n'
            f'            storePassword = "{PW}"\n'
            '            keyAlias = "echowp"\n'
            f'            keyPassword = "{PW}"\n'
            "        }\n"
            "    }\n"
        )
        t = re.sub(r"(\n\s*buildTypes\s*\{)", "\n" + signing.rstrip("\n") + r"\1", t, count=1)
        t = t.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        if 'signingConfigs.getByName("release")' not in t:
            print("::error::Signatur konnte nicht in build.gradle.kts eingetragen werden")
            sys.exit(1)
    return t


copy_widget_files()
patch(root / "android/app/src/main/AndroidManifest.xml", manifest)
patch(root / "android/app/build.gradle.kts", gradle_kts)
print("Signatur: Release-Schlüssel" if SIGNED else "Signatur: Test-Schlüssel (Secrets fehlen)")
