// Select80 sim evidence: the runtime builds lowpolyLand / lowpolyHero (art/lowpoly-select) into
// characterPanel/lowpolyScene and the selection figure host. The static capture has no runtime, so
// inject the SAME production rows into the tree (land scale 1 as in abyss_traveler_portraits, hero
// scaled to portraitFrame width) and hide the fallbacks the runtime hides once ready.
// Usage: node experiments/ui-polish-sim/select-lowpoly-inject.mjs <dir> scene...
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const [dir, ...names] = process.argv.slice(2);
const data = JSON.parse(readFileSync('art/lowpoly-select/select-lowpoly.json'));
const rows = (asset, prefix) => asset.rows.map((r, i) => ({ name: `${prefix}${i}`, kind: 'image', visible: true, position: [r[1], r[2]], size: [r[3], r[4]],
  rotation: [r[5], r[6], r[7]], image: r[0], colour: '#' + [r[8], r[9], r[10], r[11]].map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase() }));
const find = (n, name) => n.name === name ? n : (n.children ?? []).map(c => find(c, name)).find(Boolean);
for (const name of names) {
  const file = join(dir, name + '.tree.json'), tree = JSON.parse(readFileSync(file));
  const panel = find(tree, 'characterPanel');
  const scene = find(panel, 'lowpolyScene');
  if (!scene) throw Error('no lowpolyScene host (build with --art-menu-background=true)');
  Object.assign(scene, { visible: true, children: rows(data.land, 'land') });
  for (const n of ['border', 'face']) { const c = panel.children.find(c => c.name === n); if (c) c.visible = false; }
  const details = find(panel, 'details'), frame = details && find(details, 'portraitFrame');
  if (details && details.visible !== false && frame) {
    const k = frame.size[0] / data.hero.width;
    details.children.push({ name: 'lowpolyHeroSim', kind: 'container', visible: true, position: frame.position, size: [data.hero.width, data.hero.height], scale: [k, k], children: rows(data.hero, 'hero') });
    const fallback = find(details, 'traveler_ironclad'); if (fallback) fallback.visible = false;
  }
  writeFileSync(file, JSON.stringify(tree));
}
