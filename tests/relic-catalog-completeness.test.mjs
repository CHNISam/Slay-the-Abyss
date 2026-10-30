import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
test('all 130 legal source relics have real runtime bindings and descriptions',()=>{
 const r=runLua('tests/lua/relic_catalog_completeness.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/RELIC_CATALOG_COMPLETENESS_PASS 130/);
});
for(let part=1;part<=4;part++)test(`Big Fish boxes work with unmodified reward queues, seed partition ${part}`,()=>{
 const r=runLua(`tests/lua/natural_event_relics_${part}.lua`);
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/NATURAL_EVENT_RELICS_PASS \d+ \d+ 32/);
});
