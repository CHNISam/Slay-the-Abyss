import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runLua } from '../scripts/test-lua.mjs';
import { nodeLayout } from '../scripts/node-ui-layout.mjs';

test('actual generated NodeUI uses the existing last footer without adding camp controls',()=>{
  const root=nodeLayout().controls[0], camp=root.children.find(control=>control.name==='campView');
  assert.deepEqual(camp.children.map(control=>control.name),['medallion','rest','forge']);
  const footer=root.children.find(control=>control.name==='confirm');
  assert.ok(root.children.indexOf(footer)>root.children.indexOf(camp));
  for(const tile of camp.children.filter(control=>['rest','forge'].includes(control.name)))
    assert.ok(footer.position[1]+footer.size[1]/2<tile.position[1]-tile.size[1]/2);
  const source=readFileSync('src/lua/abyss_node_ui.lua','utf8');
  assert.match(source,/confirmLabel, confirmOk = "Recall", true/);
  assert.match(source,/commit\("recall", recallSource/);
});

test('real NodeUI pointer ownership and public Recall command preserve complete run/map/RNG parity',()=>{
  const result=runLua('tests/lua/ruby_recall_ui.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/RUBY_RECALL_UI_PASS 14/);
});
