import test from 'node:test';
import assert from 'node:assert/strict';
import { nodeLayout } from '../scripts/node-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('Act2 events reuse the unchanged event rows, picker, confirm and back controls',()=>{
  const root=nodeLayout().controls[0], event=root.children.find(c=>c.name==='eventView');
  assert.deepEqual(event.children.filter(c=>/^option\d+$/.test(c.name)).map(c=>c.name),
    ['option1','option2','option3','option4']);
  assert.ok(root.children.some(c=>c.name==='pickerView'));
  assert.ok(root.children.some(c=>c.name==='confirm'));
  assert.ok(root.children.some(c=>c.name==='back'));
});
for(const [file,count] of [['act2_event_ui.lua',8],['act2_event_ui_hooks.lua',6],
  ['act2_event_ui_gestures.lua',8],['act2_event_ui_exchanges.lua',6]]){
  test(`mock-local generated NodeUI plus real Nodes/Run: ${file}`,()=>{
    const result=runLua(`tests/fixtures/js-owned/tests/lua/${file}`);
    assert.equal(result.status,0,result.stdout+result.stderr);
    assert.match(result.stdout,new RegExp(`ACT2_EVENT_UI_PASS ${count}`));
  });
}
