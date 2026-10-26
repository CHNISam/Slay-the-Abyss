import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

test('the frozen 53 battle UI cases execute once across both original-budget slices',()=>{
  const source=readFileSync('tests/lua/support/battle_ui_cases.lua','utf8').replaceAll('\r\n','\n');
  const body=source.slice(source.indexOf('\ntest('),source.lastIndexOf('\nassert(registered')).trim();
  // PR206 at 162dcfb: all case bodies and intervening helpers, unchanged.
  assert.equal(createHash('sha256').update(body).digest('hex'),
    'd97b7f1b44cb4c4655f9ae06ec429f88f40bfd322ddb1aa8ab30e4c2d08b9678');
  const seen=[];
  for(const [file,first,last] of [['battle_ui.lua',1,26],['battle_ui_slice_2.lua',27,53]]) {
    const result=runLua('tests/lua/'+file);
    assert.equal(result.status,0,result.stdout+result.stderr);
    const indices=[...result.stdout.matchAll(/^ok UI (\d+) - /gm)].map(row=>Number(row[1]));
    assert.deepEqual(indices,Array.from({length:last-first+1},(_,i)=>first+i));
    seen.push(...indices);
  }
  assert.deepEqual(seen,Array.from({length:53},(_,i)=>i+1));
});
