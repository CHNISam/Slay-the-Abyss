import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';

const directory='docs/reviews/presentation-native-m3-20261028';
const digest=value=>createHash('sha256').update(value).digest('hex');
const manifestBytes=readFileSync(`${directory}/review.json`);
assert.equal(digest(manifestBytes),'889ee9c585b2661569e2161cc836c4f431d1c41105e8eccfc821f584dc7ccbde');
const review=JSON.parse(manifestBytes);
// Accepted PR261 (develop77262) adds an opt-in platform binding and a strict
// helper. The ordinary77278-record capture is exactly unchanged. Keep the
// historical c5 manifest/archives immutable and invert only these two reviewed
// hunks after checking the complete current source identity, never a wildcard.
const acceptedNativeArt={
 'src/lua/abyss_battle_ui.lua':{
  sha256:'91d0cce1a3c6ef5a437175209f3fd2b086111de3f57f4756f15840e01412ee94',
  before:'        child = child, show = show, ink = ink, tint = tint, picture = picture,\n',
  after:'        child = child, show = show, ink = ink, tint = tint, picture = picture, platform = platform,\n',
 },
 'tests/lua/support/native_ui_contract.lua':{
  sha256:'7828c10e6e90f5e3da7ddb393d17d05b393159ce7e7f20f3b55cad0385dbd0a1',
  before:'',after:'function M.transform3(x,y,z)\n    M.sizeDelta(x,y);M.sizeDelta(z,0)\nend\n',
 },
};
function historicalSourceHash(path,source){
 let text=source.replaceAll('\r\n','\n');
 const binding=acceptedNativeArt[path];
 if(!binding)return digest(text);
 if(path==='src/lua/abyss_battle_ui.lua'){
  assert.equal(digest(text),'10fbc5766c9792e0b34017cfa5351587e037eedb44b4cb7cf4a86b5e12dfd508','complete accepted PR261 source identity plus reviewed drag cancellation must match');
  const edits=[
   ['                self.gesture, self.selected = nil, nil','                self.gesture, self.selected, self.hover, self.handHover = nil, nil, nil, nil'],
   ['            self.carry,self.selected = nil,nil','            self.carry,self.selected,self.hover,self.handHover = nil,nil,nil,nil'],
   ['', '        g.handCancelY = L.hand.y + Theme.motion.hoverLift\n        self.hover, self.handHover = nil, nil\n'],
  ];
  for(const [before,after] of edits){
   assert.equal(text.split(after).length,2,'exactly one reviewed drag cancellation edit');
   text=text.replace(after,before);
  }
 }
 assert.equal(digest(text),binding.sha256,'complete accepted PR261 source identity must match');
 assert.equal(text.split(binding.after).length,2,'exactly one reviewed native-art compatibility hunk');
 const original=text.replace(binding.after,binding.before);
 assert.equal(digest(original),review.sourceInputs[path],'exact inverse must recover historical source identity');
 return digest(original);
}
function capture(name){
 const bytes=readFileSync(`${directory}/${name}.json.gz`);
 assert.equal(digest(bytes),review[name].archiveSha256);
 return JSON.parse(gunzipSync(bytes));
}
const baseline=capture('baseline'),current=capture('current');
function hash(entries){
 let value=0;
 for(const entry of entries)for(const byte of Buffer.from(entry+'\n'))value=(value*131+byte)%2147483647;
 return value;
}
function additions(before,after){
 let preserved=0;const result=[];
 for(let index=0;index<after.length;index++){
  if(after[index]===before[preserved])preserved++;
  else result.push({currentIndex:index,afterBaseline:preserved,row:after[index]});
 }
 assert.equal(preserved,before.length,'every old write and its order must remain');
 return result;
}
function verify(before,after){
 assert.equal(before.length,72915);assert.equal(hash(before),148113441);
 assert.equal(after.length,77278);assert.equal(hash(after),1948853637);
 const delta=additions(before,after);
 assert.equal(delta.length,4363);
 assert.equal(digest(JSON.stringify(delta)),review.insertionsSha256,'exact insertion positions and values');
 const remaining=new Map(review.writes.map(row=>[row.row,row.count]));
 for(const item of delta){
  assert.ok(remaining.has(item.row),'unreviewed insertion');
  remaining.set(item.row,remaining.get(item.row)-1);
 }
 for(const count of remaining.values())assert.equal(count,0,'every reviewed write has its exact multiplicity');
 return delta;
}
function verifySources(hashes){
 assert.deepEqual(hashes,review.sourceInputs,'the directly reviewed source, fixtures and strict recorder must retain their identity');
}
test('paired e0/c5 captures retain all 72915 original native writes and exactly 4363 reviewed additions',()=>{
 assert.equal(baseline.head,'e0fad45c74ed574bc4cfb8a4c9ad71424a13c386');
 assert.equal(current.head,'c5e768807081d1c62750174998367f1565274ee5');
 assert.equal(baseline.originalScenarioPassed,true);assert.equal(current.originalScenarioPassed,false);
 assert.match(current.originalFailure,/ordered native writes changed from the frozen contract/);
 const delta=verify(baseline.entries,current.entries);
 const counts={};for(const item of delta){const entry=review.writes.find(row=>row.row===item.row);counts[entry.category]=(counts[entry.category]||0)+1;}
 assert.deepEqual(counts,review.categories);
 verifySources(Object.fromEntries(Object.keys(review.sourceInputs).map(path=>[path,historicalSourceHash(path,readFileSync(path,'utf8'))])));
 const fixture=readFileSync('tests/lua/presentation_responsibilities_trace.lua','utf8');
 assert.match(fixture,/trace:assertNativeInteraction\(\)/);
 assert.match(fixture,/assert\(trace.count==77278 and trace.hash==1948853637/);
});
test('accepted native-art compatibility permits only its two complete identities and exact historical inverses',()=>{
 assert.deepEqual(Object.keys(acceptedNativeArt),['src/lua/abyss_battle_ui.lua','tests/lua/support/native_ui_contract.lua']);
 for(const [path,binding]of Object.entries(acceptedNativeArt)){
  const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(historicalSourceHash(path,source),review.sourceInputs[path]);
  assert.equal(historicalSourceHash(path,source.replaceAll('\n','\r\n')),review.sourceInputs[path]);
  assert.throws(()=>historicalSourceHash(path,source+'\n-- unreviewed source drift\n'),/complete accepted PR261 source identity/);
  assert.throws(()=>historicalSourceHash(path,source.replace(binding.after,binding.before)),/complete accepted PR261 source identity/,'accepted binding/helper cannot be silently removed');
  assert.throws(()=>historicalSourceHash(path,source.replace(binding.after,binding.after+binding.after)),/complete accepted PR261 source identity/,'duplicate compatibility edits cannot be hidden');
 }
});
test('native trace proof rejects deleted changed reordered old writes and unreviewed additions',()=>{
 const original=current.entries;
 const removed=original.slice(1);assert.throws(()=>verify(baseline.entries,removed));
 const changed=[...original];changed[0]+=' UNREVIEWED';assert.throws(()=>verify(baseline.entries,changed));
 const reordered=[...original];[reordered[0],reordered[1]]=[reordered[1],reordered[0]];
 assert.notEqual(original[0],original[1]);assert.throws(()=>verify(baseline.entries,reordered));
 assert.throws(()=>verify(baseline.entries,[...original,'unreviewed insertion']));
 const inserted=additions(baseline.entries,original);const swapped=[...original];
 const first=inserted.findIndex((item,index)=>index>0&&item.row!==inserted[0].row);
 [swapped[inserted[0].currentIndex],swapped[inserted[first].currentIndex]]=[swapped[inserted[first].currentIndex],swapped[inserted[0].currentIndex]];
 assert.throws(()=>verify(baseline.entries,swapped),'reviewed values cannot move to unreviewed positions');
 const source={...review.sourceInputs};source['tests/lua/support/presentation_trace.lua']='unreviewed recorder';
 assert.throws(()=>verifySources(source));
});
