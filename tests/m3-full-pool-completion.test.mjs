import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
for(const [act,first,last] of [[1,1,12],[1,13,24],[2,1,15],[2,16,31]]){
 test(`public act${act} full-source identities ${first}-${last} complete through public commands`,()=>{
  const result=runLua(`tests/lua/m3_full_pool_completion_${act}_${first}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`M3_FULL_POOL_COMPLETION act${act} ${first}-${last} ${last-first+1} routes passed`));
 });
}
