import test from 'node:test';
import {originalLuaRunner} from './helpers/ci-lua-runner-inverse.mjs';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=source=>createHash('sha256').update(source).digest('hex');
const entry='tests/lua/encounter_coverage.lua';
// Exact public PR265 head that failed both Windows attempts at the original 120s.
const original={commit:'d4a7797741595f8314ce004a671a88bf7e43cca1',bytes:12623,
 sha256:'5234f61a344763c1f33d23bf9e850e4779ce28605ad15c82ec1452c8dea1841a',
 blob:'21ee23734050f3cd53baba8f44ccf7017c643960'};
const prefix="local slice=... or 1\nassert(type(slice)=='number' and slice%1==0 and slice>=1 and slice<=5,'invalid encounter coverage slice')\nlocal registered,encounterIndex,sampledSeeds=0,0,0\n";
const edits=[
 [
  "local function test(name, action)\n",
  "local function test(name, action, queueGroup)\n    registered = registered + 1\n    local selected = queueGroup and 1 or encounterIndex <= 10 and 1 or encounterIndex <= 12 and 2 or encounterIndex <= 14 and 3 or encounterIndex <= 16 and 4 or 5\n    if slice ~= selected then return end\n"
 ],
 [
  "    count = count + 1\n",
  "    count = count + 1\n    print(\"ENCOUNTER_COVERAGE_CASE \" .. registered)\n"
 ],
 [
  "for seed = 1, 256 do\n",
  "if slice == 1 then -- keep the complete shared queue sample in one process\nfor seed = 1, 256 do\n"
 ],
 [
  "    end\nend\ntest('all seventeen source queue identities",
  "    end\n    sampledSeeds = sampledSeeds + 1\n    print('ENCOUNTER_COVERAGE_SEED ' .. seed)\nend\nend -- shared queue sample boundary\ntest('all seventeen source queue identities"
 ],
 [
  "    assert(generated.large_slime and generated.lots_of_slimes and generated.exordium_thugs)\nend)",
  "    assert(generated.large_slime and generated.lots_of_slimes and generated.exordium_thugs)\nend,true)"
 ],
 [
  "for _, encounter in ipairs(data.enemies.encounters) do\n",
  "for _, encounter in ipairs(data.enemies.encounters) do\n    encounterIndex = encounterIndex + 1\n"
 ],
 [
  "            print(\"coverage \" .. encounter.id .. \" queueItems=\" .. generated[encounter.id])\n        end)",
  "            print(\"coverage \" .. encounter.id .. \" queueItems=\" .. generated[encounter.id])\n        end,true)"
 ]
];
const footer="\nassert(registered==53 and encounterIndex==18,'all original encounter coverage groups must register')\nassert(count==({37,4,4,4,4})[slice],'every selected original encounter coverage group must execute')\nassert(sampledSeeds==(slice==1 and 256 or 0),'every original queue seed must complete exactly once')\nprint('ENCOUNTER_COVERAGE_SLICE ' .. slice .. ' ' .. count .. ' ' .. registered)\n";
const parts=[
 {path:entry,groups:[...Array.from({length:29},(_,i)=>i+1),31,34,37,40,43,46,49,52],seeds:256,budget:120000},
 {path:'tests/lua/encounter_coverage_slice_2.lua',groups:[30,32,33,35],seeds:0,budget:30000},
 {path:'tests/lua/encounter_coverage_slice_3.lua',groups:[36,38,39,41],seeds:0,budget:30000},
 {path:'tests/lua/encounter_coverage_slice_4.lua',groups:[42,44,45,47],seeds:0,budget:30000},
 {path:'tests/lua/encounter_coverage_slice_5.lua',groups:[48,50,51,53],seeds:0,budget:30000},
];
const wrappers=()=>Object.fromEntries(parts.slice(1).map(p=>[p.path,read(p.path)]));
function validateSource(source){
 assert.ok(source.startsWith(prefix)&&source.endsWith(footer),'only the reviewed bounded selector and completion guards');
 let restored=source.slice(prefix.length,-footer.length);
 for(const [before,after]of [...edits].reverse()){
  assert.equal(restored.split(after).length,2,'one exact inverse for every harness edit');
  restored=restored.replace(after,before);
 }
 const bytes=Buffer.from(restored);
 assert.equal(bytes.length,original.bytes,'all original source bytes');
 assert.equal(sha(restored),original.sha256,'all original helpers, assertions, loops and seed inputs');
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),original.blob,'actual original Git blob');
 return restored;
}
function validatePartitions(rows,files){
 assert.deepEqual(rows,parts,'only the five complete original-budget partitions');
 assert.deepEqual(rows.flatMap(p=>p.groups).sort((a,b)=>a-b),Array.from({length:53},(_,i)=>i+1),'every original logical group exactly once');
 assert.deepEqual(rows.map(p=>p.seeds),[256,0,0,0,0],'one complete shared seed sample, never repeated or divided');
 for(const [i,p]of rows.entries())if(i)assert.equal(files[p.path],`assert(loadfile('${entry}'))(${i+1})\n`,'complete executable wrapper, not a comment');
}
test('encounter partitions reconstruct the exact failing public source and retain every original budget',()=>{
 assert.equal(original.commit,'d4a7797741595f8314ce004a671a88bf7e43cca1');
 const restored=validateSource(read(entry));
 assert.ok(restored.includes('for seed = 1, 256 do'));
 assert.equal(sha(originalLuaRunner(read('scripts/test-lua.mjs'))),'63ec149511d52b9e362f2c9210d092e4d97bd815c5b8c16e7009ade146d5d55b','runner and all original deadlines remain byte-identical');
});
test('raw, Node and CI discovery retain every encounter entry exactly once',()=>{
 validatePartitions(parts,wrappers());
 const discovered=readdirSync('tests/lua').filter(f=>f.endsWith('.lua')).map(f=>'tests/lua/'+f).sort();
 assert.deepEqual(discovered.filter(f=>/^tests\/lua\/encounter_coverage.*\.lua$/.test(f)),parts.map(p=>p.path));
 const shards=Array.from({length:8},(_,i)=>shardLuaScripts(discovered,`${i+1}/8`)).flat();
 for(const p of parts)assert.equal(shards.filter(f=>f===p.path).length,1);
 assert.match(read('package.json'),/node --test --test-concurrency=1 tests\/\*\.test\.mjs/);
 assert.match(read('.github/workflows/quality.yml'),/node scripts\/test-lua\.mjs --shard/);
});
test('negative controls reject weakened bodies, changed seeds, bypassed setup and partition coverage drift',()=>{
 const source=read(entry);
 for(const changed of [source.replace('assert(Combat.endTurn(s))','assert(true)'),source.replace('for seed = 1, 256 do','for seed = 1, 255 do'),
  source.replace('if slice == 1 then -- keep','if true then -- keep'),source.replace('    assert(generated.large_slime and generated.lots_of_slimes and generated.exordium_thugs)\n',''),
  source.replace('    print("ENCOUNTER_COVERAGE_CASE " .. registered)\n',''),source.replace('    sampledSeeds = sampledSeeds + 1\n',''),source.replace("    print('ENCOUNTER_COVERAGE_SEED ' .. seed)\n",'')])
  assert.throws(()=>validateSource(changed),{code:'ERR_ASSERTION'});
 assert.throws(()=>validatePartitions(parts.slice(0,-1),wrappers()),{code:'ERR_ASSERTION'});
 const overlap=structuredClone(parts);overlap[1].groups[0]=29;
 assert.throws(()=>validatePartitions(overlap,wrappers()),{code:'ERR_ASSERTION'});
 const hidden=wrappers();hidden[parts[1].path]='-- '+hidden[parts[1].path];
 assert.throws(()=>validatePartitions(parts,hidden),{code:'ERR_ASSERTION'});
});
