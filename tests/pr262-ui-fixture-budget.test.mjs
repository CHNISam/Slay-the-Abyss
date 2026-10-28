import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const sha=s=>createHash('sha256').update(s).digest('hex');
const registration='    registered=registered+1\n    if registered<first or registered>last then return end\n';
const inlineRegistration=' registered=registered+1;if registered<first or registered>last then return end;';
const suites=[
 {name:'card_help_release',total:31,size:4,hash:'088862441fab127f5f29dee6cc990ab39b59152e57250310386bae6b8f3808f2',marker:'LUA_CARD_HELP_RELEASE'},
 {name:'looter_potion_ui',total:8,size:1,hash:'730f8c33080a66916981f912c8fece20a002eceba8bd3771b9c0619481871a68',marker:'LOOTER_POTION_UI'},
];
const header=s=>`local first,last=...\nfirst,last=first or 1,last or ${s.size}\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=${s.total} and first<=last,'invalid UI budget slice')\nlocal registered=0\n`;
const footer=s=>`assert(registered==${s.total},'original UI case discovery changed')\nassert(passed+failed==last-first+1,'UI budget slice coverage changed')\n`;
const ranges=s=>Array.from({length:8},(_,i)=>({first:i*s.size+1,last:Math.min((i+1)*s.size,s.total),file:`${s.name}${i===0?'':`_slice_${i+1}`}.lua`}));
function restore(source,s){return source.replace(header(s),'').replace(registration,'').replace(inlineRegistration,'').replace(footer(s),'');}

test('UI budget split restores both original complete bodies and retains the original default 30s budget',()=>{
 for(const s of suites){
  const source=read(`tests/fixtures/js-owned/tests/lua/${s.name}.lua`);
  assert.ok(source.startsWith(header(s)),`${s.name} must explicitly select its original first slice`);
  assert.equal(sha(restore(source,s)),s.hash,'no assertion, setup, timing or source seed may change');
  assert.ok(restore(source,s).includes('assert('));
  assert.notEqual(sha(restore(source,s).replace('assert(','assert(true or ')),s.hash,'weakened original assertions must be rejected');
  const changed=restore(source,s).replace("'bash'","'cleave'");
  if(changed!==restore(source,s))assert.notEqual(sha(changed),s.hash,'changed real fixture input must be rejected');
 }
 for(const [file,hash]of Object.entries({
  'battle_gesture_fixture.lua':'b92b90973b271f2a5789f9b59942263ecda7b6fb1922b1b6780b4ae8f892140e',
  'looter_potion_ui_fixture.lua':'c68bcd6d44ebbd5193875c9003e95e8643b97a083c1cbbe4eb5390f629c4c43e',
 }))assert.equal(sha(read('tests/lua/support/'+file)),hash,'original shared fixture inputs must remain unchanged');
 assert.match(read('scripts/test-lua.mjs'),/timeout \?\?= normalizedScript\.endsWith\('tests\/lua\/encounter_coverage\.lua'\) \? 120000 : mapProperties \? 120000 : fixture \|\| composedHost \? 60000 : 30000;/);
});

test('UI budget split wrappers and raw discovery preserve all 31 card cases and eight whole reward groups exactly once',()=>{
 for(const s of suites){
  const slices=ranges(s),actual=readdirSync('tests/fixtures/js-owned/tests/lua').filter(f=>new RegExp(`^${s.name}(?:_slice_[0-9]+)?\\.lua$`).test(f));
  assert.deepEqual(actual.sort(),slices.map(x=>x.file).sort());
  const covered=slices.flatMap(x=>Array.from({length:x.last-x.first+1},(_,i)=>x.first+i));
  assert.deepEqual(covered,Array.from({length:s.total},(_,i)=>i+1));
  for(const x of slices.slice(1))assert.equal(read(`tests/fixtures/js-owned/tests/lua/${x.file}`),`assert(loadfile('tests/fixtures/js-owned/tests/lua/${s.name}.lua'))(${x.first},${x.last})\n`);
 }
});

for(const s of suites)for(const x of ranges(s))test(`PR262 original UI coverage at 30s: ${x.file} [${x.first}..${x.last}]`,()=>{
 const result=runLua(`tests/fixtures/js-owned/tests/lua/${x.file}`,{timeout:30_000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp(`${s.marker} ${x.last-x.first+1} passed[;]? 0 failed`));
});
