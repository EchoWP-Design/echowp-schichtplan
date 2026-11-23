const { chromium } = require('playwright');
const fs = require('fs');
const [,, src, out] = process.argv;
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  for (const n of ['icon', 'icon_foreground', 'icon_monochrome']) {
    const svg = fs.readFileSync(`${src}/${n}.svg`, 'utf8');
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await p.screenshot({ path: `${out}/${n}.png`, omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  }
  const fg = Buffer.from(fs.readFileSync(`${src}/icon_foreground.svg`)).toString('base64');
  const ic = Buffer.from(fs.readFileSync(`${src}/icon.svg`)).toString('base64');
  const mo = Buffer.from(fs.readFileSync(`${src}/icon_monochrome.svg`)).toString('base64');
  const tile = (bg, img, r, s, z) => `<div style="width:${s}px;height:${s}px;border-radius:${r};background:${bg};overflow:hidden;display:inline-block;margin:12px;vertical-align:middle;position:relative"><img src="data:image/svg+xml;base64,${img}" style="position:absolute;width:${z?150:100}%;height:${z?150:100}%;left:${z?-25:0}%;top:${z?-25:0}%"></div>`;
  await p.setViewportSize({ width: 1100, height: 360 });
  await p.setContent(`<body style="margin:0;background:#3a3f44;padding:20px;font-family:sans-serif;color:#fff">
    ${tile('#0A0A0A', fg, '50%', 220, 1)}${tile('#0A0A0A', fg, '22%', 220, 1)}${tile('transparent', ic, '0', 220)}
    ${tile('#e8e0ff', mo, '50%', 220, 1)}${tile('#0A0A0A', fg, '50%', 48, 1)}${tile('#0A0A0A', fg, '22%', 48, 1)}
    <div>runde Maske · abgerundete Maske · Hauptsymbol · Monochrom (Thema) · 48 px rund · 48 px abgerundet</div></body>`);
  await p.screenshot({ path: `${out}/00_uebersicht-launcher.png` });
  await b.close();
})();
