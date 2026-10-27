import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for(const role of ['ironclad','silent','defect','watcher'])test(`formal ending route retains ${role} across actual combat and reward APIs`,()=>{
 const result=runLua('tests/lua/ending_route_characters.lua',{caseName:role});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp(`ENDING_ROUTE_CHARACTER_PASS ${role}; real 52 camp`));
});
