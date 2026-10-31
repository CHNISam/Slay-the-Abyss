import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('source victory lifecycle manifest authenticates exact thirteen original Java identities',()=>{
 const bytes=readFileSync('tests/fixtures/victory-relic-counter-source.json');
 assert.equal(createHash('sha256').update(bytes).digest('hex'),'2a01166ec16aa018990912397570f140ad010059c36880c6ff5e931c9e0c14e7');
 const source=JSON.parse(bytes);assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(Object.keys(source.sources).length,13);assert.equal(source.battleIds.length,7);
 assert.equal(source.counterAfterVictory,-1);assert.equal(source.visibleWhenCounterGreaterThan,-1);
});
for(const mutation of [
 {name:'missing public settlement callback',module:'abyss_run_settlement',before:"if result=='victory'then RelicHooks.onVictory(run.combat)end",after:'-- mutation omits settlement victory callback'},
 {name:'missing uncommon victory cleanup',module:'abyss_relic_hooks',before:" require('abyss_uncommon_relics').onVictory(state)",after:' -- mutation omits uncommon victory cleanup'},
])test(`public seven-counter lifecycle rejects ${mutation.name}`,()=>{
 const directory=mkdtempSync(join(tmpdir(),'victory-counter-mutant-'));
 try{
  const source=readFileSync(`src/lua/${mutation.module}.lua`,'utf8');assert.equal(source.split(mutation.before).length,2,'one exact production source site');
  const path=join(directory,'case.lua');writeFileSync(path,`package.preload[${luaString(mutation.module)}]=function()return assert(load(${luaString(source.replace(mutation.before,mutation.after))}))()end\ndofile('tests/lua/support/victory_relic_counters.lua').lifecycle()`);
  const result=runLua(path);assert.notEqual(result.status,0,result.stdout+result.stderr);assert.match(result.stderr,/source victory counter must hide letter_opener/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
