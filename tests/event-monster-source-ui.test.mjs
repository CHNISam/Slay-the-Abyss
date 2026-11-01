import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('event-only bandits and awake Lagavulin retain exact source geometry and intent metadata',()=>{
 const r=runLua('tests/lua/event_monster_source_ui.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/EVENT_MONSTER_SOURCE_UI_PASS 4 definitions \/ 9 moves/);
});
