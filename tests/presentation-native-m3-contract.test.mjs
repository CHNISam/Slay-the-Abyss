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
const themeReviewBytes=readFileSync('docs/reviews/PRESENTATION-THEME-RESERVES-20261028.json');
assert.equal(digest(themeReviewBytes),'a1bd533e3f023eae92f66ce502699643e55b2b8df0824392b061a781061f8e64');
const themeReview=JSON.parse(themeReviewBytes);
function projectReviewedTheme(source){
 const normalized=source.replaceAll('\r\n','\n');
 const {insertionOffset:at,insertedLf,precedingAnchor}=themeReview;
 assert.equal(normalized.slice(at-precedingAnchor.length,at),precedingAnchor,'exact relic mapping insertion position');
 assert.equal(normalized.slice(at,at+insertedLf.length),insertedLf,'only the two complete reviewed mappings');
 const projected=normalized.slice(0,at)+normalized.slice(at+insertedLf.length);
 assert.equal(digest(projected),themeReview.projectedLfSha256,'all original theme bytes and order retained');
 assert.equal(digest(normalized),themeReview.currentLfSha256,'exact reviewed complete current theme');
 return projected;
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
 verifySources(Object.fromEntries(Object.keys(review.sourceInputs).map(path=>{
  const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  return [path,digest(path===themeReview.path?projectReviewedTheme(source):source)];
 })));
 const fixture=readFileSync('tests/lua/presentation_responsibilities_trace.lua','utf8');
 assert.match(fixture,/trace:assertNativeInteraction\(\)/);
 assert.match(fixture,/assert\(trace.count==77278 and trace.hash==1948853637/);
});

test('only exact Black Star and Tail placeholder additions reversibly project to the historical theme',()=>{
 assert.equal(themeReview.sourceHead,'af25ca0887529ea0549363c394ba54fc55ad91f1');
 assert.equal(themeReview.historicalCaptureHead,'c5e768807081d1c62750174998367f1565274ee5');
 assert.equal(themeReview.path,'data/presentation/ui_theme.json');
 assert.equal(themeReview.currentLfSha256,'4648ea4c56bdd6dac75fe363480e9b72e64976b84242fb41efdc10a092b99743');
 assert.equal(themeReview.projectedLfSha256,review.sourceInputs[themeReview.path]);
 const additions=JSON.parse('{'+themeReview.insertedLf.trim().slice(0,-1)+'}');
 assert.deepEqual(additions,{
  black_star:{id:102028,placeholder:true,note:'黑星暂沿用批准主题现有宝箱图标；专属美术与设备验收待完成。'},
  lizard_tail:{id:102028,placeholder:true,note:'蜥蜴尾巴暂沿用批准主题现有宝箱图标；实际剩余次数由只读详情展示，专属美术与设备验收待完成。'},
 });
 const source=readFileSync(themeReview.path,'utf8').replaceAll('\r\n','\n');
 const projected=projectReviewedTheme(source);
 assert.equal(digest(projected),review.sourceInputs[themeReview.path]);
 assert.equal(projectReviewedTheme(source.replaceAll('\n','\r\n')),projected,'Windows normalization is CRLF to LF only');
 const {insertionOffset:at,insertedLf}=themeReview;
 const blocks=insertedLf.match(/      "(?:black_star|lizard_tail)": \{\n[\s\S]*?      \},\n/g);
 assert.equal(blocks.length,2);
 const mutations={
  deletedBlackStar:source.replace(blocks[0],''),
  deletedTail:source.replace(blocks[1],''),
  changedIcon:source.replace(insertedLf,insertedLf.replace('"id": 102028','"id": 102029')),
  changedPlaceholder:source.replace(insertedLf,insertedLf.replace('"placeholder": true','"placeholder": false')),
  changedNote:source.replace(additions.lizard_tail.note,'未审查说明'),
  changedOriginalField:source.replace('"membership_card": 102026','"membership_card": 102027'),
  thirdMapping:source.slice(0,at+insertedLf.length)+'      "unreviewed_relic": 102028,\n'+source.slice(at+insertedLf.length),
  movedMappings:projected.replace('      "membership_card": 102026,\n','      "membership_card": 102026,\n'+insertedLf),
  reorderedMappings:source.replace(insertedLf,blocks[1]+blocks[0]),
 };
 for(const [name,mutation]of Object.entries(mutations)){
  assert.notEqual(mutation,source,name+' must really mutate the current input');
  assert.throws(()=>projectReviewedTheme(mutation),undefined,name);
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
