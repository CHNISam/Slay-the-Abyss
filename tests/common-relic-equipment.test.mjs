import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('five common equipment and room/potion effects retain source values and random consumption', () => {
  buildLuaData();
  const result = runLua('tests/lua/common_relic_equipment.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /^LUA_COMMON_RELIC_EQUIPMENT_PASS 8$/m);
  assert.deepEqual(result.stdout.split(/\r?\n/).filter(line => line.startsWith('PASS ')), [
    'PASS Strawberry raises current and max HP by seven on equipment',
    'PASS RegalPillow adds fifteen only to rest recovery; healing still clamps at max',
    'PASS ToyOrnithopter heals five in current battle and in noncombat, clamped',
    'PASS Whetstone and WarPaint shuffle eligible cards using one misc long and upgrade two original identities',
    'PASS empty/singleton equipment upgrades still consume one shuffle seed and never upgrade wrong types',
    'PASS equipment upgrade callback preserves repeatable card semantics and bottled identity',
    'PASS successful equipment obtain receipts retain actual UIDs and before/after levels for zero one and two targets',
    'PASS repeatable upgrades record existing levels and rejected outer transaction preserves original source',
  ], 'all eight equipment cases, including receipt identity and rollback, must execute');
});
