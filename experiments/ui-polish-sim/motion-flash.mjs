// Scripted motion evidence: run real GameUI + abyss_map_ui update(dt) on the Lua fixture, capture a
// tree per frame (t0..tN), render each through beyond-simulator (sim.mjs), and stitch a GIF.
// Motion VALUES come from production Lua; PIXELS come from the simulator with official textures.
// Usage: node experiments/ui-polish-sim/motion.mjs [outDir]   (env MOTION_FRAMES, MOTION_STEP)
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { runLua } from '../../scripts/test-lua.mjs';
const out = process.argv[2] || '.artifacts/map413/v3/motion-flash';
mkdirSync(out, { recursive: true });
const host = runLua('experiments/ui-polish-sim/motion-flash.lua', { timeout: 120000 });
if (host.status !== 0) throw new Error(host.stdout.slice(-2000) + host.stderr);
writeFileSync(join(out, 'frames.log'), host.stderr);
const scenes = JSON.parse(host.stdout.split('PARITY_SCENES ')[1]);
const fix = n => { if (n.children && !Array.isArray(n.children)) n.children = Object.values(n.children); (n.children ?? []).forEach(fix); return n; };
for (const s of scenes) writeFileSync(join(out, s.name + '.tree.json'), JSON.stringify(fix(s.tree)));
const names = scenes.map(s => s.name);
const r = spawnSync(process.execPath, ['experiments/ui-polish-sim/sim.mjs', out, ...names], { stdio: 'inherit' });
if (r.status !== 0) throw new Error('sim.mjs failed');
const g = spawnSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', '3', '-i', join(out, 'flash-t%d.sim.png'),
  '-vf', 'split[a][b];[a]palettegen[p];[b][p]paletteuse', '-loop', '0', join(out, 'flash.gif')], { stdio: 'inherit' });
console.log(names, g.status === 0 ? 'gif ok' : 'gif skipped (ffmpeg missing)');
