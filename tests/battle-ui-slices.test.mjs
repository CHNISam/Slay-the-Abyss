import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

const slices=[['battle_ui.lua',1,26],['battle_ui_slice_2.lua',27,33],['battle_ui_slice_6.lua',34,34],
  ['battle_ui_slice_7.lua',35,38],['battle_ui_slice_3.lua',39,44],['battle_ui_slice_4.lua',45,47],
  ['battle_ui_slice_5.lua',48,53]];

test('frozen battle UI metadata preserves the 53 complete case bodies and seven-slice coverage',()=>{
  const source=readFileSync('tests/lua/support/battle_ui_cases.lua','utf8').replaceAll('\r\n','\n');
  const body=source.slice(source.indexOf('\ntest('),source.lastIndexOf('\nassert(registered')).trim();
  // Review-specific migrations are inverse-normalized; all other frozen cases stay intact.
  const legacyDeath='    assert(poison == 1 and death == 1 and intent == 1 and not stage.children.enemy1.visible)';
  const migratedDeath=[
    '    assert(poison == 1 and death == 1 and intent == 1)',
    '    assert(battle.enemies[1].hp == 0 and battle.enemies[2].hp > 0)',
    '    local survivor = stage.children.enemy1',
    '    assert(survivor.visible and survivor.children.name.text == battle.enemies[2].name)',
    '    assert(survivor.children.hp.text == battle.enemies[2].hp .. "/" .. battle.enemies[2].maxHp)',
    '    for i = 2, 5 do assert(not stage.children["enemy" .. i].visible) end',
  ].join('\n');
  assert.equal(body.split(migratedDeath).length,2,'the exact reviewed migration must occur once');
  assert.equal(body.includes(legacyDeath),false,'the old raw-slot assertion must be replaced');
  const legacyAim='    assert(battle.energy == 3 and #battle.hand == 1 and ui.selected == nil)';
  const migratedAim='    assert(battle.energy == 3 and #battle.hand == 1 and ui.selected == battle.hand[1].uid and ui.carry.aiming)';
  assert.equal(body.split(migratedAim).length,2,'the source persistent-target migration must occur once');
  const motionFrames=[
    '    assert(stage.children.card1.localScaleX == 1, "selection must preserve the current pose before interpolation")',
    '    for _ = 1, 80 do ui:update(1 / 60) end',
    '',
  ].join('\n');
  assert.equal(body.split(motionFrames).length,2,'the source hand interpolation advance must occur once');
  // Latest user instruction adopts AbstractPlayer's persistent target mode on empty release.
  // Inverse-normalize exactly these reviewed migrations, retaining PR206's original frozen hash.
  // Every other case body and intervening helper must remain byte-for-byte unchanged.
  assert.equal(createHash('sha256').update(body.replace(migratedDeath,legacyDeath).replace(migratedAim,legacyAim).replace(motionFrames,'')).digest('hex'),
    'd97b7f1b44cb4c4655f9ae06ec429f88f40bfd322ddb1aa8ab30e4c2d08b9678');
  const coverage=[];
  for(const [file,first,last] of slices) {
    const wrapper=readFileSync('tests/lua/'+file,'utf8').replaceAll('\r\n','\n')
      .split('\n').filter(line=>!line.startsWith('--')).join('\n').trim();
    assert.equal(wrapper,`dofile('tests/lua/support/battle_ui_cases.lua')(${first},${last})`);
    coverage.push(...Array.from({length:last-first+1},(_,i)=>first+i));
  }
  assert.deepEqual(coverage,Array.from({length:53},(_,i)=>i+1));
});

test('the frozen 53 battle UI cases execute once across seven original-budget slices',()=>{
  const seen=[];
  for(const [file,first,last] of slices) {
    const result=runLua('tests/lua/'+file);
    assert.equal(result.status,0,result.stdout+result.stderr);
    const indices=[...result.stdout.matchAll(/^ok UI (\d+) - /gm)].map(row=>Number(row[1]));
    assert.deepEqual(indices,Array.from({length:last-first+1},(_,i)=>first+i));
    seen.push(...indices);
  }
  assert.deepEqual(seen,Array.from({length:53},(_,i)=>i+1));
});
