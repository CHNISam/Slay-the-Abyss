import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { controlsGuide } from '../scripts/controls-guide-layout.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('TASK-4.16 guide is grouped by scene, explains resources, fits the modal and promises no unbound shortcuts', () => {
  const guide = controlsGuide(), names = guide.children.map(c => c.name);
  for (const section of ['battle', 'map', 'resources']) assert(names.includes(section), section);
  assert(!names.some(n => n.startsWith('tip')), 'six-tile dump removed');
  const content0 = JSON.stringify(guide);
  for (const word of ['出牌', '取消', '看详情', '用药水', '看地图', '生命', '金币', '手柄']) assert(content0.includes(word), word);
  assert(names.includes('blocker') && names.includes('catch') && names.indexOf('blocker') < names.indexOf('catch'));
  const visit = (c, x=0, y=0) => {
    x += c.position?.[0] ?? 0; y += c.position?.[1] ?? 0;
    assert(Math.abs(x) + c.size[0]/2 <= 640, c.name);
    assert(Math.abs(y) + c.size[1]/2 <= 360, c.name);
    if (c.text) assert(c.size[1] >= 40, c.name);
    for (const child of c.children ?? []) visit(child,x,y);
  };
  visit(guide);
  const content = JSON.stringify(guide);
  assert(!content.includes('1–9') && !content.includes('Esc') && !content.includes('Tab'));
  const exit = gameLayout().controls.find(c=>c.name==='exitPanel');
  const help = exit.children.find(c=>c.name==='help'), title = exit.children.find(c=>c.name==='title');
  assert(Math.abs(help.position[0]-title.position[0]) >= (help.size[0]+title.size[0])/2);
  assert.deepEqual(help.position,theme.layout.exitMenu.help.slice(0,2)); // TASK-4.11 header slot, off the warning body
});

test('real host isolates guide input, returns controller focus, and retains map navigation after input switching', () => {
  const result=runLua('tests/lua/native_ui_parity.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_UI_PARITY_PASS/);
});

test('TASK-4.16 run menu: outside blocker below a panel catch, primary resume first, abandon separated, no grey map promise', () => {
  const menu = gameLayout().controls.find(c => c.name === 'runMenu'), names = menu.children.map(c => c.name);
  assert(names.indexOf('blocker') < names.indexOf('catch'));
  const y = name => menu.children.find(c => c.name === name).position[1];
  assert(y('resume') > y('help') && y('help') > y('map') && y('map') > y('rule') && y('rule') > y('abandon'));
  assert(!JSON.stringify(menu).includes('启程后可用'));
  const lua = readFileSync('src/lua/abyss_game_ui.lua', 'utf8');
  assert.match(lua, /routeBox:SetVisible\(routeEnabled\)/);
  assert(lua.includes('确认退出本局？目前无法保存进度，退出后本局结束。'), 'keep original quit warning');
  assert(lua.includes('喜欢的话欢迎点赞支持。帮助作者提升等级。'), 'like-support copy only appends the author-level sentence');
  assert.match(lua, /runMenu:GetChild\('blocker'\)[\s\S]{0,200}dismissFromOutside/);
  assert(!/dismissFromOutside[^\n]*abandon/.test(lua));
});
