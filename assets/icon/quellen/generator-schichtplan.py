"""Erzeugt die SVG-Quellen des App-Symbols EchoWP Schichtplan.

Grundlage: rundes Elefanten-Logo (Corporate Design, schriftzug/entwurf-01/rund) wie beim
Symbol von EchoWP-Mail; statt des Umschlags steht ein Kalenderblatt am Echo-Bogen.
Aufruf: python3 generator-schichtplan.py  → icon.svg, icon_foreground.svg, icon_monochrome.svg
"""
import pathlib

Y, K = "#FFD400", "#0A0A0A"
here = pathlib.Path(__file__).resolve().parent


def elefant(stroke: str, fill: str) -> str:
    return (
        f'<g fill="none" stroke="{stroke}" stroke-width="26" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="M104 62 C 60 34, 18 80, 34 130 C 44 160, 74 170, 98 150"/>'
        '<path d="M104 62 C 132 40, 176 50, 182 92 C 186 120, 172 140, 160 160 C 150 178, 156 198, 176 196 C 192 194, 198 178, 194 164"/>'
        '<path d="M216 180 A 32 32 0 0 0 220 138" stroke-width="18"/>'
        f'</g><circle cx="150" cy="90" r="13" fill="{fill}"/>'
    )


def kalender(body: str, cut: str) -> str:
    """Kalenderblatt: Körper mit Kopfzeile, zwei Ringen und 2×2 Feldern; `cut` = Lücke/Linien."""
    return (
        '<g transform="translate(250 244) scale(1.3)">'
        f'<rect x="-35" y="-26" width="70" height="60" rx="10" fill="{body}" stroke="{cut}" stroke-width="12"/>'
        f'<path d="M-29 -7 H29" stroke="{cut}" stroke-width="7"/>'
        f'<rect x="-23" y="1" width="20" height="12" rx="2" fill="{cut}"/>'
        f'<rect x="3" y="1" width="20" height="12" rx="2" fill="{cut}"/>'
        f'<rect x="-23" y="18" width="20" height="10" rx="2" fill="{cut}"/>'
        f'<rect x="3" y="18" width="20" height="10" rx="2" fill="{cut}"/>'
        f'<rect x="-19" y="-36" width="14" height="18" rx="7" fill="{body}" stroke="{cut}" stroke-width="7"/>'
        f'<rect x="5" y="-36" width="14" height="18" rx="7" fill="{body}" stroke="{cut}" stroke-width="7"/>'
        "</g>"
    )


def motiv(scale: float, stroke: str, fill: str, body: str, cut: str) -> str:
    return (
        f'<g transform="translate(512 512) scale({scale}) translate(-160 -163)">'
        + elefant(stroke, fill)
        + kalender(body, cut)
        + "</g>"
    )


head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
icon = head + f'<circle cx="512" cy="512" r="512" fill="{K}"/>' + motiv(2.55, Y, Y, Y, K) + "</svg>"
fg = head + motiv(1.6, Y, Y, Y, K) + "</svg>"
mono = (
    head
    + '<defs><mask id="m">'
    + motiv(1.6, "white", "white", "white", "black")
    + '</mask></defs><rect width="1024" height="1024" fill="#000" mask="url(#m)"/></svg>'
)
for name, svg in [("icon.svg", icon), ("icon_foreground.svg", fg), ("icon_monochrome.svg", mono)]:
    (here / name).write_text(svg + "\n", encoding="utf-8")
    print("erzeugt:", name)
