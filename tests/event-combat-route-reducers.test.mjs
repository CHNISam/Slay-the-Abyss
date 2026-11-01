import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,existsSync,unlinkSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {runLua} from '../scripts/test-lua.mjs';
import {eventCombatRouteFixtures,eventCombatRouteInput} from './helpers/event-combat-route-input.mjs';
test('original event combat reducers preserve real source rewards or refuse atomically without pool edits',()=>{
 const result=runLua('tests/lua/event_combat_route_reducers.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EVENT_COMBAT_ROUTE_REDUCERS_PASS/);
});

test('raw event route fixtures load fresh independent vectors without a JS-produced Lua artifact',()=>{
 assert.deepEqual(eventCombatRouteFixtures,['tests/lua/event_combat_route_reducers.lua','tests/lua/event_combat_route_enemies.lua']);
 const vectors=JSON.parse(readFileSync(eventCombatRouteInput,'utf8'));
 const root=mkdtempSync(join(tmpdir(),'event-combat-route-input-'));
 try{
  mkdirSync(join(root,'tests/lua'),{recursive:true});mkdirSync(join(root,'tests/fixtures'),{recursive:true});
  for(const seed of [vectors.dead[0].seed,'fresh per call']){
   vectors.dead[0].seed=seed;writeFileSync(join(root,eventCombatRouteInput),JSON.stringify(vectors));
   for(const fixture of eventCombatRouteFixtures){
    writeFileSync(join(root,fixture),`local V=require('event_combat_routes_vectors');assert(V.dead[1].seed==${JSON.stringify(seed)});print('FRESH_EVENT_INPUT_PASS')`);
    const result=runLua(fixture,{cwd:root});
    assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/FRESH_EVENT_INPUT_PASS/);
   }
   assert.equal(existsSync(join(root,'build')),false,'preloading must not generate a shared Lua vector file');
  }
  unlinkSync(join(root,eventCombatRouteInput));
  for(const fixture of eventCombatRouteFixtures)assert.throws(()=>runLua(fixture,{cwd:root}),error=>error.code==='ENOENT');
 }finally{rmSync(root,{recursive:true,force:true});}
});
