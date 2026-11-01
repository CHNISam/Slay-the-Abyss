import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { buildLuaData, toLua } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('actual capability agrees with independently declared launch inclusions and exclusions', () => {
  const manifest = JSON.parse(readFileSync('data/release/launch-content.json', 'utf8'));
  assert.equal(manifest.cards.length, 75);
  assert.equal(manifest.generatedCards.filter(row => row.type === 'curse').length, 12);
  assert.equal(manifest.generatedCards.filter(row => row.type === 'status').length, 4);
  const bell = manifest.generatedCards.find(row => row.id === 'curse_of_the_bell');
  assert.equal(bell.sourceId, 'CurseOfTheBell');
  assert.equal(bell.unremovable, true);
  const necro=manifest.generatedCards.find(row=>row.id==='necronomicurse');
  assert.equal(necro.type,'curse');assert.equal(necro.countsTowardSeventyFive,false);
  assert.ok(necro.channels.includes('explicit_event:cursed_tome:claim'));
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
assert(definitions.curse_of_the_bell.sourceId=='CurseOfTheBell' and definitions.curse_of_the_bell.type=='curse')
assert(M.isImplemented(definitions.curse_of_the_bell),'Calling Bell curse must retain its explicit lifecycle capability')
local transforms=assert(require('abyss_event_transform_context').new({data=data}))
assert(#transforms.pools.curses==10,'ordinary random curse pool must retain all ten source entries')
for _,id in ipairs(transforms.pools.curses)do assert(id~='CurseOfTheBell' and id~='curse_of_the_bell','Bell curse must not enter ordinary random draws')end
assert(definitions.necronomicurse.sourceId=='Necronomicurse' and definitions.necronomicurse.type=='curse')
assert(M.isImplemented(definitions.necronomicurse),'Necronomicon curse must retain its explicit rebirth capability')
for _,id in ipairs(transforms.pools.curses)do assert(id~='Necronomicurse' and id~='necronomicurse','Necronomicurse must not enter ordinary random draws')end
assert(M.isImplemented(definitions.dazed),'legitimate ethereal status must remain implemented')
assert(not M.isImplemented({id='unknown_curse',type='curse',cost=-2,effects={}}))
assert(not M.isImplemented({id='unknown_status',type='status',cost=-2,effects={}}))
-- Affordability is temporary; zero energy is not a reason to disable a definition.
assert(M.isImplemented(definitions.bludgeon))
print('CARD_CAPABILITY_PASS '..#expected.included..' included '..#expected.excluded..' excluded')
`);
  const result = runLua('build/lua/card_capability_fixture.lua');
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /CARD_CAPABILITY_PASS 91 included 0 excluded/);
});
