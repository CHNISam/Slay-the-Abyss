import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
import {timings} from '../scripts/ci-shards.mjs';
import {preApprovedUiSource,preBoundedPotionFailuresSource} from './helpers/approved-ui-inverse.mjs';
import {assertMainPotionActionHelper} from './helpers/main-potion-fixture-inverse.mjs';

const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=source=>createHash('sha256').update(source).digest('hex');
const potionEntry='tests/lua/battle_ui_potion_target_failures.lua';
const potionBefore='local test,finish = H.suite("LUA_POTION_TARGET_FAILURES")\n';
const continuousBefore='local function test(name, fn)\n';
const continuousPrint='    print((ok and "ok" or "not ok") .. " feedback_continuous_cards " .. tests .. " - " .. name .. (ok and "" or ": " .. tostring(err)))\n';
const exitBefore='local function test(name, fn) fn(); count=count+1; print("ok exit UI "..count.." - "..name) end\n';
const families=[
 {
  entry:potionEntry,total:7,last:4,
  originalSha256:'47565faaad06cbf34edf208a30d922ab4975b19a5025dc751c379ff6ed2d83a9',
  originalBlob:'5faa5cf608f248ba5c5e8c613470709d1810691b',
  prefix:"local first,last=...\nfirst,last=first or 1,last or 4\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=7 and first<=last,'invalid potion failure slice')\nlocal registered,executed=0,0\n",
  edits:[[potionBefore,potionBefore+"local originalTest=test\ntest=function(name,fn)\n registered=registered+1\n if registered<first or registered>last then return end\n executed=executed+1\n originalTest(name,fn)\n print('POTION_TARGET_FAILURES_CASE '..registered)\nend\n"]],
  footer:"assert(registered==7,'all original potion failure cases must register')\nassert(executed==last-first+1,'all selected potion failure cases must execute')\nprint('POTION_TARGET_FAILURES_PART '..first..' '..last..' '..executed)\n",
  mutations:[['eq(ok,false)','eq(ok,true)'],['2147483647','2147483646'],["{'up','endDrag'}","{'up'}"]],
 },
 {
  entry:'tests/lua/feedback_continuous_cards.lua',total:9,last:5,
  originalSha256:'d71e04f8b4a0736dbd90a32b57d7aeede3b5b418f58d3f96604b02fccf1902ee',
  originalBlob:'01da8333a744bcee14c8e7574b2056f99b5b1b39',
  prefix:"local first,last=...\nfirst,last=first or 1,last or 5\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=9 and first<=last,'invalid continuous feedback slice')\nlocal registered=0\n",
  edits:[[continuousBefore,continuousBefore+'    registered = registered + 1\n    if registered < first or registered > last then return end\n'],
   [continuousPrint,continuousPrint+'    print("FEEDBACK_CONTINUOUS_CARDS_CASE " .. registered)\n']],
  footer:'assert(registered==9,"all original continuous feedback cases must register")\nassert(tests==last-first+1,"all selected continuous feedback cases must execute")\nprint("FEEDBACK_CONTINUOUS_CARDS_PART "..first.." "..last.." "..tests)\n',
  mutations:[['same(battle, committed)','same(battle, battle)'],['for _, fast in ipairs({false, true}) do','for _, fast in ipairs({false}) do'],['for _ = 1, 100 do','for _ = 1, 99 do'],['seed = 11','seed = 12']],
 },
 {
  entry:'tests/lua/potion_targeting.lua',total:5,last:4,
  // These accepted independent suites share the prefix, but are not slices.
  neighbours:['tests/lua/potion_targeting_commit.lua','tests/lua/potion_targeting_help.lua'],
  originalSha256:'3dcadb807b990be2621b12ff85677749cf63b5ffcf06fa6a38bd6ff6c14d7fcc',
  originalBlob:'5605f22c901f7636b023ed90fd343053e1c7fc47',
  prefix:"local first,last=...\nfirst,last=first or 1,last or 4\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=5 and first<=last,'invalid potion targeting slice')\nlocal registered,executed=0,0\n",
  edits:[["local test, finish = H.suite('LUA_POTION_TARGETING')\n","local test, finish = H.suite('LUA_POTION_TARGETING')\nlocal originalTest=test\ntest=function(name,fn)\n registered=registered+1\n if registered<first or registered>last then return end\n executed=executed+1\n originalTest(name,fn)\n print('POTION_TARGETING_CASE '..registered)\nend\n"]],
  footer:"assert(registered==5,'all original potion targeting cases must register')\nassert(executed==last-first+1,'all selected potion targeting cases must execute')\nprint('POTION_TARGETING_PART '..first..' '..last..' '..executed)\n",
  mutations:[['hp-13','hp-12'],['{false,true}','{false}'],["{'bash','defend'}","{'strike','defend'}"],
   ["{'turn','battle','deck','status','resize','inactive','inventory','phase','potionPanel'}","{'turn','battle','deck','status','resize','inactive','inventory','phase'}"]],
 },
 {
  entry:'tests/lua/game_ui_exit.lua',total:15,last:7,
  neighbours:['tests/lua/game_ui_exit_swipe.lua'],
  originalSha256:'986c6a694f51d13dccf121ccba1a93fbb9e9d84f3f30bf7d0ae11d7360fdbf2d',
  originalBlob:'f986addd094b95e234464e7bb48401d305e1515b',
  prefix:"local first,last=...\nfirst,last=first or 1,last or 7\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=15 and first<=last,'invalid exit UI slice')\nlocal registered=0\n",
  edits:[[exitBefore,'local function test(name, fn)\n    registered=registered+1\n    if registered<first or registered>last then return end\n    fn(); count=count+1; print("ok exit UI "..count.." - "..name)\n    print("GAME_UI_EXIT_CASE "..registered)\nend\n']],
  footer:'assert(registered==15,"all original exit UI cases must register")\nassert(count==last-first+1,"all selected exit UI cases must execute")\nprint("GAME_UI_EXIT_PART "..first.." "..last.." "..count)\n',
  mutations:[['same(before,ui.run)','same(before,before)'],['ui:update(30)','ui:update(0)'],['{"reopen","resize"}','{"reopen"}'],['for _=1,400 do','for _=1,399 do']],
 },
];
const parts=row=>[{path:row.entry,first:1,last:row.last},{path:row.entry.replace('.lua','_slice_2.lua'),first:row.last+1,last:row.total}];

