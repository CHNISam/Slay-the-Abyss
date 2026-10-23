import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { requestedSeeds, mapInvariants } from '../scripts/sts1-map-evidence.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('independent twelve golden graphs forbid crossings and permit single outgoing edges', () => {
  let single = 0, triple = 0;
  for (const seed of requestedSeeds()) {
    const graph = JSON.parse(readFileSync(`tests/fixtures/sts1/maps/${seed}.json`));
    assert.deepEqual(mapInvariants(graph), []);
    for (const node of graph.nodes.filter(node => node.y < 14)) {
      const count = graph.edges.filter(edge => edge.src_x === node.x && edge.src_y === node.y).length;
      assert(count >= 1 && count <= 3, `${seed}/${node.x},${node.y}: ${count}`);
      if (count === 1) single++; if (count === 3) triple++;
    }
  }
  assert(single > 0 && triple > 0, 'reference must exercise both outdegree boundaries');
});

test('production generator clamps the seed0 reverse diagonal and rejects old topology snapshots', () => {
  const result = runLua('tests/lua/map_no_crossings.lua');
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /LUA_MAP_NO_CROSSINGS_PASS 128/);
});
