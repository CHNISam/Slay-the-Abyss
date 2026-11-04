import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const file='src/lua/abyss_combat.lua',fixture='tests/lua/end_turn_admission.lua';
const normalize=s=>s.replaceAll('\r\n','\n'),hash=s=>createHash('sha256').update(s).digest('hex');
const frozen=JSON.parse(readFileSync('tests/fixtures/end-turn-admission-before.json','utf8'));
const baseline=gunzipSync(Buffer.from(frozen.gzipBase64,'base64')).toString('utf8');
assert.equal(frozen.revision,'f26aeb30c0995de70cf340af977d3c8579c1a2b5');
assert.equal(frozen.path,file);assert.equal(frozen.sha256,'05a24758f0815a8186a868048029c3e4bb22d23e99b1199c697ad69b665ce80a');
assert.equal(hash(baseline),frozen.sha256);
function execute(source,caseName,trace=false){
 const dir=mkdtempSync(join(tmpdir(),'end-admission-'));
 try{
  const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');writeFileSync(module,source);
  writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});ADMISSION_TRACE=${trace?'true':'false'};${caseName?`ADMISSION_CASE=${luaString(caseName)};`:''}dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
  return runLua(driver,{maxBuffer:64*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}
test('public end-turn admission preserves full graphs, short-circuit reads, rollback owners and return arity',t=>{
 const before=execute(baseline,undefined,true),after=execute(normalize(readFileSync(file,'utf8')),undefined,true);
 for(const r of [before,after]){assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/END_TURN_ADMISSION_PASS 12/);}
 assert.ok(before.stdout===after.stdout,'independent old/new mutable graph, aliases, events, RNG, queue, returns and errors');
 t.diagnostic(`complete trace ${Buffer.byteLength(after.stdout)} bytes, SHA256 ${hash(after.stdout)}`);
});
test('public end-turn semantic mutations fail real route, capability and arity assertions',()=>{
 const source=normalize(readFileSync(file,'utf8'));
 const mutations=[
  ['potion has first refusal','potion-first',
   "if state.pendingPotionChoice then return false,'potion_choice_pending'end","if false then return false,'potion_choice_pending'end"],
  ['relic false carries refusal','relic-false',
   'if relicResult==false then return false,relicReason end','if false then return false,relicReason end'],
  ['relic pause ends public admission','relic-pause',
   "if relicResult=='pause'or relicResult=='terminal'then return true end","if relicResult=='terminal'then return true end"],
  ['retained pending choice remains refusal','retained-public-resume',
   'if retainedResult==false then return false,retainedReason end','if retainedResult==false then return true end'],
  ['catalog short circuit remains source ordered','catalog-short-circuit',
   'return state.catalog.cards.evolve or state.catalog.cards.claw or state.catalog.cards.blur or state.catalog.cards.wallop',
   'return state.catalog.cards.claw or state.catalog.cards.evolve or state.catalog.cards.blur or state.catalog.cards.wallop'],
  ['second advanced read retains fallback','second-predicate-fallback',
   'if not advancedTurnCleanup(state) then return endExperimentalTurn(state) end',
   'if true then return endExperimentalTurn(state) end'],
  ['exact parent owner is consumed','owner-and-atomic-alias-restore',
   "return rollbackOwner and require('abyss_snapshot').ownedRestore(rollbackOwner,state)or require('abyss_snapshot').capture(state)",
   "return require('abyss_snapshot').capture(state)"],
  ['late errors restore complete graph','owner-and-atomic-alias-restore',
   'local function invokeEndTurnResolver(state,resolver,restore)\n    local called,ok,reason=pcall(resolver,state)\n    if not called then restore();error(ok,0)end',
   'local function invokeEndTurnResolver(state,resolver,restore)\n    local called,ok,reason=pcall(resolver,state)\n    if not called then error(ok,0)end'],
  ['transactional nil reason retains return slot','catalog-short-circuit',
   'local function invokeEndTurnResolver(state,resolver,restore)\n    local called,ok,reason=pcall(resolver,state)\n    if not called then restore();error(ok,0)end\n    return ok,reason',
   'local function invokeEndTurnResolver(state,resolver,restore)\n    local called,ok,reason=pcall(resolver,state)\n    if not called then restore();error(ok,0)end\n    return ok'],
  ['direct native keeps its single result','direct-native',
   'if not state.experimentalMechanics then return endNativeTurn(state) end',
   'if not state.experimentalMechanics then local ok,why=endNativeTurn(state);return ok,why end'],
  ['original V4 always chooses native','original-overrides-experimental',
   'local resolver=(state.originalV4 or not state.experimentalMechanics)and endNativeTurn or endExperimentalTurn',
   'local resolver=(not state.experimentalMechanics)and endNativeTurn or endExperimentalTurn'],
  ['snapshot precedes resolver property reads','snapshot-before-resolver-read',
   'local restore=endTurnRestore(state,rollbackOwner)\n        local resolver=(state.originalV4 or not state.experimentalMechanics)and endNativeTurn or endExperimentalTurn',
   'local resolver=(state.originalV4 or not state.experimentalMechanics)and endNativeTurn or endExperimentalTurn\n        local restore=endTurnRestore(state,rollbackOwner)'],
 ];
 for(const [label,caseName,before,after]of mutations){
  assert.equal(source.split(before).length-1,1,`${label}: exact unique production mutation`);
  const r=execute(source.replace(before,after),caseName);assert.notEqual(r.status,0,`${label}: mutant survived`);
  assert.match(r.stdout+r.stderr,/\[END_ADMISSION\]/,`${label}: behavioral assertion, not parse/runner failure`);
 }
});