function restore(row,source){
 assert.ok(source.startsWith(row.prefix),'exact reviewed default range');
 assert.ok(source.endsWith(row.footer),'registration and execution counts remain enforced');
 let original=source.slice(row.prefix.length,-row.footer.length);
 for(const [before,after]of row.edits){
  assert.equal(original.split(after).length,2,'one exact registration-only inverse');
  original=original.replace(after,before);
 }
 assert.equal(sha(original),row.originalSha256,'complete original body, assertions, setup, seeds, loops and failure behavior');
 const bytes=Buffer.from(original);
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),row.originalBlob);
 return original;
}
function validateDiscovery(row,rows,sources,raw){
 const expected=parts(row);
 assert.deepEqual(rows,expected,'only the two reviewed complete ranges');
 const prefix=row.entry.slice(0,-4);
 assert.deepEqual(raw.filter(path=>path.startsWith(prefix)&&path.endsWith('.lua')).sort(),
  [...expected.map(part=>part.path),...(row.neighbours??[])].sort());
 assert.equal(sources[expected[1].path],`assert(loadfile('${row.entry}'))(${row.last+1},${row.total})\n`,'exact executable tail wrapper');
 assert.deepEqual(rows.flatMap(part=>Array.from({length:part.last-part.first+1},(_,i)=>part.first+i)),
  Array.from({length:row.total},(_,i)=>i+1),'complete original identity union exactly once');
}

