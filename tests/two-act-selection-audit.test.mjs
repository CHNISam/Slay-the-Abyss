import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';

for (const [name, marker] of [
  ['events_act1', 'TWO_ACT_SELECTION_EVENTS_PASS 1'],
  ['events_act2', 'TWO_ACT_SELECTION_EVENTS_PASS 2'],
  ['relics', 'TWO_ACT_SELECTION_RELICS_PASS 130'],
  ['pending', 'TWO_ACT_SELECTION_PENDING_PASS 11'],
]) {
  test(`competition selection audit: ${name}`, () => {
    const result = runLua(`tests/lua/two_act_selection_${name}.lua`);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.stdout.includes(marker), result.stdout);
  });
}

for (const [name, mutation, marker] of [
  ['success without a transaction', `A.H.Nodes.chooseEvent=function()return true,'pending'end`, 'SELECTION_NO_PROGRESS'],
  ['disabled reward options', `local original=A.H.Nodes.view
A.H.Nodes.view=function(...)
 local view=original(...)
 for _,row in ipairs(view.node and view.node.event and view.node.event.options or {})do
  if row.choice~='leave'then row.enabled=false end
 end
 return view
end`, 'SELECTION_OPTIONS_CHANGED'],
]) {
  test(`selection audit rejects ${name}`, () => {
    const directory = mkdtempSync(join(tmpdir(), 'abyss-selection-audit-'));
    try {
      const script = join(directory, 'mutant.lua');
      writeFileSync(script, `local A=dofile('tests/lua/support/two_act_selection_audit.lua')\n${mutation}\nA.events(2)\n`);
      const result = runLua(script);
      assert.notEqual(result.status, 0, result.stdout + result.stderr);
      assert.ok((result.stdout + result.stderr).includes(marker), result.stdout + result.stderr);
    } finally {
      rmSync(directory, {recursive:true, force:true});
    }
  });
}
