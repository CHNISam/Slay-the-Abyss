import {preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
import {discoverJs,jsShard,timings} from '../scripts/ci-shards.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=source=>createHash('sha256').update(source).digest('hex');
const partitions=JSON.parse(read('tests/fixtures/game-ui-class-choices-partitions.json'));

function verifyOriginal(source){
 assert.ok(source.startsWith(partitions.prefix),'the primary raw fixture selects original cases 1 through 5');
 assert.ok(source.endsWith(partitions.footer));
 let original=source.slice(partitions.prefix.length,-partitions.footer.length);
 assert.equal(original.split(partitions.after).length,2,'the sole registration edit has one exact inverse');
 original=original.replace(partitions.after,partitions.before);
 assert.equal(sha(original),partitions.originalSha256LF,'all original setup, cases, assertions, seeds, and statement order are preserved');
 const bytes=Buffer.from(original);
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),partitions.originalGitBlob);
}

test('class choice raw partitions restore every byte of the original ten registered cases and the unchanged deadline',()=>{
 assert.equal(partitions.base,'7a4910b56cb35e5221faf4523410a9100085c4ea');
 assert.equal(partitions.entry,'tests/lua/game_ui_class_choices.lua');
 assert.equal(partitions.originalSha256LF,'69060f92fe3cc24e7ace32c835621acae9874ee05390019ec78c72c6de69b04b');
 assert.equal(partitions.originalGitBlob,'295f6132b4a1167aac584dddda487340358f00f7');
 assert.equal(partitions.total,10);assert.equal(partitions.timeoutMilliseconds,30000);
 assert.equal(partitions.runnerSha256LF,'7866bfbb9888417087a669dd20f524de32ccb1efe1d035a283fc1b148d26ed33');
 assert.equal(sha(preAcceptedPr323Source('scripts/test-lua.mjs',read('scripts/test-lua.mjs'))),partitions.runnerSha256LF,'the original runner and all fixture deadline rules remain unchanged');
 assert.equal(partitions.prefix,'local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 5\nlocal sliceRegistered=0\n');
 assert.equal(partitions.before,'local function test(name,fn) fn();n=n+1;print("ok game_ui_class_choices "..n.." - "..name) end\n');
 assert.equal(partitions.after,'local function test(name,fn)\n    sliceRegistered=sliceRegistered+1\n    if sliceRegistered>=sliceFirst and sliceRegistered<=sliceLast then\n        fn();n=n+1;print("ok game_ui_class_choices "..n.." - "..name)\n        print("GAME_UI_CLASS_CHOICES_CASE "..sliceRegistered)\n    end\nend\n');
 assert.equal(partitions.footer,'\nassert(sliceRegistered==10,"all ten original class choice cases must register")\nassert(n==sliceLast-sliceFirst+1,"every selected original class choice case must execute")\nprint("GAME_UI_CLASS_CHOICES_SLICE "..sliceFirst.." "..sliceLast.." "..n)\n');
 assert.deepEqual(partitions.slices,[{path:partitions.entry,first:1,last:5},{path:'tests/lua/game_ui_class_choices_slice_2.lua',first:6,last:10}]);
 verifyOriginal(read(partitions.entry));
 assert.equal(read(partitions.slices[1].path),`assert(loadfile("${partitions.entry}"))(6,10)\n`);
 const covered=partitions.slices.flatMap(part=>Array.from({length:part.last-part.first+1},(_,i)=>part.first+i));
 assert.deepEqual(covered,Array.from({length:10},(_,i)=>i+1),'all ten original registrations run exactly once');
});

test('negative controls reject changed original cases and any family discovery drift',()=>{
 const source=read(partitions.entry);
 for(const [before,after]of [
  ['eq(s.pendingDiscard,nil)','eq(nil,nil)'],
  ['for i=1,12 do','for i=1,11 do'],
  ['{"select","exit"}','{"select"}'],
  [partitions.after,partitions.after+partitions.after],
 ]){
  const mutant=source.replace(before,after);
  assert.notEqual(mutant,source,'each negative control must change the real source');
  assert.throws(()=>verifyOriginal(mutant),'original-body or selector drift must fail');
 }
 const raw=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
 const sources=Object.fromEntries(partitions.slices.map(part=>[part.path,read(part.path)]));
 const verifyDiscovery=(parts,files,bodies)=>{
  assert.deepEqual(parts,partitions.slices,'only the accepted complete ranges');
  assert.deepEqual(files.filter(path=>path.startsWith('tests/lua/game_ui_class_choices')&&path.endsWith('.lua')).sort(),
   partitions.slices.map(part=>part.path),'every family-prefixed Lua entry must be accounted for');
  for(const part of parts.slice(1))
   assert.equal(bodies[part.path],`assert(loadfile("${partitions.entry}"))(${part.first},${part.last})\n`);
  assert.deepEqual(parts.flatMap(part=>Array.from({length:part.last-part.first+1},(_,i)=>part.first+i)),
   Array.from({length:partitions.total},(_,i)=>i+1));
 };
 verifyDiscovery(partitions.slices,raw,sources);
 assert.throws(()=>verifyDiscovery(partitions.slices.slice(0,1),raw,sources),'missing range must fail');
 for(const first of [5,7])
  assert.throws(()=>verifyDiscovery([partitions.slices[0],{...partitions.slices[1],first}],raw,sources),'overlap or gap must fail');
 assert.throws(()=>verifyDiscovery(partitions.slices,raw.filter(path=>path!==partitions.slices[1].path),sources),'missing raw entry must fail');
 for(const extra of ['tests/lua/game_ui_class_choices_slice_3.lua','tests/lua/game_ui_class_choices_disabled.lua'])
  assert.throws(()=>verifyDiscovery(partitions.slices,[...raw,extra],sources),'extra standard or nonstandard family entry must fail');
 const wrapper=partitions.slices[1].path;
 assert.throws(()=>verifyDiscovery(partitions.slices,raw,{...sources,[wrapper]:'-- '+sources[wrapper]}),'commented-out wrapper must fail');
});

test('raw runner, Node suite, and every hosted shard plan discover the two class choice slices exactly once',()=>{
 const raw=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
 const expected=partitions.slices.map(part=>part.path);
 assert.deepEqual(raw.filter(path=>/^tests\/lua\/game_ui_class_choices(?:_slice_\d+)?\.lua$/.test(path)).sort(),expected);
 assert.match(read('scripts/test-lua.mjs'),/readdirSync\('tests\/lua'\)/);
 assert.match(read('scripts/test-lua.mjs'),/filter\(file => file\.endsWith\('\.lua'\)\)/);
 for(const workers of [1,2]){
  const actual=Array.from({length:8},(_,i)=>shardLuaScripts(raw,`${i+1}/8`,timings,workers)).flat().filter(path=>expected.includes(path));
  assert.deepEqual(actual.sort(),expected,`all raw CI shards retain each slice exactly once with ${workers} worker(s)`);
 }
 const contract='tests/game-ui-class-choices-partitions.test.mjs',js=discoverJs();
 assert.equal(js.filter(path=>path===contract).length,1,'normal Node discovery includes this source-preservation contract');
 assert.match(JSON.parse(read('package.json')).scripts.test,/node --test --test-concurrency=1 tests\/\*\.test\.mjs/);
 for(const [platform,count]of [['win32',8],['linux',4]]){
  const actual=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files).flat();
  assert.equal(actual.filter(path=>path===contract).length,1,`${platform} hosted JS plans execute the source-preservation contract exactly once`);
 }
});
