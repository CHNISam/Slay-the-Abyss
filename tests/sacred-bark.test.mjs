import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for (const [name,count] of [['channels',2],['potions',6],['advanced',4],['ui',2]]) test(`Sacred Bark actual source acquisition and ${name}`,()=>{
 const r=runLua(`tests/lua/sacred_bark_${name}.lua`);
 assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,new RegExp(`SACRED_BARK_${name.toUpperCase()}_PASS ${count}`));
});