for(const row of families){
 test(`${row.entry}: exact original source, two raw ranges and hosted discovery`,()=>{
  restore(row,read(row.entry));
  const rows=parts(row),sources=Object.fromEntries(rows.map(part=>[part.path,read(part.path)]));
  const raw=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
  validateDiscovery(row,rows,sources,raw);
  for(const workers of [1,2]){
   const selected=Array.from({length:8},(_,i)=>shardLuaScripts(raw,`${i+1}/8`,timings,workers)).flat()
    .filter(path=>rows.some(part=>part.path===path)).sort();
   assert.deepEqual(selected,rows.map(part=>part.path),'each raw range is scheduled exactly once');
  }
 });
 test(`${row.entry}: negative controls reject body, selector, wrapper and coverage drift`,()=>{
  const source=read(row.entry);
  for(const [before,after]of [...row.mutations,[row.edits[0][1],row.edits[0][1]+row.edits[0][1]]]){
   const mutant=source.replace(before,after);assert.notEqual(mutant,source,'negative control changes actual source');
   assert.throws(()=>restore(row,mutant));
  }
  assert.throws(()=>restore(row,source.slice(0,-row.footer.length)));
  const rows=parts(row),sources=Object.fromEntries(rows.map(part=>[part.path,read(part.path)]));
  const raw=[...rows.map(part=>part.path),...(row.neighbours??[])];
  assert.throws(()=>validateDiscovery(row,rows.slice(0,1),sources,raw));
  for(const first of [row.last,row.last+2])
   assert.throws(()=>validateDiscovery(row,[rows[0],{...rows[1],first}],sources,raw));
  assert.throws(()=>validateDiscovery(row,rows,sources,raw.slice(0,1)));
  for(const suffix of ['_slice_3.lua','_disabled.lua'])
   assert.throws(()=>validateDiscovery(row,rows,sources,[...raw,row.entry.replace('.lua',suffix)]));
  assert.throws(()=>validateDiscovery(row,rows,sources,[...raw,raw[1]]));
  assert.throws(()=>validateDiscovery(row,rows,{...sources,[rows[1].path]:'-- '+sources[rows[1].path]},raw));
 });
}

test('fresh potion acquisition, explicit action helper, runner and worker policy remain unchanged',()=>{
 assertMainPotionActionHelper();
 const expected={
  'tests/lua/support/potion_targeting_fixture.lua':'ab0e566fc05e0a122759e5b46f17b332f15496760144934753a852cd6ba9ac1b',
  'tests/lua/support/potion_gesture_fixture.lua':'2b9d320d2c210c110c4b3a25510c7cd69bd32b0d9633e85e9e2a0354b057c671',
  'scripts/test-lua.mjs':'7866bfbb9888417087a669dd20f524de32ccb1efe1d035a283fc1b148d26ed33',
  'scripts/lua-workers.mjs':'699aa2e9e4c236c4be8fdc7b4a61f66877dbecf88d16b8ad0d488defee8d82a3',
 };
 const validate=(path,source)=>assert.equal(sha(source),expected[path]);
 for(const path of Object.keys(expected))validate(path,read(path));
 const helper='tests/lua/support/potion_targeting_fixture.lua',source=read(helper),mutant=source.replace('Run.new(F.Data,61)','Run.new(F.Data,62)');
 assert.notEqual(mutant,source);assert.throws(()=>validate(helper,mutant));
 const runner='scripts/test-lua.mjs',budget=read(runner),longer=budget.replace('60000 : 30000','60000 : 60000');
 assert.notEqual(longer,budget);assert.throws(()=>validate(runner,longer));
});

test('the potion registration seam composes before the unchanged frozen approved UI witness',()=>{
 const row=families[0],source=read(row.entry),original=restore(row,source);
 assert.equal(preBoundedPotionFailuresSource('tests/lua/unrelated.lua',source),source,'the inverse is bound to one exact path');
 assert.equal(preBoundedPotionFailuresSource(row.entry,source),original);
 assert.equal(preApprovedUiSource(row.entry,source),preApprovedUiSource(row.entry,original));
 assert.equal(preApprovedUiSource(row.entry,source.replaceAll('\n','\r\n')),preApprovedUiSource(row.entry,original));
 const changed=source.replace('eq(ok,false)','eq(ok,true)');assert.notEqual(changed,source);
 assert.throws(()=>preApprovedUiSource(row.entry,changed));
});
