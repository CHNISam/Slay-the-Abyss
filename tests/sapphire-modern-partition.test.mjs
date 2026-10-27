import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=text=>createHash('sha256').update(text).digest('hex');
const lock=JSON.parse(read('tests/fixtures/sapphire-modern-partition.json'));
function assertFrozenSapphireUI(source){
 // Restore exactly the reviewed mock-only edits; never normalize scenario bodies.
 const loader="local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')\n";
 assert(source.startsWith(loader));assert.equal(source.split(loader).length,2);
 let original=source.slice(loader.length);
 for(const [current,before]of[
  ['    function c:SetSizeDelta(width,height) NativeContract.sizeDelta(width,height);\n',
   "    function c:SetSizeDelta(width,height)\n        assert(type(width)=='number' and type(height)=='number' and width>=0 and height>=0 and width<math.huge and height<math.huge)\n"],
  ['    function c:AddCursorEventListener(event,fn) NativeContract.listener(event,fn);assert(not self.listeners[event]);self.listeners[event]=fn end\n',
   '    function c:AddCursorEventListener(event,fn)assert(not self.listeners[event]);self.listeners[event]=fn end\n'],
  ['\nreturn registered, control\nend\n','\nreturn registered\nend\n'],
 ]){
  assert.equal(original.split(current).length,2,'exact reviewed mock migration must occur once');
  original=original.replace(current,before);
 }
 assert.equal(hash(original),lock.uiHelperSha256,'frozen Sapphire UI body hash');
}
test('modern Sapphire keeps the complete migrated core body and all original 21 groups exactly once',()=>{
 assert.equal(lock.originalGroups,21);assert.equal(lock.timeout,30000);
 let body=read(lock.entry);assert(body.startsWith(lock.prefix)&&body.endsWith(lock.footer));
 body=body.slice(lock.prefix.length,-lock.footer.length);
 assert.equal(body.split(lock.after).length,2);body=body.replace(lock.after,lock.before);
 assert.equal(hash(body),lock.migratedBodySha256);
 const groups=[];
 for(const [index,[first,last]]of lock.slices.entries()){
  if(index)assert.equal(read(`tests/lua/sapphire_treasure_slice_${index+1}.lua`),`assert(loadfile('${lock.entry}'))(${first},${last})\n`);
  else assert(lock.prefix.includes(`sliceFirst or ${first},sliceLast or ${last}`));
  for(let n=first;n<=last;n++)groups.push(n);
 }
 assert.deepEqual(groups,Array.from({length:21},(_,i)=>i+1));
});
test('modern Sapphire UI keeps the complete 17-group body and every original interruption matrix',()=>{
 assertFrozenSapphireUI(read(lock.uiHelper));
 const groups=[];
 for(const [index,[first,last]]of lock.uiSlices.entries()){
  const path=index?`tests/lua/sapphire_treasure_ui_slice_${index+1}.lua`:'tests/lua/sapphire_treasure_ui.lua';
  assert(read(path).includes(`dofile("${lock.uiHelper}")(${first},${last})\n`));
  for(let n=first;n<=last;n++)groups.push(n);
 }
 assert.deepEqual(groups,Array.from({length:17},(_,i)=>i+1));
});
test('Sapphire frozen-body protection still rejects a deleted scenario or gameplay assertion',()=>{
 const source=read(lock.uiHelper);
 const first="test('standalone keeps exact closed/open states and legacy displayed reward action',function()\n";
 assert.equal(source.split(first).length,2);
 const start=source.indexOf(first),next=source.indexOf('\ntest(',start+first.length);
 assert(next>start);
 assert.throws(()=>assertFrozenSapphireUI(source.slice(0,start)+source.slice(next)),/frozen Sapphire UI body hash/);
 const assertion="    assert(get('notice').text=='小型宝箱就在眼前；可以打开或直接离开。')\n";
 assert.equal(source.split(assertion).length,2);
 assert.throws(()=>assertFrozenSapphireUI(source.replace(assertion,'')),/frozen Sapphire UI body hash/);
});
