import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('formal shops and elite rewards share complete source queue ownership and RNG',()=>{
 const result=runLua('tests/lua/relic_channel_queues.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LUA_RELIC_CHANNEL_QUEUES_PASS 6/);
});
