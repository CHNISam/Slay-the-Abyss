import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync,cpSync,mkdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {spawnSync} from 'node:child_process';
import {mobileQaMigration,materializeBeforeMobileQa} from './helpers/mobile-qa-source-inverse.mjs';

test('Nodes refactor preserves the frozen baseline API and state transitions',()=>{
  assert.equal(createHash('sha256').update(readFileSync('tests/nodes-governance-baseline.lua','utf8').replaceAll('\r\n','\n')).digest('hex'),
    '74ffe0af91db89dc800878d1385bddba27eeef6b232099336eccad04c2859a04');
  const directory=mkdtempSync(join(tmpdir(),'nodes-governance-'));
  const executed=[];
  try{
    assert.equal(mobileQaMigration.baseline,'58f72c2cc43a2833e9e1cdefe7c332ff0fd49243');
    // Replay the complete pre-Mobile source tree. New live APIs are covered by
    // their feature tests; this differential retains every original API/graph assertion.
    for(const input of ['src','data','scripts'])cpSync(input,join(directory,input),{recursive:true});
    mkdirSync(join(directory,'tests'),{recursive:true});
    for(const input of ['tests/nodes-governance.lua','tests/nodes-governance-baseline.lua'])
      cpSync(input,join(directory,input));
    materializeBeforeMobileQa(directory);
    console.log(`Nodes historical source: ${mobileQaMigration.baseline}; ${Object.keys(mobileQaMigration.files).length} complete bindings; archive ${createHash('sha256').update(readFileSync('docs/reviews/mobile-qa-source-migration-20261028.json.gz')).digest('hex')}`);
    const built=spawnSync(process.execPath,['scripts/build-lua-data.mjs'],{
      cwd:directory,encoding:'utf8',timeout:30000,windowsHide:true,
    });
    assert.ifError(built.error);assert.equal(built.status,0,built.stdout+built.stderr);
    for(let first=1;first<=72;first+=4){
      const last=Math.min(first+3,72),file=join(directory,'slice.lua');
      writeFileSync(file,`assert(loadfile('tests/nodes-governance.lua'))(${first},${last})\n`);
      const started=Date.now();
      const result=runLua(file,{cwd:directory});
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
