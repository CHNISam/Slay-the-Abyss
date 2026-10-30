import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('Rare relic source hooks execute real combat actions and preserve persistent counters',()=>{
 const r=runLua('tests/lua/rare_relics_hooks.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/RARE_RELICS_HOOKS_PASS/);
});
test('Rare relics are obtained through the real Run and affect normal battles',()=>{
 const r=runLua('tests/lua/rare_relics_run.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/RARE_RELICS_RUN_PASS/);
});
test('Rare camp and Winged Greaves actions use public transactional node commands',()=>{
 const r=runLua('tests/lua/rare_relics_nodes.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/RARE_RELICS_NODES_PASS/);
});
test('Rare camp choices remain reachable through native UI controls',()=>{
 const r=runLua('tests/lua/rare_relics_ui.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/RARE_RELICS_UI_PASS/);
});
