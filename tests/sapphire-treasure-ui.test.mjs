import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { nodeLayout } from '../scripts/node-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('generated treasure retains legacy commands and adds four visible reward rows',()=>{
  const root=nodeLayout().controls[0], treasure=root.children.find(control=>control.name==='treasureView');
  assert.deepEqual(treasure.children.map(control=>control.name),
    ['glow','closed','open','chest','hint','reward','take','previous','next','page','bossDescription',
      'rewardItem1','rewardItem2','rewardItem3','rewardItem4','burst','details']);
  const take=treasure.children.find(control=>control.name==='take');
  const footer=root.children.find(control=>control.name==='confirm');
  assert.ok(root.children.indexOf(footer)>root.children.indexOf(treasure));
  assert.ok(take.position[0]+take.size[0]/2<footer.position[0]-footer.size[0]/2);
  assert.deepEqual(take.position,[0,-244]);assert.deepEqual(footer.position,[490,-290]);
  const source=readFileSync('src/lua/abyss_node_ui.lua','utf8');
  assert.match(source,/commit\("chooseTreasure", source,/);
  assert.match(source,/pcall\(Nodes\.chooseTreasure, self\.run, self\.map, argument, choice\)/);
});

for (const [file,groups] of [['sapphire_treasure_ui.lua',8],['sapphire_treasure_ui_slice_2.lua',2],
  ['sapphire_treasure_ui_slice_3.lua',1],['sapphire_treasure_ui_slice_4.lua',1],
  ['sapphire_treasure_ui_slice_5.lua',1],['sapphire_treasure_ui_slice_6.lua',1],['sapphire_treasure_ui_slice_7.lua',3]]) {
  test(`generated NodeUI full command parity and interrupted-input isolation: ${file}`,()=>{
    const result=runLua(`tests/lua/${file}`);
    assert.equal(result.status,0,result.stderr||result.stdout);
    assert.match(result.stdout,new RegExp(`SAPPHIRE_TREASURE_UI_PASS ${groups}`));
  });
}
