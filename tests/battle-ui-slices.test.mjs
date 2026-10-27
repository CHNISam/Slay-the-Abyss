import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';

test('the frozen 53 battle UI cases execute once across five original-budget slices',()=>{
  const source=readFileSync('tests/lua/support/battle_ui_cases.lua','utf8').replaceAll('\r\n','\n');
  const body=source.slice(source.indexOf('\ntest('),source.lastIndexOf('\nassert(registered')).trim();
  // Only this reviewed assertion migrates from raw enemy indices to live display slots.
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
  // Inverse-normalize that one migration, then retain PR206's original frozen hash.
  // Every other case body and intervening helper must remain byte-for-byte unchanged.
  assert.equal(createHash('sha256').update(body.replace(migratedDeath,legacyDeath)).digest('hex'),
    'd97b7f1b44cb4c4655f9ae06ec429f88f40bfd322ddb1aa8ab30e4c2d08b9678');
  const seen=[];
  for(const [file,first,last] of [['battle_ui.lua',1,26],['battle_ui_slice_2.lua',27,38],['battle_ui_slice_3.lua',39,44],
    ['battle_ui_slice_4.lua',45,47],['battle_ui_slice_5.lua',48,53]]) {
    const result=runLua('tests/lua/'+file);
    assert.equal(result.status,0,result.stdout+result.stderr);
    const indices=[...result.stdout.matchAll(/^ok UI (\d+) - /gm)].map(row=>Number(row[1]));
    assert.deepEqual(indices,Array.from({length:last-first+1},(_,i)=>first+i));
    seen.push(...indices);
  }
  assert.deepEqual(seen,Array.from({length:53},(_,i)=>i+1));
});
