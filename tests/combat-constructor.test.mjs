import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const file='src/lua/abyss_combat.lua',fixture='tests/lua/combat_constructor.lua';
const normalize=s=>s.replaceAll('\r\n','\n'),hash=s=>createHash('sha256').update(s).digest('hex');
const frozen=JSON.parse(readFileSync('tests/fixtures/combat-constructor-before.json','utf8'));
const baseline=gunzipSync(Buffer.from(frozen.gzipBase64,'base64')).toString('utf8');
assert.equal(frozen.revision,'2107aeda9a8fca4b219b9281f2ddecd22f1b05b6');
assert.equal(frozen.sha256,'2d9dfa94c855e07dc112ca09e6d94db7332ec77acd7971f69400bc417e7add7c');
assert.equal(frozen.path,file);assert.equal(hash(baseline),frozen.sha256);

function execute(source,{caseName,trace=false}={}){
 const dir=mkdtempSync(join(tmpdir(),'combat-constructor-'));
 try{
  const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');
  writeFileSync(module,source);
  writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});ABYSS_CONSTRUCTOR_TRACE=${trace?'true':'false'};${caseName?`ABYSS_CONSTRUCTOR_CASE=${luaString(caseName)};`:''}dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
  return runLua(driver,{maxBuffer:32*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}

test('complete old/new constructor graphs retain caller data, options, RNG, aliases, callbacks and failures',t=>{
 const current=normalize(readFileSync(file,'utf8'));
 assert.equal(current.slice(0,current.indexOf('local function constructorOptions(')),baseline.slice(0,baseline.indexOf('function M.new(')),'only the constructor region changes relative to the frozen source');
 const before=execute(baseline,{trace:true}),after=execute(current,{trace:true});
 for(const result of [before,after]){
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/COMBAT_CONSTRUCTOR_PASS 11/);
 }
 assert.ok(after.stdout===before.stdout,'complete graph and callback/order output differ between independent old/new VMs');
 t.diagnostic(`complete trace ${Buffer.byteLength(after.stdout)} bytes, SHA256 ${hash(after.stdout)}`);
});

test('constructor option, stream, UID, metadata and callback regressions fail behavioral assertions',()=>{
 const source=normalize(readFileSync(file,'utf8'));
 const mutations=[
  ['explicit false options','profile-option-defaults',
   'if options.enableStances==nil then options.enableStances=true end','if not options.enableStances then options.enableStances=true end'],
  ['caller stream isolation','independent-streams',
   'state.cardRandomRng=SourceRandom.cloneState(options.roomStreams.cardRandomRng)','state.cardRandomRng=options.roomStreams.cardRandomRng'],
  ['permanent UID allocation','permanent-card-identity',
   'state.nextUid = math.max(state.nextUid,uid)+1','state.nextUid = uid+1'],
  ['bottled identity','card-copy-metadata',
   'instance.inBottleFlame=value.inBottleFlame','instance.inBottleFlame=nil'],
  ['opening refusal','callback-refusal',
   'local ok, reason = options.beforeFirstTurn(state)\n        if not ok then return nil, reason end',
   'local ok, reason = options.beforeFirstTurn(state)\n        if false then return nil, reason end'],
  ['prepared encounter identity','prepared-adoption',
   'if options.preparedEncounter then EnemySetup.adopt(state,options)','if false then EnemySetup.adopt(state,options)'],
  ['opening callback preserved','callback-refusal',
   'M.startPlayerTurn(state, options.beforeOpeningDraw)','M.startPlayerTurn(state, nil)'],
  ['registered pool ownership','defaults-and-registration',
   'local sourcePools=data~=originalData and data.cards.sourcePools or copy(data.cards.sourcePools)',
   'local sourcePools=data.cards.sourcePools'],
 ];
 for(const [label,caseName,before,after] of mutations){
  assert.equal(source.split(before).length-1,1,`${label}: unique live production mutation`);
  const result=execute(source.replace(before,after),{caseName});
  assert.notEqual(result.status,0,`${label}: mutant survived`);
  assert.match(result.stdout+result.stderr,/\[COMBAT_CONSTRUCTOR\]/,`${label}: must fail a behavioral assertion, not parse or runner error`);
 }
});
