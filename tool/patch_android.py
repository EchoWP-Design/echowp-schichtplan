"""Passt die von `flutter create` erzeugten Android-Dateien an (läuft nur im GitHub-Build)."""
import os
import pathlib
import re
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
    return t


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


patch(root / "android/app/src/main/AndroidManifest.xml", manifest)
patch(root / "android/app/build.gradle.kts", gradle_kts)
print("Signatur: Release-Schlüssel" if SIGNED else "Signatur: Test-Schlüssel (Secrets fehlen)")
