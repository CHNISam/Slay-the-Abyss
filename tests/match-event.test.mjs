import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {randomUUID} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua,luaString} from '../scripts/build-lua-data.mjs';
import {matchVectors} from './helpers/match-event-oracle.mjs';
import {augmentMatchEventPicker} from '../scripts/match-event-layout.mjs';
import {nodeLayout} from '../scripts/node-ui-layout.mjs';
function plainPicker(){
  const find=item=>item.name==='pickerView'?item:(item.children||item.controls||[]).map(find).find(Boolean);
  const picker=find(nodeLayout());picker.children=picker.children.filter(c=>c.name!=='matchRetry');
  for(const cell of picker.children.find(c=>c.name==='forgeGrid').children)cell.children=cell.children.filter(c=>c.name!=='matchBack');
  return picker;
}
function pickerLayout(){return augmentMatchEventPicker(plainPicker());}
test('Match reuses all twelve original faces/hits and adds exactly57 non-renderer controls',()=>{
  const count=item=>1+(item.children||[]).reduce((n,c)=>n+count(c),0);
  const picker=plainPicker(),before=count(picker),grid=picker.children.find(c=>c.name==='forgeGrid');
  const original=structuredClone(grid);augmentMatchEventPicker(picker);
  assert.equal(count(picker)-before,57);
  for(const [i,cell]of grid.children.entries()){
    assert.deepEqual({...cell,children:cell.children.filter(c=>c.name!=='matchBack')},original.children[i]);
    assert.equal(cell.children.filter(c=>c.kind==='cursorArea').length,1);
    assert.ok(cell.children.length<64);
  }
  assert.ok(picker.children.length<64);
});

test('four independent source-pool/Java-shuffle vectors regenerate byte-for-byte',()=>{
  assert.equal(readFileSync('tests/fixtures/match-event-vectors.lua','utf8'),
    '-- Independent BigInt oracle; see tests/helpers/match-event-oracle.mjs\nreturn '+toLua(matchVectors())+'\n');
});

test('Match production leaf exists separately from the supplied-board candidate',()=>{
  assert.ok(existsSync('src/lua/abyss_match_event.lua'),'production Match leaf is missing');
  const body=readFileSync('src/lua/abyss_match_event.lua','utf8');
  assert.doesNotMatch(body,/tools\/candidates|math\.random/);
});
for(const file of ['match_event_sampling','match_event_commands','match_event_ui']){
  test(`Match production regression ${file}`,()=>{
    const temporary=file==='match_event_ui'?join(tmpdir(),`match-native-${randomUUID()}.lua`):null;
    if(temporary)writeFileSync(temporary,`ABYSS_MATCH_LAYOUT=${toLua(pickerLayout())}\ndofile(${luaString(`tests/lua/${file}.lua`)})\n`);
    let result;try{result=runLua(temporary||`tests/lua/${file}.lua`);}finally{if(temporary)unlinkSync(temporary);}
    assert.equal(result.status,0,result.stdout+result.stderr);
    assert.match(result.stdout,/MATCH_EVENT_.*_PASS/);
  });
}
