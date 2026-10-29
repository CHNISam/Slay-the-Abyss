import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

test('Nodes refactor preserves the frozen baseline API and state transitions',()=>{
  assert.equal(createHash('sha256').update(readFileSync('tests/nodes-governance-baseline.lua','utf8').replaceAll('\r\n','\n')).digest('hex'),
    '74ffe0af91db89dc800878d1385bddba27eeef6b232099336eccad04c2859a04');
  const directory=mkdtempSync(join(tmpdir(),'nodes-governance-'));
  const executed=[];
  try{
    for(let first=1;first<=72;first+=4){
      const last=Math.min(first+3,72),file=join(directory,'slice.lua');
      writeFileSync(file,`assert(loadfile('tests/nodes-governance.lua'))(${first},${last})\n`);
      const started=Date.now();
      const result=runLua(file);
      assert.equal(result.status,0,result.stderr||result.stdout);
      const cases=[...result.stdout.matchAll(/^NODES_GOVERNANCE_CASE (\d+) /gm)].map(x=>Number(x[1]));
      assert.deepEqual(cases,Array.from({length:last-first+1},(_,i)=>first+i));
      assert.match(result.stdout,new RegExp(`NODES_GOVERNANCE_PASS ${first} ${last} ${cases.length};`));
      executed.push(...cases);
      console.log(`Nodes differential ${first}-${last}: ${Date.now()-started} ms`);
    }
  }finally{rmSync(directory,{recursive:true,force:true});}
  assert.deepEqual(executed,Array.from({length:72},(_,i)=>i+1));
});
