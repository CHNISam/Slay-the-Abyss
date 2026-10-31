import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for(const [file,marker]of [
 ['m3_relic_public_camp_skills.lua','M3_RELIC_PUBLIC_LETTER_PASS'],
 ['m3_relic_public_hand_drill.lua','M3_RELIC_PUBLIC_HAND_DRILL_PASS 4'],
 ['m3_relic_public_brimstone.lua','M3_RELIC_PUBLIC_BRIMSTONE_PASS'],
])test(`actual public relic chain: ${file}`,()=>{
 const result=runLua(`tests/lua/${file}`);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.ok(result.stdout.includes(marker),result.stdout);
});
