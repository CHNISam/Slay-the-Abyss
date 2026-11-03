import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {runStatic} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';

test('real selection protocol preserves candidates, tokens, source identities and rollback',()=>{
  const result=runLua('tests/lua/card_selection_protocol.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/CARD_SELECTION_PROTOCOL_PASS 6/);
});

test('CardActions includes every helper within CC15 except the documented unchanged drain',()=>{
  const sources=discoverSources();
  const measured=measureSources(sources,runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics);
  assert.deepEqual(measured.errors,[]);
  const module=measured.modules.find(m=>m.file==='src/lua/abyss_card_actions.lua');
  // Bound the entire module so relocating a new helper cannot evade coverage.
  // The unchanged CC25 queue owner is an explicit remaining M9 hotspot.
  const drains=module.functions.filter(f=>f.name==='M.drain');
  assert.equal(drains.length,1);
  assert.equal(drains[0].complexity,25);
  const responsibilities=module.functions.filter(f=>f.name!=='M.drain');
  assert(responsibilities.some(f=>f.name==='M.choose'));
  assert(responsibilities.some(f=>f.name==='M.applyChoice'));
  for(const f of responsibilities)assert(f.complexity<=15,`${f.name}: ${f.complexity} exceeds 15`);
});

test('selection eligibility, exact count and copy multiplicity mutations fail behavioral assertions',()=>{
  const source=readFileSync('src/lua/abyss_card_actions.lua','utf8');
  const mutations=[
    ['live eligibility','if not containsUid(candidates(combat,state,choice.op),uid) then','if false then'],
    ['exact required count','#choice.selected~=choice.required','#choice.selected<0'],
    ['replacement multiplicity','count=count+1','count=count+2'],
  ];
  const dir=mkdtempSync(join(tmpdir(),'selection-mutants-'));
  try{
    for(const [label,before,after] of mutations){
      assert.equal(source.split(before).length-1,1,`${label}: unique live mutation`);
      const mutant=join(dir,'mutant.lua'),driver=join(dir,'driver.lua');
      writeFileSync(mutant,source.replace(before,after));
      writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_card_actions=dofile(${luaString(mutant.replaceAll('\\','/'))});dofile(${luaString(resolve('tests/lua/card_selection_protocol.lua').replaceAll('\\','/'))})`);
      const result=runLua(driver);
      assert.notEqual(result.status,0,`${label}: mutant survived`);
      assert.match(result.stdout+result.stderr,/\[SELECTION_CONTRACT\]/,`${label}: genuine assertion failure`);
    }
  }finally{rmSync(dir,{recursive:true,force:true});}
});
