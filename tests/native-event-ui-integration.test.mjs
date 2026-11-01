import test from 'node:test';
import assert from 'node:assert/strict';
import {nodeLayout} from '../scripts/node-ui-layout.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const find=(item,name)=>item.name===name?item:(item.children||item.controls||[]).map(child=>find(child,name)).find(Boolean);
test('production node layout registers reused Match faces and its sole new input',()=>{
  const picker=find(nodeLayout(),'pickerView');
  assert.ok(find(picker,'matchRetry'),'production picker must register Match retry');
  const grid=find(picker,'forgeGrid');assert.equal(grid.children.length,12);
  for(const cell of grid.children){
    assert.ok(find(cell,'matchBack'),'production face must have a concealment overlay');
    assert.equal(cell.children.filter(child=>child.kind==='cursorArea').length,1);
  }
});
for(const fixture of ['duplicator_event_integration','match_event_integration'])test(`production native event ${fixture}`,()=>{
  const result=runLua(`tests/lua/${fixture}.lua`);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/ACT2_EVENT_UI_PASS|MATCH_EVENT_INTEGRATION_PASS/);
});
