// Production-host UI capture: real GameUI Lua on the native-contract fixture -> resolved control tree
// -> HTML (scripts/node-ui-preview page(): library pictures are stand-in glyphs) -> headless Chrome PNG.
// Layer: offline layout evidence. NOT simulator art, NOT official PC/phone.
// Usage: npm run build:data && npm run build:ui && node experiments/topbar-sim/render.mjs [outDir]
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { runLua } from '../../scripts/test-lua.mjs';
import { page } from '../../scripts/node-ui-preview.mjs';
const out = resolve(process.argv[2] || '.artifacts/topbar-sim/after');
mkdirSync(out, { recursive: true });
const host = runLua('experiments/topbar-sim/capture.lua', { timeout: 120000 });
if (host.status !== 0) throw new Error(host.stdout.slice(-2000) + host.stderr);
const scenes = JSON.parse(host.stdout.split('PARITY_SCENES ')[1]);
const fix = n => { if (n.children && !Array.isArray(n.children)) n.children = Object.values(n.children); (n.children ?? []).forEach(fix); return n; };
scenes.forEach(s => fix(s.tree));
const chrome = process.env.CHROME || 'google-chrome';
for (const s of scenes) {
  const html = join(out, s.name + '.html');
  writeFileSync(html, page(s.tree));
  writeFileSync(join(out, s.name + '.tree.json'), JSON.stringify(s.tree));
  const r = spawnSync(chrome, ['--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
    '--window-size=1280,720', `--screenshot=${join(out, s.name + '.png')}`, 'file://' + html], { encoding: 'utf8', timeout: 60000 });
  if (r.status !== 0) throw new Error(r.stderr);
}
console.log(scenes.map(s => s.name).join(' '));
