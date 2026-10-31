import {preIntegrationSource} from './helpers/pr372-integration-source.mjs';
import test from 'node:test';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {mapPathA11yLayer, preMapPathA11ySource as prior} from './helpers/map-path-a11y-inverse.mjs';
const hash = s => createHash('sha256').update(s).digest('hex');
const read = p => preIntegrationSource(p,readFileSync(p, 'utf8').replaceAll('\r\n', '\n'),'map');
const lum = hex => { const c = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
  .map(x => x <= .03928 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4); return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]; };
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m); return (x + .05) / (y + .05); };
const over = (fg, bg, a) => '#' + [1, 3, 5].map(i => Math.round(parseInt(fg.slice(i, i + 2), 16) * a + parseInt(bg.slice(i, i + 2), 16) * (1 - a)).toString(16).padStart(2, '0')).join('');

historicalTest('map path a11y outer inverse exactly recovers prior sources and rejects drift', () => {
  for (const [path, layer] of Object.entries(mapPathA11yLayer)) {
    const live = read(path);
    assert.equal(hash(live), layer.afterSha256, path);
    const before = prior(path, live);
    assert.equal(hash(before), layer.beforeSha256, path);
    assert.equal(prior(path, live.replaceAll('\n', '\r\n')), before);
    assert.equal(prior(path, before), before);
    for (const mutant of [live + '\n', live.slice(1), live.replace(layer.hunks[0].after, layer.hunks[0].after + layer.hunks[0].after)])
      assert.equal(prior(path, mutant), mutant);
  }
  assert.equal(prior('other.lua', 'x'), 'x');
});

test('map node and path states follow STS hierarchy with WCAG 1.4.11 contrast', () => {
  const theme = JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8'));
  const {node, mapCanvas} = theme.color, v = theme.layout.map.presentation, bg = mapCanvas.field;
  const locked = ratio(mapCanvas.far, bg), visited = ratio(mapCanvas.visited, bg);
  for (const ink of Object.values(mapCanvas.kind)) assert.ok(ratio(ink, bg) > Math.max(locked, 4.5), ink);
  assert.ok(locked >= 3 && visited >= 4.5 && visited > locked + 2, 'locked recessive, visited distinct');
  const future = ratio(over(node.path, bg, v.futureOpacity), bg);
  const next = ratio(over(node.reachable, bg, v.nextOpacity), bg);
  const taken = ratio(over(node.pathTaken, bg, v.takenOpacity), bg);
  // Unreachable routes are inactive decoration (WCAG 1.4.11 exemption) and must recede like STS
  // DISABLED edges; live routes stay >= 4.5:1 and at least 3x the recessive stroke.
  assert.ok(future >= 2 && future < locked && next >= 4.5 && taken >= 4.5 && next > future * 3 && taken > future * 3, `${future} ${next} ${taken}`);
  assert.ok(v.pathWidth >= 3);
  assert.match(readFileSync('src/lua/abyss_map_ui.lua','utf8'), /next = pathColour\(Theme\.color\.node\.reachable/);
});
