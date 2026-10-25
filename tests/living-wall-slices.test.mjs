import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

test('all original Living Wall base cases and every independent source transform slot execute',()=>{
  const source=readFileSync('tests/lua/support/living_wall_cases.lua','utf8').replaceAll('\r\n','\n');
  const starts=[...source.matchAll(/^test\(/gm)].map(row=>row.index);
  const end=source.lastIndexOf('\nassert(registered');
  assert.equal(starts.length,11);
  const base=starts.flatMap((start,i)=>i===7?[]:[source.slice(start,starts[i+1]??end).trim()]).join('\n');
  // Ten non-matrix bodies plus their intervening helpers are byte-preserved
  // from PR206 at 162dcfb; the matrix retains its per-slot assertions.
  assert.equal(createHash('sha256').update(base).digest('hex'),
    '33a25b6b5f0e79f9e771fd9ad085dc07eab4815fdfd15162c1a2886a4f34b788');
  const pools=JSON.parse(readFileSync('data/reference/sts1-card-pools/pools.json','utf8'));
  assert.equal(pools.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  const expected=[...pools.pools.redReward.COMMON,...pools.pools.srcRed.UNCOMMON,...pools.pools.srcRed.RARE];
  assert.equal(expected.length,72);
  const seen=[],baseCases=[];
  for(const [file,first,last] of [['living_wall.lua',1,24],['living_wall_slice_2.lua',25,48],['living_wall_slice_3.lua',49,72]]) {
    const result=runLua('tests/lua/'+file);
    assert.equal(result.status,0,result.stdout+result.stderr);
    const rows=[...result.stdout.matchAll(/^LIVING_TRANSFORM (\d+) (.+)$/gm)];
    assert.deepEqual(rows.map(row=>Number(row[1])),Array.from({length:last-first+1},(_,i)=>first+i));
    assert.deepEqual(rows.map(row=>row[2]),expected.slice(first-1,last));
    seen.push(...rows.map(row=>Number(row[1])));
    const cases=[...result.stdout.matchAll(/^LIVING_CASE (\d+) /gm)].map(row=>Number(row[1]));
    assert.deepEqual(cases,first===1?Array.from({length:11},(_,i)=>i+1):[8]);
    baseCases.push(...cases.filter(i=>i!==8));
  }
  assert.deepEqual(seen,Array.from({length:72},(_,i)=>i+1));
  assert.deepEqual(baseCases,[1,2,3,4,5,6,7,9,10,11]);
});
