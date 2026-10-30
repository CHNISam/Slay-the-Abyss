import {preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import test from 'node:test';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
import {discoverJs,jsShard,timings} from '../scripts/ci-shards.mjs';
import {qualityShardMatrices} from '../scripts/ci-quality-shape.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=source=>createHash('sha256').update(source).digest('hex');
const manifest=JSON.parse(read('tests/fixtures/ui-regression-partitions.json'));
const originals=[
 ['potion_targeting',5,4,'POTION_TARGETING','3dcadb807b990be2621b12ff85677749cf63b5ffcf06fa6a38bd6ff6c14d7fcc','5605f22c901f7636b023ed90fd343053e1c7fc47'],
 ['game_ui_exit',15,5,'GAME_UI_EXIT','986c6a694f51d13dccf121ccba1a93fbb9e9d84f3f30bf7d0ae11d7360fdbf2d','f986addd094b95e234464e7bb48401d305e1515b'],
 ['feedback_continuous_cards',9,4,'FEEDBACK_CONTINUOUS_CARDS','d71e04f8b4a0736dbd90a32b57d7aeede3b5b418f58d3f96604b02fccf1902ee','01da8333a744bcee14c8e7574b2056f99b5b1b39'],
 ['battle_ui_potion_target_failures',7,3,'BATTLE_UI_POTION_TARGET_FAILURES','47565faaad06cbf34edf208a30d922ab4975b19a5025dc751c379ff6ed2d83a9','5faa5cf608f248ba5c5e8c613470709d1810691b'],
];
const acceptedRegistrationEdits=new Map([
 ['tests/lua/battle_ui_potion_target_failures.lua',['bd4e739a3105c488a44b4a2b564b0198862c942fc1167e28e6aa912f501fc24d','563d5256883692e4f011eb7cac3a5dd014d99988d029ff4877f3496c62a1410d']],
 ['tests/lua/potion_targeting.lua',['f80c0e4f9456d37877b0e17c2228e33e4b7898ab9df652157d113e8816bed8b0','0edf396cffb9a7c7f3111c26d18bf09897683c7e479314bbbe61e28f31caa038']],
 ['tests/lua/game_ui_exit.lua',['dd5f7db76b2630928828b148e61876aedf980928a6e6c914b00bad29d038c3b3','dd99a76ad8d4f825a49ccbf3a825885f0a140bafba6883d27eea2fdc8ccf584b']],
 ['tests/lua/feedback_continuous_cards.lua',['215f0c976bdc7c2fd4651027991306fbc8e7e62963ef8ee25d436cadffac129a','2b1095082ab321592c89a8b30983412b95ed50f0ee3233b87836ef2a8afedeeb']],
]);
function originalSource(part,source){
 assert.deepEqual([sha(part.before),sha(part.after)],acceptedRegistrationEdits.get(part.entry),'accepted registration edit must keep real execution, gating, counters, and markers unchanged');
 assert.ok(source.startsWith(part.prefix),'the primary raw fixture must select its exact original case range');
 assert.ok(source.endsWith(part.footer),'every selected original case must execute');
 source=source.slice(part.prefix.length,-part.footer.length);
 assert.equal(source.split(part.after).length,2,'the sole registration edit must have one exact inverse');
 source=source.replace(part.after,part.before);
 assert.equal(sha(source),part.originalSha256LF,'all original setup, cases, assertions, seeds, and statement order must survive');
 const bytes=Buffer.from(source);
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),part.originalGitBlob);
 return source;
}
historicalTest('UI regression partitions keep the actual merged base and every runner deadline unchanged',()=>{
 assert.equal(manifest.base,'cec690c1701af121e370facde5c1ca2ad9beb99e');
 assert.equal(manifest.timeoutMilliseconds,30000);
 assert.equal(manifest.runnerSha256LF,'7866bfbb9888417087a669dd20f524de32ccb1efe1d035a283fc1b148d26ed33');
 assert.equal(sha(preAcceptedPr323Source('scripts/test-lua.mjs',read('scripts/test-lua.mjs'))),manifest.runnerSha256LF);
 assert.equal(manifest.partitions.length,originals.length);
});
for(const [index,[name,total,last,label,sourceSha,blob]]of originals.entries()){
 historicalTest(`${name} partitions restore every original byte and reject source or range drift`,()=>{
  const part=manifest.partitions[index],entry=`tests/lua/${name}.lua`;
  assert.equal(part.entry,entry);assert.equal(part.total,total);assert.equal(part.label,label);
  assert.equal(part.originalSha256LF,sourceSha);assert.equal(part.originalGitBlob,blob);
  assert.equal(part.prefix,`local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or ${last}\nlocal sliceRegistered,sliceExecuted=0,0\n`);
  assert.equal(part.footer,`\nassert(sliceRegistered==${total},"all ${total} original cases must register")\nassert(sliceExecuted==sliceLast-sliceFirst+1,"every selected original case must execute")\nprint("${label}_SLICE "..sliceFirst.." "..sliceLast.." "..sliceExecuted)\n`);
  assert.deepEqual(part.slices,[{path:entry,first:1,last},{path:`tests/lua/${name}_slice_2.lua`,first:last+1,last:total}]);
  const source=read(entry),original=originalSource(part,source);
  assert.equal(read(part.slices[1].path),`assert(loadfile("${entry}"))(${last+1},${total})\n`);
  assert.deepEqual(part.slices.flatMap(({first,last})=>Array.from({length:last-first+1},(_,i)=>first+i)),Array.from({length:total},(_,i)=>i+1));
  assert.throws(()=>originalSource(part,source.replace(part.prefix,part.prefix.replace(`sliceLast or ${last}`,`sliceLast or ${last+1}`))),/exact original case range/);
  const caseAt=original.indexOf('\ntest(');assert.ok(caseAt>=0);
  const drift=original.slice(0,caseAt)+original.slice(caseAt).replace('assert(', 'assert( ');
  assert.notEqual(drift,original,'the negative probe must change an actual original case body');
  assert.throws(()=>originalSource(part,part.prefix+drift.replace(part.before,part.after)+part.footer),/all original setup/);
  const noCall=part.after.includes('originalTest(name,fn);')?part.after.replace('originalTest(name,fn);',''):part.after.includes('fn();')?part.after.replace('fn();',''):part.after.replace('    tests = tests + 1\n','    tests = tests + 1\n    if true then return end\n');
  assert.notEqual(noCall,part.after,'the negative probe must stop executing the selected case');
  assert.throws(()=>originalSource({...part,after:noCall},source.replace(part.after,noCall)),/accepted registration edit/,'changing both wrapper and manifest must not allow counting without execution');
 });
}
test('raw runner, Node discovery, and every hosted shard plan retain all eight UI slices exactly once',()=>{
 const raw=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
 const expected=manifest.partitions.flatMap(part=>part.slices.map(slice=>slice.path));
 const names=originals.map(([name])=>name).join('|');
 assert.deepEqual(raw.filter(path=>new RegExp(`^tests/lua/(?:${names})(?:_slice_\\d+)?\\.lua$`).test(path)).sort(),[...expected].sort());
 assert.match(read('scripts/test-lua.mjs'),/readdirSync\('tests\/lua'\)/);
 assert.match(read('scripts/test-lua.mjs'),/filter\(file => file\.endsWith\('\.lua'\)\)/);
 for(const workers of [1,2]){
  const count=qualityShardMatrices.windows.length;
  const actual=Array.from({length:count},(_,i)=>shardLuaScripts(raw,`${i+1}/${count}`,timings,workers)).flat().filter(path=>expected.includes(path));
  assert.deepEqual(actual.sort(),[...expected].sort(),`all raw CI shards retain each slice exactly once with ${workers} worker(s)`);
 }
 const contract='tests/ui-regression-partitions.test.mjs',js=discoverJs();
 assert.equal(js.filter(path=>path===contract).length,1);
 assert.match(JSON.parse(read('package.json')).scripts.test,/node --test --test-concurrency=1 tests\/\*\.test\.mjs/);
 for(const [platform,count]of [['win32',qualityShardMatrices.windows.length],['linux',qualityShardMatrices.posix.length]]){
  const actual=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files).flat();
  assert.equal(actual.filter(path=>path===contract).length,1,`${platform} hosted JS plans execute this source-preservation contract exactly once`);
 }
});
