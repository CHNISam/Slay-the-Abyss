import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=text=>createHash('sha256').update(text).digest('hex');
const lock=JSON.parse(read('tests/fixtures/sapphire-modern-partition.json'));
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
 assert.equal(hash(read(lock.uiHelper)),lock.uiHelperSha256);
 const groups=[];
 for(const [index,[first,last]]of lock.uiSlices.entries()){
  const path=index?`tests/lua/sapphire_treasure_ui_slice_${index+1}.lua`:'tests/lua/sapphire_treasure_ui.lua';
  assert(read(path).includes(`dofile("${lock.uiHelper}")(${first},${last})\n`));
  for(let n=first;n<=last;n++)groups.push(n);
 }
 assert.deepEqual(groups,Array.from({length:17},(_,i)=>i+1));
});
