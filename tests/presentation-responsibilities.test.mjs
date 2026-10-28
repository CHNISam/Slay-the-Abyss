import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

for (const [fixture, marker] of [
  ['text', 'PRESENTATION_WORDING_TRACE 361 1837256485'],
  ['trace', 'PRESENTATION_NATIVE_TRACE 79543 1215629804'],
]) {
  test(`presentation responsibilities preserve the frozen ${fixture} contract`, () => {
    const result = runLua(`tests/lua/presentation_responsibilities_${fixture}.lua`);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.stdout.includes(marker), result.stdout);
  });
}
test('native write recorder retains strict field guards and inverts only the reviewed P0 field changes',()=>{
  const result=runLua('tests/lua/presentation_trace_native.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/PRESENTATION_TRACE_NATIVE_PASS/);
});
