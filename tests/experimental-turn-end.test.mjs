import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const fixture='tests/lua/experimental_turn_end.lua',file='src/lua/abyss_combat.lua';
const normalize=s=>s.replaceAll('\r\n','\n'),hash=s=>createHash('sha256').update(s).digest('hex');
const frozen=JSON.parse(readFileSync('tests/fixtures/experimental-turn-end-before.json','utf8'));
const baseline=gunzipSync(Buffer.from(frozen.gzipBase64,'base64')).toString('utf8');
assert.equal(frozen.revision,'9a2d88dc2816a7a5613aba3035fecc0a8a4e0b1c');
assert.equal(frozen.sha256,'10304febd86439edcea6054101bc1dc56e3658bd07d2f41f341644b811e838b2');
assert.equal(frozen.path,file);assert.equal(hash(baseline),frozen.sha256);
function execute(source,caseName,trace=false){
 const dir=mkdtempSync(join(tmpdir(),'experimental-end-'));
 try{
  const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');writeFileSync(module,source);
  writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});ABYSS_EXPERIMENTAL_END_TRACE=${trace?'true':'false'};ABYSS_EXPERIMENTAL_END_EXISTING=true;${caseName?`ABYSS_EXPERIMENTAL_END_CASE=${luaString(caseName)};`:''}dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
  return runLua(driver,{maxBuffer:64*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}
function region(source){
 const begin=source.indexOf('local function resetExperimentalTurnCosts('),end=source.indexOf('local function nativeEthereal(');
 assert(begin>=0&&end>begin,'bounded experimental extraction region');return {begin,end,body:source.slice(begin,end)};
}
test('experimental end-turn complete graphs retain costs, NoDraw, death, retain, skips, enemies and failure boundaries',t=>{
 const source=normalize(readFileSync(file,'utf8'));region(source);
 const before=execute(baseline,undefined,true),after=execute(source,undefined,true);
 for(const result of [before,after]){
  assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EXPERIMENTAL_TURN_END_PASS 5/);
  assert.equal((result.stdout.match(/NATIVE_TURN_END_PASS 1/g)||[]).length,6,'six original experimental lifecycle scenarios replayed');
 }
 assert.ok(before.stdout===after.stdout,'complete old/new graph and boundary stdout must match');
 t.diagnostic(`complete trace ${Buffer.byteLength(after.stdout)} bytes, SHA256 ${hash(after.stdout)}`);
});
test('experimental end-turn real semantic mutations fail state and ordering assertions',()=>{
 const source=normalize(readFileSync(file,'utf8')),bounded=region(source);
 const mutations=[
  ['exhaust cost remains outside reset','cost-reset-piles',
   'for _,pile in ipairs({state.hand,state.draw,state.discard}) do for _,c in ipairs(pile)',
   'for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust}) do for _,c in ipairs(pile)'],
  ['player-end NoDraw precedes Ethereal cleanup','no-draw-experimental',
   'if prepareExperimentalPlayerEnd(state)then return true end\n    state.silentRetainResume=nil\n    discardOwnerEnd(state)',
   'discardOwnerEnd(state)\n    if prepareExperimentalPlayerEnd(state)then return true end\n    state.silentRetainResume=nil'],
  ['late retain guard remains independent','late-resume-guard',
   'if not state.silentRetainResume then\n    resetExperimentalTurnCosts(state)',
   'if true then\n    resetExperimentalTurnCosts(state)'],
  ['newly summoned enemy cannot act immediately','enemy-snapshot-experimental',
   'for _, enemy in ipairs(actionQueue) do','for _, enemy in ipairs(state.enemies) do'],
  ['lethal second Regret stops cleanup','second-regret-death',
   '-- Keep the current UID in cardInUse; later cards and cleanup never run.\n        if finish(state) then return true end',
   '-- Keep the current UID in cardInUse; later cards and cleanup never run.\n        if false and finish(state) then return true end'],
  ['skip enemy group is consumed before enemy boundary','vault-skips-entire-enemy-phase',
   'if state.skipMonsterTurn then','if false then'],
 ];
 for(const [label,caseName,before,after]of mutations){
  assert.equal(bounded.body.split(before).length-1,1,`${label}: exact unique experimental production mutation`);
  const mutant=source.slice(0,bounded.begin)+bounded.body.replace(before,after)+source.slice(bounded.end);
  const result=execute(mutant,caseName);assert.notEqual(result.status,0,`${label}: mutant survived`);
  assert.match(result.stdout+result.stderr,/\[(?:EXPERIMENTAL_END|NATIVE_END)\]/,`${label}: genuine behavioral assertion`);
 }
});
