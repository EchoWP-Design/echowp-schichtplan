# EchoWP Schichtplan – App-Symbol

Grundlage: rundes Elefanten-Logo (Corporate Design, `schriftzug/entwurf-01/rund/rund-elefant`), Gelb #FFD400 auf Schwarz #0A0A0A, Kalenderblatt am Echo-Bogen (Bauweise wie EchoWP-Mail).

| Datei | Zweck |
|---|---|
| `icon.svg` / `../icon.png` | Hauptsymbol (runder schwarzer Kreis) |
| `icon_foreground.svg` / `../icon_foreground.png` | Android Adaptive Icon, Vordergrund (Motiv in der Sicherheitszone, Hintergrund #0A0A0A) |
| `icon_monochrome.svg` / `../icon_monochrome.png` | Android 13+ Themensymbole |

Neu erzeugen: `python3 generator-schichtplan.py`, PNGs + Vorschau mit `node render-vorschau.js <quellen> <ziel>` (Playwright).
