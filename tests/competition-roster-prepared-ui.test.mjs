import {preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua,shardLuaScripts} from '../scripts/test-lua.mjs';
import {discoverJs,jsShard,timings} from '../scripts/ci-shards.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=value=>createHash('sha256').update(value).digest('hex');
const entry='tests/lua/competition_roster_prepared_ui.lua';
const slices=[{path:entry,first:1,last:18},{path:'tests/lua/competition_roster_prepared_ui_slice_2.lua',first:19,last:33}];
const proof={"prefix":"local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 18\nassert(type(sliceFirst)=='number'and type(sliceLast)=='number'and sliceFirst%1==0 and sliceLast%1==0\n and sliceFirst>=1 and sliceLast<=33 and sliceFirst<=sliceLast,'invalid prepared UI case range')\nlocal sliceRegistered=0\nlocal function selected()\n sliceRegistered=sliceRegistered+1\n if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return false end\n print('COMPETITION_PREPARED_UI_CASE '..sliceRegistered)\n return true\nend\n","footer":"assert(sliceRegistered==33,'all 33 original prepared UI cases must register')\nassert(count==sliceLast-sliceFirst+1,'every selected original prepared UI case must execute')\nprint('COMPETITION_PREPARED_UI_SLICE '..sliceFirst..' '..sliceLast..' '..count)\n","gates":[["  local ui,root,samples=fixture(source)\n","  if selected()then\n",true],["  verifySource();verifySelection();count=count+1\n","  end -- selected original route case\n",false],["local changed=C.copy(F.Data)\n","if selected()then\n",true],["verify();assert(samples()==0 and not ui.run);count=count+1\n","end -- selected original changed-source case\n",false],["local stale=C.copy(F.Data)\n","if selected()then\n",true],["verifyStale();verifyStaleSource();count=count+1\n","end -- selected original stale-source case\n",false],[" local source=C.copy(F.Data);source.characterId=id\n"," if selected()then\n",true],[" count=count+1\nend\n-- The future/development host"," end -- selected original consistent-marker case\n",false],["local development,developmentRoot,developmentSamples=fixture(F.Data,'full-source')\n","if selected()then\n",true],["count=count+1\n-- Direct legacy factories","end -- selected original development case\n",false],[" local options=full and {experimental=true,campaign=true,campaignProfile='full-source'}or nil\n"," if selected()then\n",true],[" count=count+1\nend\nprint('COMPETITION_PREPARED_UI_PASS "," end -- selected original legacy case\n",false]],"originalSha256":"ff9d0aa399934e599c93ef086aac9a518c9de859ee44e5a0db03ea769bf31c55","originalGitBlob":"208b8c3e8944f8822211d59269a418c911172ba5","boundedSha256":"acc9dc54007199013b072f9fac58e177bf937bda193d7dcb20bee91ce6eb9618"};
function originalPreparedUiSource(value){
 assert.equal(hash(value),proof.boundedSha256,'only the exact reviewed bounded prepared UI registrar is accepted');
 assert.ok(value.startsWith(proof.prefix));assert.ok(value.endsWith(proof.footer));
 value=value.slice(proof.prefix.length,-proof.footer.length);
 for(const [anchor,insert,before]of [...proof.gates].reverse()){
  let added;
  if(anchor.startsWith(' count=count+1\nend\n'))added=' count=count+1\n'+insert+anchor.slice(' count=count+1\n'.length);
  else if(anchor==='count=count+1\n-- Direct legacy factories')added='count=count+1\n'+insert+'-- Direct legacy factories';
  else added=before?insert+anchor:anchor+insert;
  assert.equal(value.split(added).length,2,'one exact original case boundary');
  value=value.replace(added,anchor);
 }
 assert.equal(hash(value),proof.originalSha256,'all original setup, 33 cases, assertions, seeds and statement order survive');
 const bytes=Buffer.from(value);
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),proof.originalGitBlob);
 return value;
}
for(const slice of slices)test(`configured-source prepared UI retains original cases ${slice.first}–${slice.last}`,t=>{
 const started=Date.now(),result=runLua(slice.path,{timeout:30000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 const expected=Array.from({length:slice.last-slice.first+1},(_,i)=>slice.first+i);
 assert.match(result.stdout,new RegExp(`COMPETITION_PREPARED_UI_PASS ${expected.length}; native/natural NOT_RUN`));
 assert.deepEqual([...result.stdout.matchAll(/^COMPETITION_PREPARED_UI_CASE (\d+)$/gm)].map(match=>Number(match[1])),expected);
 assert.match(result.stdout,new RegExp(`COMPETITION_PREPARED_UI_SLICE ${slice.first} ${slice.last} ${expected.length}`));
 t.diagnostic(`Lua fixture ${slice.path}: ${Date.now()-started} ms; original cases ${expected.join(',')}`);
});
test('bounded prepared UI registrar reverses every reviewed byte and rejects range case seed or execution drift',()=>{
 const bounded=read(entry),original=originalPreparedUiSource(bounded);
 assert.equal(hash(original),'ff9d0aa399934e599c93ef086aac9a518c9de859ee44e5a0db03ea769bf31c55');
 assert.equal(proof.originalGitBlob,'208b8c3e8944f8822211d59269a418c911172ba5');
 assert.equal(read(slices[1].path),`assert(loadfile("${entry}"))(19,33)\n`);
 assert.deepEqual(slices.flatMap(({first,last})=>Array.from({length:last-first+1},(_,i)=>first+i)),Array.from({length:33},(_,i)=>i+1));
 const mutants=[bounded.replace(proof.prefix,''),bounded.replace('sliceLast or 18','sliceLast or 19'),
  bounded.replace('  if selected()then\n',''),bounded.replace(proof.footer,''),bounded+proof.footer,
  bounded.replace('return 3 end','return 4 end'),bounded.replace('assert(adaptations==0','assert(adaptations ==0')];
 for(const mutant of mutants){assert.notEqual(mutant,bounded);assert.throws(()=>originalPreparedUiSource(mutant),/exact reviewed/);}
 assert.equal(hash(preAcceptedPr323Source('scripts/test-lua.mjs',read('scripts/test-lua.mjs'))),'7866bfbb9888417087a669dd20f524de32ccb1efe1d035a283fc1b148d26ed33','original runner deadlines and worker limits remain unchanged');
});
test('raw and Node discovery retain both prepared UI slices exactly once in every hosted plan',()=>{
 const raw=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name),expected=slices.map(slice=>slice.path);
 assert.deepEqual(raw.filter(path=>/^tests\/lua\/competition_roster_prepared_ui(?:_slice_\d+)?\.lua$/.test(path)).sort(),[...expected].sort());
 for(const workers of [1,2]){
  const actual=Array.from({length:8},(_,i)=>shardLuaScripts(raw,`${i+1}/8`,timings,workers)).flat().filter(path=>expected.includes(path));
  assert.deepEqual(actual.sort(),[...expected].sort(),`every raw prepared UI slice executes once with ${workers} worker(s)`);
 }
 const contract='tests/competition-roster-prepared-ui.test.mjs',js=discoverJs();assert.equal(js.filter(path=>path===contract).length,1);
 for(const [platform,count]of [['win32',8],['linux',4]]){
  const actual=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files).flat();
  assert.equal(actual.filter(path=>path===contract).length,1,`${platform} executes the complete prepared UI regression once`);
 }
});
