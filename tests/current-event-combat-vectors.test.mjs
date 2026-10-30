import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {toLua} from '../scripts/build-lua-data.mjs';
import {currentEventCombatVectorFixtures as fixtures,currentEventCombatVectorPrelude as prelude} from './helpers/current-event-combat-vectors.mjs';
test('only the exact two current event combat fixtures receive their original JSON vector producer',()=>{
 assert.deepEqual(fixtures,['tests/lua/event_combat_route_enemies.lua','tests/lua/event_combat_route_reducers.lua']);
 const expected=`package.preload['event_combat_routes_vectors']=function() return ${toLua(JSON.parse(readFileSync('tests/fixtures/event-combat-routes-vectors.json','utf8')))} end;`;
 for(const path of fixtures)assert.equal(prelude(path),expected);
 for(const path of ['tests/lua/event_combat_route_terminal.lua',resolve(fixtures[0]),'other/'+fixtures[0],fixtures[0]+'.bak']){
  assert.equal(prelude(path,{readSource(){throw Error('unexpected read');}}),'');
 }
 assert.equal(prelude(fixtures[0],{cwd:'/other-checkout',readSource(){throw Error('unexpected read');}}),'');
});
test('current vector inputs are freshly read and malformed or missing inputs fail instead of using stale generated output',()=>{
 let calls=0;const readSource=()=>{calls++;return JSON.stringify({marker:calls});};
 assert.notEqual(prelude(fixtures[0],{readSource}),prelude(fixtures[0],{readSource}));assert.equal(calls,2);
 assert.throws(()=>prelude(fixtures[0],{readSource:()=>'{broken'}),SyntaxError);
 assert.throws(()=>prelude(fixtures[0],{readSource(){throw Error('missing exact vectors');}}),/missing exact vectors/);
});
