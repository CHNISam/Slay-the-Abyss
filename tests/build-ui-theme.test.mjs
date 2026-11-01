import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildUiTheme, colourToLua, validateTheme } from '../scripts/build-ui-theme.mjs';
import { luaString } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { loadContent } from '../scripts/validate-data.mjs';

const theme = () => JSON.parse(readFileSync('data/presentation/ui_theme.json', 'utf8'));
const content = loadContent('data');

function temporary(action) {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-theme-'));
  try { return action(directory); } finally { rmSync(directory, { recursive: true, force: true }); }
}

test('colours convert to the 0-255 channels the client Color() expects', () => {
  assert.deepEqual(colourToLua('#D9BE8A'), { r: 217, g: 190, b: 138, a: 255 });
  assert.deepEqual(colourToLua('#0E1018CC'), { r: 14, g: 16, b: 24, a: 204 });
});

test('shipped theme passes validation and covers every enemy, status, potion, relic and node type', () => {
  assert.deepEqual(validateTheme(theme(), content), []);
});

test('source class-common relics retain localized identities and explicit temporary theme mappings', () => {
  const shipped = theme();
  for (const [id, sourceId, name, picture] of [
    ['snake_skull', 'Snake Skull', '异蛇头骨', 102031],
    ['data_disk', 'DataDisk', '数据磁盘', 102028],
    ['damaru', 'Damaru', '手摇鼓', 102028],
  ]) {
    const definition = content.relics.relics.find(relic => relic.id === id);
    assert.equal(definition?.sourceId, sourceId);
    assert.equal(definition?.name, name);
    assert.equal(shipped.icon.relic[id].id, picture);
    assert.equal(shipped.icon.relic[id].placeholder, true);
    assert.match(shipped.icon.relic[id].note, /专属美术与设备验收待完成/);
    const missing = structuredClone(shipped); delete missing.icon.relic[id];
    assert.ok(validateTheme(missing, content).includes(`icon.relic has no picture for ${id}`));
  }
});

test('actor action sounds cannot silently disappear from a player or enemy profile', () => {
  for (const key of ['player_action', ...content.enemies.enemies.map(enemy => `action_${enemy.id}`)]) {
    const broken = theme();
    delete broken.sound[key];
    assert.ok(validateTheme(broken, content).includes(`sound.${key} has no actor action sound`));
  }
});

test('validation rejects unreadable fonts, bad colours, unknown pictures and missing portraits', () => {
  const broken = theme();
  broken.font.card = 11;
  broken.color.gold = 'gold';
  broken.icon.hp = 999999;
  delete broken.icon.enemy.guardian;
  const errors = validateTheme(broken, content).join('\n');
  assert.match(errors, /font\.card is below/);
  assert.match(errors, /color\.gold is not/);
  assert.match(errors, /icon\.hp is not in the picture library/);
  assert.match(errors, /icon\.enemy has no picture for guardian/);
});

test('built theme loads in Lua with converted colours and without the design note', () => temporary(directory => {
  const output = join(directory, 'abyss_theme.lua');
  assert.equal(buildUiTheme(undefined, undefined, output), buildUiTheme(undefined, undefined, output));
  const script = join(directory, 'load.lua');
  writeFileSync(script, `package.path=${luaString(directory.replaceAll('\\', '/') + '/?.lua;')}..package.path\nlocal t=require('abyss_theme')\nassert(t.color.gold.r==227 and t.color.backdropVeil.a==204)\nassert(t.note==nil and t.layout.card.size[1]==148)\nassert(t.icon.gold.id==105077)\nprint('theme loaded')\n`);
  const result = runLua(script);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /theme loaded/);
}));

test('native card portrait source dimensions are validated without treating them as image IDs',()=>{
  const portrait=theme();
  portrait.icon.cardPortraits.strike={id:102035,status:'test-native-asset',size:[288,128]};
  assert.deepEqual(validateTheme(portrait,content),[]);
  for(const size of [[0,128],[-1,64],[144],[144,64,1],['144',64],[Infinity,64]]) {
    portrait.icon.cardPortraits.strike.size=size;
    assert(validateTheme(portrait,content).some(error=>error.includes('cardPortraits.strike.size')),JSON.stringify(size));
  }
});
