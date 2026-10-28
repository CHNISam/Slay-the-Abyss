import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
import { validateTheme } from '../scripts/build-ui-theme.mjs';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
test('three event/exhaustion relics retain source identities, SPECIAL rarity and explicit temporary theme pictures', () => {
  const data = loadContent('data');
  assert.deepEqual(validateContent(data), []);
  const theme = JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8'));
  assert.deepEqual(validateTheme(theme, data), []);
  for (const [id, source] of [['warped_tongs','WarpedTongs'],['spirit_poop','Spirit Poop'],['circlet','Circlet']]) {
    const relic = data.relics.relics.find(r => r.id === id); assert.ok(relic, id);
    assert.equal(relic.sourceId, source); assert.equal(relic.rarity, 'special');
    assert.ok(relic.name && relic.description);
    assert.equal(theme.icon.relic[id].placeholder, true);
    assert.match(theme.icon.relic[id].note, /临时/);
  }
  assert.equal(data.relics.relics.find(r=>r.id==='circlet').stackable,true);
  assert.equal(data.relics.relics.find(r=>r.id==='spirit_poop').scoreModifier,-1);
});
test('Circlet obtains one slot with repeat counts and Spirit Poop supplies only its source score adjustment', () => {
  buildLuaData();
  const result=runLua('tests/fixtures/js-owned/tests/lua/special_relics.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_SPECIAL_RELIC_OBTAIN_PASS/);
});
