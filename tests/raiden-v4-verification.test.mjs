import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

for (const [file,marker] of [
  ['public_commands','RAIDEN_V4_PUBLIC_COMMANDS_PASS 4'],
  ['rollback','RAIDEN_V4_ROLLBACK_PASS 4'],
]) test(`frozen Raiden V4 public Run ${file}`,t=>{
  const result=runLua(`tests/lua/raiden_v4_${file}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.ok(result.stdout.includes(marker),result.stdout);
  t.diagnostic(result.stdout.trim());
});
