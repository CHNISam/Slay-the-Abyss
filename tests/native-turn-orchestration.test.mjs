import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const fixture='tests/lua/native_turn_orchestration.lua';
const sourceFile='src/lua/abyss_combat.lua';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const frozen=JSON.parse(readFileSync('tests/fixtures/native-turn-before.json','utf8'));
const baseline=gunzipSync(Buffer.from(frozen.gzipBase64,'base64')).toString('utf8');
assert.equal(frozen.revision,'b4ac63145689b9dd632db100eee49087f6182b39');
assert.equal(frozen.path,sourceFile);
assert.equal(frozen.sha256,'2e6a406674d95f0037892120301b684857414dc75b9b225fec2052ff8ed6b55a');
assert.equal(hash(baseline),frozen.sha256,'immutable complete baseline source');

function execute(source,caseName){
 const dir=mkdtempSync(join(tmpdir(),'native-turn-'));
 try{
  const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');
  writeFileSync(module,source);
  writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});ABYSS_NATIVE_TURN_TRACE=true;${caseName?`ABYSS_NATIVE_TURN_CASE=${luaString(caseName)};`:''}dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
  return runLua(driver,{maxBuffer:8*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}

test('native turn preserves complete mutable graphs, aliases, queues, RNG, events and failure results',()=>{
 const before=execute(baseline),after=execute(normalize(readFileSync(sourceFile,'utf8')));
 for(const result of [before,after]){
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_TURN_ORCHESTRATION_PASS 12/);
 }
 assert.equal(after.stdout,before.stdout,'independent old/new VMs retain every recorded boundary');
});

test('native turn ordering, consumption and refusal regressions fail behavioral assertions',()=>{
 const source=normalize(readFileSync(sourceFile,'utf8'));
 const mutations=[
  ['opening marker consumed','opening',';state.openingInnateExtra=nil',';state.openingInnateExtra=state.openingInnateExtra'],
  ['Brutality draw before HP loss','powers',
   'CardActions.enqueue(state,{op="draw",value=p.statuses.brutality})\n        CardActions.enqueue(state,{op="loseHp",value=p.statuses.brutality})',
   'CardActions.enqueue(state,{op="loseHp",value=p.statuses.brutality})\n        CardActions.enqueue(state,{op="draw",value=p.statuses.brutality})'],
  ['callback refusal stops turn','callback-refusal',
   'local ok, reason = beforeOpeningDraw(state)\n        if not ok then return false, reason end',
   'local ok, reason = beforeOpeningDraw(state)\n        if false then return false, reason end'],
  ['later turns omit innate draw','later-innate',
   'if state.turn==1 and state.openingInnateExtra then','if state.openingInnateExtra then'],
  ['post-draw relic remains behind ordinary draw','post-draw-hooks',
   'enqueueNativeOpeningDraw(state,originalExtra)\n    enqueueNativePostDraw(state,p)',
   'enqueueNativePostDraw(state,p)\n    enqueueNativeOpeningDraw(state,originalExtra)'],
 ];
 for(const [label,caseName,before,after] of mutations){
  assert.equal(source.split(before).length-1,1,`${label}: unique production mutation`);
  const result=execute(source.replace(before,after),caseName);
  assert.notEqual(result.status,0,`${label}: mutant survived`);
  assert.match(result.stdout+result.stderr,/\[NATIVE_TURN\]/,`${label}: genuine behavioral assertion, not parse/runner failure`);
 }
});
