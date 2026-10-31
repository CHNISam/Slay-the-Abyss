// Feed the resolved PRODUCTION control trees (render.mjs output) into beyond-simulator 0.5.2 so official
// picture-library ids render as real textures. Reuses art-tech-lab seed.save.json + rpc.mjs.
// Layer: simulator Host PNG. NOT official PC/phone. No scripts run inside the sim (static frame).
// Usage: node experiments/ui-polish-sim/sim.mjs <dir-with-*.tree.json> scene1 scene2 ...
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { bridge } from '../art-tech-lab/rpc.mjs';
const [dir, ...names] = process.argv.slice(2);
const seed = JSON.parse(readFileSync('experiments/art-tech-lab/seed.save.json'));
const base = seed.assets.server.root.children[0], samples = Object.fromEntries(base.children.map(n => [n.kind, n]));
const argb = h => { h = String(h || '#FFFFFFFF').replace('#', ''); if (h.length === 6) h += 'FF'; return ((parseInt(h.slice(6, 8), 16) << 24) >>> 0) + parseInt(h.slice(0, 6), 16); };
let seq = 0;
function conv(c, parent, root, scale = 1) {
  if (c.visible === false || c.kind === 'cursorArea') return;
  const kind = c.kind === 'image' ? 'image' : c.kind === 'text' ? 'textbox' : 'container';
  const n = structuredClone(kind === 'container' ? root : samples[kind]); n.children = []; n.id = 'p' + (++seq); n.guid = 1073800000 + seq; n.name = c.name; n.scriptMappingIds = []; delete n.isRootContainer;
  const [x, y] = c.position ?? [0, 0], [w, h] = c.size ?? [0, 0];
  for (const t of Object.values(n.transformByPlatform)) { t.offset = { x, y }; t.size = { x: w, y: h }; t.anchorMin = t.anchorMax = { x: .5, y: .5 }; t.scale = { x: c.scale?.[0] ?? 1, y: c.scale?.[1] ?? 1, z: 1 }; t.rotation = Array.isArray(c.rotation) ? { x: c.rotation[0], y: c.rotation[1], z: c.rotation[2] } : { x: 0, y: 0, z: c.rotation ?? 0 }; }
  if (kind === 'image') { n.imageId = c.image; n.imageColor = argb(c.colour); }
  if (kind === 'textbox') Object.assign(n, { text: c.text.content, fontSize: c.text.fontSize, minimumFontSize: c.text.minFontSize ?? c.text.fontSize, fontColor: argb(c.text.colour), bgColor: 0, enableOutline: false,
    horizontalAlignment: c.text.align === 'left' ? 'Left' : 'Middle', verticalAlignment: c.text.valign === 'top' ? 'Top' : 'Middle' });
  parent.children.push(n);
  for (const ch of c.children ?? []) conv(ch, n, root);
}
const unpack = r => r.structuredContent ?? JSON.parse(r.content.find(c => c.type === 'text').text);
const b = bridge();
try {
  await b.request('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'ui-polish', version: '1' } });
  for (const name of names) {
    const save = structuredClone(seed); if (process.env.CANVAS) save.assets.server.canvasId = process.env.CANVAS; const root = save.assets.server.root.children[0];
    root.children = []; root.scriptMappingIds = []; save.assets.scripts = [];
    for (const t of Object.values(root.transformByPlatform)) t.scale = { x: 1, y: 1, z: 1 };
    const tree = JSON.parse(readFileSync(join(dir, name + '.tree.json')));
    for (const c of tree.children) conv(c, root, base);
    const rev = n => { for (const c of n.children) rev(c); n.children.reverse(); }; rev(root);
    const file = join(dir, name + '.sim.save.json'); writeFileSync(file, JSON.stringify(save));
    const { handle } = unpack(await b.call('qxqy_project_open', { path: file }));
    await b.call('qxqy_studio_play', { handle, action: 'start' });
    const canvas = process.env.SIM_CANVAS; if (canvas) await b.call('qxqy_studio_play', { handle, action: 'device', args: { canvasId: canvas } });
    const r = await b.call('qxqy_studio_play_screenshot', { handle });
    const pic = r.content.find(c => c.type === 'image');
    writeFileSync(join(dir, name + (process.env.SIM_CANVAS ? '.' + process.env.SIM_CANVAS : '') + '.sim.png'), Buffer.from(pic.data, 'base64'));
    writeFileSync(join(dir, name + '.sim.receipt.json'), JSON.stringify(r.content.filter(c => c.type !== 'image')));
    console.log(name, seq);
  }
} finally { b.close(); }
