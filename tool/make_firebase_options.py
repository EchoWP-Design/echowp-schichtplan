"""Erzeugt lib/firebase_options.dart aus dem GitHub-Secret GOOGLE_SERVICES_JSON (läuft nur im Build).

Die Datei landet nie im Repository (.gitignore).
"""
import json
import os
import pathlib
import sys

PACKAGE = "de.echowp.schichtplan"
root = pathlib.Path(__file__).resolve().parent.parent

raw = os.environ.get("GOOGLE_SERVICES_JSON", "").strip()
if not raw:
    print("::error::Secret GOOGLE_SERVICES_JSON fehlt (Firebase → google-services.json)")
    sys.exit(1)
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"::error::GOOGLE_SERVICES_JSON ist kein gültiges JSON: {e}")
    sys.exit(1)

clients = data.get("client", [])
client = next(
    (c for c in clients if c.get("client_info", {}).get("android_client_info", {}).get("package_name") == PACKAGE),
    None,
)
if client is None:
    found = [c.get("client_info", {}).get("android_client_info", {}).get("package_name") for c in clients]
    print(f"::error::In google-services.json fehlt die Android-App {PACKAGE} (gefunden: {found})")
    sys.exit(1)

project = data["project_info"]


def dart(s: str) -> str:
    return "'" + str(s).replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


fields = {
    "apiKey": client["api_key"][0]["current_key"],
    "appId": client["client_info"]["mobilesdk_app_id"],
    "messagingSenderId": project["project_number"],
    "projectId": project["project_id"],
    "storageBucket": project.get("storage_bucket", ""),
}
body = "\n".join(f"  {k}: {dart(v)}," for k, v in fields.items())
out = root / "lib" / "firebase_options.dart"
out.write_text(
    "// Automatisch erzeugt von tool/make_firebase_options.py – nicht einchecken.\n"
    "import 'package:firebase_core/firebase_core.dart';\n\n"
    f"final FirebaseOptions firebaseOptions = FirebaseOptions(\n{body}\n);\n",
    encoding="utf-8",
)
print(f"erzeugt: {out.relative_to(root)} (Projekt {project['project_id']})")
