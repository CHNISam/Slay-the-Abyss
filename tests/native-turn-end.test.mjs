import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const fixture='tests/lua/native_turn_end.lua',path='src/lua/abyss_combat.lua';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const proof=JSON.parse(readFileSync('tests/fixtures/native-turn-end-before.json','utf8'));
const baseline=gunzipSync(Buffer.from(proof.gzipBase64,'base64')).toString('utf8');
assert.equal(proof.revision,'b4ac63145689b9dd632db100eee49087f6182b39');
assert.equal(proof.path,path);
assert.equal(proof.sha256,'2e6a406674d95f0037892120301b684857414dc75b9b225fec2052ff8ed6b55a');
assert.equal(hash(baseline),proof.sha256,'immutable complete baseline source');
function execute(source,caseName,trace=false){
 const dir=mkdtempSync(join(tmpdir(),'native-end-'));
 try{
  const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');
  writeFileSync(module,source);
  writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});ABYSS_NATIVE_END_TRACE=${trace?'true':'false'};${caseName?`ABYSS_NATIVE_END_CASE=${luaString(caseName)};`:''}dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
  return runLua(driver,{maxBuffer:64*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}

test('native end-turn preserves full graphs, aliases, events, RNG, paused queues, returns and exceptions in independent VMs',()=>{
 const before=execute(baseline,undefined,true),after=execute(normalize(readFileSync(path,'utf8')),undefined,true);
 for(const result of [before,after]){
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_TURN_END_PASS 13/);
 }
 assert.equal(after.stdout,before.stdout,'complete old/new state and boundary traces');
});

test('native end-turn behavior rejects premature V4 cleanup, repeated retain powers and live enemy iteration',()=>{
 const source=normalize(readFileSync(path,'utf8'));
 const changes=[
  ['V4 cleanup stays after enemy actions','cleanup-v4',
   'if not state.originalV4 and cleanupNativePlayerEnd(state,resumingRetain) then return true end',
   'if cleanupNativePlayerEnd(state,resumingRetain) then return true end'],
  ['enemy action list is snapshotted before summons','enemy-snapshot-native',
   'for _, enemy in ipairs(actionQueue) do','for _, enemy in ipairs(state.enemies) do'],
  ['retained continuation never repeats player powers','retain-native',
   'local function cleanupNativePlayerEnd(state,resumingRetain)\n    if not resumingRetain then',
   'local function cleanupNativePlayerEnd(state,resumingRetain)\n    if true then'],
 ];
 for(const [label,caseName,before,after]of changes){
  // The experimental protocol has its own enemy snapshot loop. Mutate only
  // the native resolver's final matching loop rather than changing both.
  const position=source.lastIndexOf(before);assert.notEqual(position,-1,`${label}: production anchor`);
  const mutant=source.slice(0,position)+after+source.slice(position+before.length);
  const result=execute(mutant,caseName);
  assert.notEqual(result.status,0,`${label}: mutant survived`);
  assert.match(result.stdout+result.stderr,/\[NATIVE_END\]/,`${label}: genuine behavioral assertion`);
 }
});
