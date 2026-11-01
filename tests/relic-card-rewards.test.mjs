import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

for (const fixture of ['relic_card_rewards', 'relic_card_rewards_ui']) {
  test(`independent Prayer Wheel and Singing Bowl rewards: ${fixture}`, () => {
    buildLuaData();
    const result = runLua(`tests/lua/${fixture}.lua`);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /RELIC_CARD_REWARDS.*PASS/);
  });
}
