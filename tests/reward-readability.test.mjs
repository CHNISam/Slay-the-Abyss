import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { buildLuaData } from '../scripts/build-lua-data.mjs';
import { buildUI } from '../scripts/build-ui.mjs';
import { runLua } from '../scripts/test-lua.mjs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';
import { visibleText, textConflicts, capacityProblems, rewardRole, adjacentRole } from './helpers/ui-readability.mjs';

let snapshots;
function rendered() {
  if (snapshots) return snapshots;
  buildLuaData();
  buildUI();
  const result = runLua('tests/fixtures/js-owned/tests/lua/reward_readability.lua');
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /UI_READABILITY_CAPTURE_PASS/);
  snapshots = Object.fromEntries(result.stdout.split(/\r?\n/).filter(line => line.startsWith('UI_READABILITY\t'))
    .map(line => { const [, state, json] = line.split('\t'); return [state, JSON.parse(json)]; }));
  assert.equal(Object.keys(snapshots).length, 23, 'every promised rendered state must be captured');
  mkdirSync('build', { recursive: true });
  writeFileSync('build/reward-readability.json', JSON.stringify(snapshots, null, 2) + '\n');
  return snapshots;
}
const node = (state, path) => state.nodes.find(row => row.path === path);
const shown = (state, path) => node(state, path)?.visible === true;

test('reward titles, live feedback, card text and action captions occupy separate text boxes', () => {
  const cases = rendered();
  const failures = Object.entries(cases).filter(([, state]) => state.meta.phase === 'reward')
    .flatMap(([name, state]) => textConflicts(state.nodes, rewardRole).map(error => `${name}: ${error}`));
  assert.equal(failures.length, 0, failures.join('\n'));
});

test('reward copy fits the native line budget without shrinking below the approved minimum', () => {
  const failures = Object.entries(rendered()).filter(([, state]) => state.meta.phase === 'reward')
    .flatMap(([name, state]) => capacityProblems(state.nodes.filter(row => rewardRole(row.path) && rewardRole(row.path) !== 'card'),
      nativeTheme.layout.nativeText.lineHeight).map(error => `${name}: ${error}`));
  assert.equal(failures.length, 0, failures.join('\n'));
});

test('reward list, card choice, feedback and leave action have consistent rendered ownership', () => {
  const cases = rendered();
  for (const name of ['reward-list', 'card-added', 'card-skipped', 'potion-claimed', 'reward-redraw',
    'potion-full', 'potion-full-card-added', 'potion-full-rejected', 'stolen-gold-list', 'stolen-gold-claimed']) {
    const state = cases[name];
    assert.ok(shown(state, '/battlePanel/rewardList'), `${name}: reward list must own its title and feedback`);
    assert.ok(!shown(state, '/battlePanel/rewardStage'), `${name}: card-pick panel leaks into reward list`);
    assert.ok(!shown(state, '/battlePanel/card1'), `${name}: card choices leak into reward list`);
    assert.ok(shown(state, '/battlePanel/continue'), `${name}: list must have a visible leave action`);
    assert.ok(!shown(state, '/battlePanel/skip'), `${name}: card-choice skip leaks into list`);
    assert.ok(!shown(state, '/battlePanel/notice'), `${name}: global battle notice must yield to local reward feedback`);
    assert.ok(visibleText(state.nodes).some(row => row.path === '/battlePanel/rewardList/title'), `${name}: missing readable list title`);
  }
  for (const name of ['card-pick', 'card-pick-settled', 'card-pick-hover']) {
    const state = cases[name];
    assert.ok(shown(state, '/battlePanel/rewardStage') && shown(state, '/battlePanel/card1'), `${name}: choices must be visible`);
    for (const path of ['rewardList', 'continue', 'claimPotion', 'stolenGold', 'goldReward', 'cardReward', 'potionHelp/potionReward', 'notice'])
      assert.ok(!shown(state, `/battlePanel/${path}`), `${name}: ${path} leaks into card choice`);
    assert.ok(shown(state, '/battlePanel/skip'), `${name}: card-choice back action missing`);
  }
  assert.ok(!shown(cases['potion-claimed'], '/battlePanel/claimPotion'), 'claimed bottle must not retain a live row');
  assert.ok(!shown(cases['stolen-gold-claimed'], '/battlePanel/stolenGold'), 'claimed gold must not retain a live row');
  const feedback = name => visibleText(cases[name].nodes).find(row => row.path === '/battlePanel/rewardList/subtitle')?.text;
  for (const name of ['card-added', 'potion-claimed', 'potion-full-rejected', 'stolen-gold-claimed'])
    assert.ok(feedback(name), `${name}: hiding the global notice must preserve visible local feedback`);
  assert.notEqual(feedback('card-added'), feedback('reward-list'), 'card result must replace idle instructions');
  assert.notEqual(feedback('potion-claimed'), feedback('card-added'), 'potion result must replace stale card feedback');
  for (const name of ['potion-full', 'potion-full-rejected'])
    assert.ok(visibleText(cases[name].nodes).some(row => row.path === '/battlePanel/potionHelp/potionReward'), `${name}: full-belt explanation missing`);
  assert.ok(!visibleText(cases['potion-claimed'].nodes).some(row => row.path === '/battlePanel/potionHelp/potionReward'),
    'resolved bottle must hide its former full-belt explanation');
});

