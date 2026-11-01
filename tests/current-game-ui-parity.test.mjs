import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
// Current runtime only; one process per seed bounds native-tree/VM memory.
// Default 30s budgets remain intact. No historical projection or fixture skips.
for(let seed=1;seed<=6;seed++)test(`current generated GameUI full-state trace seed ${seed}`,()=>{
 const file=`tests/lua/current_game_ui_trace_parity${seed===1?'':'_'+seed}.lua`;
 const r=runLua(file);assert.equal(r.status,0,r.stdout+r.stderr);
 assert.deepEqual([...r.stdout.matchAll(/^CURRENT_UI_PLAYBACK_SEED (\d+)$/gm)].map(m=>m[1]),[String(seed)]);
 const summary=r.stdout.match(new RegExp(`CURRENT_GAME_UI_TRACE_PARITY_PASS seed=${seed} commands=(\\d+)`));
 assert.ok(summary,r.stdout);assert.ok(Number(summary[1])>=1&&Number(summary[1])<=20);
 console.log(summary[0]);
});
test('current generated GameUI failure and replacement boundaries',()=>{
 const r=runLua('tests/lua/current_game_ui_failure_boundaries.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/CURRENT_GAME_UI_FAILURE_BOUNDARIES_PASS/);
});
