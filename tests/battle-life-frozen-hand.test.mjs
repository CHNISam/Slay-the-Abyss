import test from 'node:test';
import assert from 'node:assert/strict';
import {tmpdir} from 'node:os';
import {frozenBattleHandFixtures, frozenBattleHandPrelude} from './helpers/battle-life-frozen-hand.mjs';
import {runLua} from '../scripts/test-lua.mjs';

test('only eighteen exact frozen UI/input entries settle the current first hand before unchanged cases', () => {
  assert.equal(frozenBattleHandFixtures.length, 18);
  assert.equal(new Set(frozenBattleHandFixtures).size, 18);
  const prelude = frozenBattleHandPrelude(frozenBattleHandFixtures[0]);
  assert.match(prelude, /local instance=createCardView\(view,\.\.\.\)/);
  assert.match(prelude, /local result=renderCards\(\.\.\.\)/);
  assert.match(prelude, /for _=1,80 do instance.update\(1\/60\)end/);
  assert.doesNotMatch(prelude, /package\.preload|Combat\.|Run\./);
  for (const path of frozenBattleHandFixtures) {
    assert.equal(frozenBattleHandPrelude(path), prelude);
    assert.equal(frozenBattleHandPrelude(path, {cwd: tmpdir()}), '', 'historical temp projects own their sources');
  }
  for (const path of ['tests/lua/card_flow.lua', 'tests/lua/card_flow_feedback.lua',
    'tests/lua/actor_idle_feedback.lua', 'tests/lua/battle_life_regression.lua',
    'tests/lua/card_feedback.lua', 'tests/lua/battle_ui.lua.bak']) {
    assert.equal(frozenBattleHandPrelude(path), '', 'live or foreign fixtures load production: ' + path);
  }
});

test('current opening-hand input retains fixed screen taps, drags and post-entry targeting', () => {
  assert.equal(frozenBattleHandPrelude('tests/lua/battle_life_opening_input.lua'), '');
  const result=runLua('tests/lua/battle_life_opening_input.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_BATTLE_LIFE_OPENING_INPUT_PASS 3/);
});