test('adjacent menu, map, node and battle headers do not share boxes with active feedback', () => {
  const failures = Object.entries(rendered()).filter(([, state]) => state.meta.phase !== 'reward')
    .flatMap(([name, state]) => textConflicts(state.nodes, adjacentRole).map(error => `${name}: ${error}`));
  assert.equal(failures.length, 0, failures.join('\n'));
  const cases = rendered();
  assert.ok(visibleText(cases['battle-feedback'].nodes).some(row => row.path === '/battlePanel/notice'));
  assert.ok(!visibleText(cases['battle-feedback-cleared'].nodes).some(row => row.path === '/battlePanel/notice'));
  const report = Object.fromEntries(['menu', 'map', 'map-feedback', 'battle', 'battle-feedback', 'camp', 'camp-feedback']
    .map(name => [name, capacityProblems(cases[name].nodes.filter(row => adjacentRole(row.path)), nativeTheme.layout.nativeText.lineHeight)]));
  // Existing neighboring short-frame risks are reported separately. They are
  // not evidence of a fresh native failure or an excuse to weaken rewards.
  writeFileSync('build/ui-readability-adjacent-risks.json', JSON.stringify(report, null, 2) + '\n');
});

test('the rendered-text guard rejects feedback and caption collisions without flagging decorative or hidden layers', () => {
  const nodes = rendered()['card-added'].nodes;
  const title = nodes.find(row => row.path === '/battlePanel/rewardList/title' && row.visible) ||
    nodes.find(row => row.path === '/battlePanel/rewardStage/title' && row.visible);
  const feedback = { ...nodes.find(row => row.path === '/battlePanel/notice'), visible: true,
    text: '卡牌已加入牌组；其他奖励请单独处理。', rect: [...title.rect] };
  assert.equal(textConflicts([title, feedback], rewardRole).length, 1, 'same escaped collision must reject');
  assert.equal(textConflicts([title, { ...feedback, visible: false }], rewardRole).length, 0, 'hidden feedback has no glyphs');
  assert.equal(textConflicts([title, { ...feedback, kind: 'image' }], rewardRole).length, 0, 'background overlap is legal');
  const caption = { ...feedback, path: '/battlePanel/claimPotion/normal/label', text: '领取药水' };
  assert.equal(textConflicts([caption, { ...feedback, path: '/battlePanel/potionHelp/potionReward' }], rewardRole).length, 1,
    'action captions must not share a text box with explanations');
  assert.equal(capacityProblems([{ ...caption, size: [500, 39] }]).length, 1, 'short native frame must reject');
});
