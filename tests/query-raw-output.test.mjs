import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

for(const [fixture,summary]of [
 ['tests/lua/actor_status_view_differential.lua',/^STATUS_VIEW_PASS 252\r?\n$/],
 ['tests/lua/combat_previews_responsibility.lua',/^COMBAT_PREVIEWS_PASS 164\r?\n$/],
])test(`${fixture} completes its raw entry within the original default output limit`,()=>{
 const result=runLua(fixture);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,summary,'raw entry executes every assertion and reports completion without differential trace output');
});
