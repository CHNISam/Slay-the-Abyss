import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { buildLuaData, toLua } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('actual capability agrees with independently declared launch inclusions and exclusions', () => {
  const manifest = JSON.parse(readFileSync('data/release/launch-content.json', 'utf8'));
  buildLuaData(); mkdirSync('build/lua', { recursive: true });
  const expected = { included: [...manifest.cards, ...manifest.generatedCards].map(row => row.id),
    excluded: manifest.exclusions.cards.map(row => row.id) };
  writeFileSync('build/lua/card_capability_fixture.lua', `
local expected=${toLua(expected)}
local M=require('abyss_card_capability');local data=require('abyss_data')
local definitions={};for _,d in ipairs(data.cards.cards)do definitions[d.id]=d end
for _,id in ipairs(expected.included)do assert(M.isImplemented(assert(definitions[id])),'missing capability '..id)end
for _,id in ipairs(expected.excluded)do assert(not M.isImplemented(assert(definitions[id])),'prototype enabled '..id)end
assert(M.isImplemented(definitions.regret),'legitimate unplayable curse must remain obtainable')
assert(M.isImplemented(definitions.dazed),'legitimate ethereal status must remain implemented')
assert(not M.isImplemented({id='unknown_curse',type='curse',cost=-2,effects={}}))
assert(not M.isImplemented({id='unknown_status',type='status',cost=-2,effects={}}))
-- Affordability is temporary; zero energy is not a reason to disable a definition.
assert(M.isImplemented(definitions.bludgeon))
print('CARD_CAPABILITY_PASS '..#expected.included..' included '..#expected.excluded..' excluded')
`);
  const result = runLua('build/lua/card_capability_fixture.lua');
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /CARD_CAPABILITY_PASS 80 included 0 excluded/);
});
