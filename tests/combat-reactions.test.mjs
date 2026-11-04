import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {candidateScriptFiles} from '../scripts/native-candidate-scripts.mjs';
test('reaction admission preserves legacy and typed ordering, identity, errors and dynamic enqueue',()=>{
  const result=runLua('tests/lua/combat_reactions.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/COMBAT_REACTIONS_PASS/);
});
test('reaction entry loads alone and preserves nil restoration and ordinary CardActions writes',()=>{
  const result=runLua('tests/lua/combat_reactions_independence.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/COMBAT_REACTIONS_INDEPENDENCE_PASS/);
});
test('candidate script inventory includes combat reaction admission exactly once',()=>{
  assert.equal(candidateScriptFiles('src/lua','build/lua',[]).filter(row=>row.name==='abyss_combat_reactions').length,1);
});
