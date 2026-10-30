import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('actual Book repeated move selection cannot rewrite earlier event intent payloads',()=>{
 const r=runLua('tests/lua/monster_intent_frame_snapshot.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/MONSTER_INTENT_FRAME_SNAPSHOT_PASS/);
});
