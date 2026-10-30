import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
test('event constructors and AI use source streams and legal public turns without combat stat injection',()=>{
 mkdirSync('build/lua',{recursive:true});writeFileSync('build/lua/event_combat_routes_vectors.lua',`return ${toLua(JSON.parse(readFileSync('tests/fixtures/event-combat-routes-vectors.json','utf8')))}`);
 const result=runLua('tests/lua/event_combat_route_enemies.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EVENT_COMBAT_ROUTE_ENEMIES_PASS/);
});
