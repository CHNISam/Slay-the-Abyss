import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';

const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const partition=JSON.parse(read('tests/fixtures/p0-card-play-partition.json'));
const originalHash='3f07a7f2fd72f35feac148261039616e7f43a1bb4bc5e04f11b4167f321fde0d';
function verifyDiscovery(files){
 const discovered=files.filter(name=>name.startsWith('battle_ui_card_play')&&name.endsWith('.lua')).sort();
 assert.deepEqual(discovered,partition.slices.map(row=>row.file).sort(),'exact card-play raw discovery');
}
function restore(source){
 assert(source.startsWith(partition.header));
 assert(source.endsWith(partition.footer));
 let original=source.slice(partition.header.length,-partition.footer.length);
 assert.equal(original.split(partition.registration).length,2,'one registration selector');
 original=original.replace(partition.registration,'');
 assert.equal(hash(original),originalHash,'complete original card-play body');
 return original;
}

test('card-play partitions retain the complete original eleven cases and unchanged per-entry deadline',()=>{
 assert.equal(partition.base,'bcca9de518a628e9558db893888cb6b780833df3');
 assert.equal(partition.entry,'tests/lua/battle_ui_card_play.lua');
 assert.equal(partition.originalSha256LF,originalHash);
 assert.equal(partition.total,11);
 assert.equal(partition.timeoutMilliseconds,30000);
 const source=read(partition.entry);
 assert.equal(hash(source),partition.currentSha256LF);
 const original=restore(source);
 assert.equal((original.match(/^test\("/gm)??[]).length,11);
 assert(source.includes("assert(registered==11 and executed==sliceLast-sliceFirst+1 and passed==executed,'incomplete card-play slice')"));
 assert.deepEqual(partition.slices.map(row=>[row.first,row.last]),[[1,4],[5,8],[9,11]]);
 const seen=[];
 for(const [index,row]of partition.slices.entries()){
  if(index===0)assert(source.includes(`sliceFirst,sliceLast=sliceFirst or ${row.first},sliceLast or ${row.last}`));
  else assert.equal(read('tests/lua/'+row.file),`assert(loadfile('${partition.entry}'))(${row.first},${row.last})\n`);
  for(let i=row.first;i<=row.last;i++)seen.push(i);
 }
 assert.deepEqual(seen,Array.from({length:11},(_,i)=>i+1));
 verifyDiscovery(readdirSync('tests/lua'));
});

test('card-play original-body guard rejects assertion loss and duplicate selectors',()=>{
 const source=read(partition.entry);
 assert.throws(()=>restore(source.replace('assert(ui.selected==nil and host.run.combat.energy==3 and host.run.combat.player.block==0)','assert(true)')),/complete original/);
 assert.throws(()=>restore(source.replace(partition.registration,partition.registration+partition.registration)),/one registration/);
});

test('card-play raw discovery rejects missing slices and additional family entries',()=>{
 const files=partition.slices.map(row=>row.file);
 assert.throws(()=>verifyDiscovery(files.slice(0,-1)),/exact card-play raw discovery/);
 assert.throws(()=>verifyDiscovery([...files,'battle_ui_card_play_slice_4.lua']),/exact card-play raw discovery/);
});
