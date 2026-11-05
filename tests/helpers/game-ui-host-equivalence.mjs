import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import lua from 'luaparse';
import {gunzipSync} from 'node:zlib';
const root=process.cwd();
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const old=fs.readFileSync('tests/fixtures/game-ui-host/old-host.lua','utf8');
assert.equal(hash(old.replaceAll('\r\n','\n')),'165e2ad1180cab9daf5321b46d1f87fe9c34ed6ebbcd3c3a8b495d23974e0933');
export const mainWindows=[[1,6],[7,12],[13,15],[16,18],[19,21],[22,24],[25,27],[28,30],[31,32],[33,34],[35,35]];
export const scenarios={clock:7,wide:7,'full-source':7,'map-failure':7,'refresh-reentry':7,'disable-live':7,overlays:13,egg:11,route:18,chapters:11};
export function windows(total){const out=[];for(let n=1;n<=total;n+=6)out.push([n,Math.min(total,n+5)]);return out;}
function coverage(ranges,total){assert.deepEqual(ranges.flatMap(([a,b])=>Array.from({length:b-a+1},(_,i)=>a+i)),Array.from({length:total},(_,i)=>i+1));}
coverage(mainWindows,35);for(const total of Object.values(scenarios))coverage(windows(total),total);
export function materialize(kind){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'abyss-host-'+kind+'-'));
 for(const p of ['src/lua','build/lua','tests/lua/support'])fs.cpSync(path.join(root,p),path.join(dir,p),{recursive:true});
 const source=path.join(dir,'src/lua/abyss_game_ui.lua');
 if(kind==='old'){
  fs.writeFileSync(source,old);
  for(const p of ['input','lifecycle','overlays','run','view'])fs.unlinkSync(path.join(dir,`src/lua/abyss_game_ui_${p}.lua`));
 }
 const f=path.join(dir,'tests/lua/support/game_ui_fixture.lua');
 const text=fs.readFileSync(f,'utf8'),needle='return NativeContract.control(self,spec)';
 assert.equal(text.split(needle).length,2);
 fs.writeFileSync(f,text.replace(needle,'if ABYSS_HOST_CONTROL then ABYSS_HOST_CONTROL(self) end\n    '+needle));
 return dir;
}
export function execute(dir,seed,constructor='',from=1,to=35){
 const started=Date.now();
 const r=spawnSync(process.execPath,[path.join(root,'tests/helpers/game-ui-host-vm.mjs'),String(seed),constructor,String(from),String(to)],{
  cwd:dir,encoding:'utf8',timeout:30000,maxBuffer:32*1024*1024,
  env:{...process.env,LUA_PATH:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_PATH_5_3:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_INIT:'',LUA_INIT_5_3:''}});
 fs.mkdirSync('build/ui-host-impl',{recursive:true});
 const receipt={seed,scenario:constructor,from,to,elapsedMs:Date.now()-started,status:r.status,signal:r.signal,
  error:r.error?{code:r.error.code,message:r.error.message}:null,encodedBytes:r.stdout?.length||0,stderr:r.stderr};
 fs.writeFileSync(path.join('build/ui-host-impl',`vm-${path.basename(dir)}-${seed}-${from}-${to}-${crypto.randomUUID()}.json`),JSON.stringify(receipt,null,2)+'\n');
 if(r.error){
  fs.writeFileSync('build/ui-host-impl/failed.log',r.stdout||'');
  console.error('HOST_VM_FAILURE '+JSON.stringify(receipt));
 }
 assert.ifError(r.error);assert.equal(r.status,0,r.stderr+'\n'+r.stdout.slice(-2000));
 const total=constructor.startsWith('short-')?scenarios[constructor.slice(6)]:constructor?1:35;
 const encoded=r.stdout.match(/^HOST_TRACE_GZIP ([A-Za-z0-9+/=]+)\n$/);assert.ok(encoded,'complete lossless trace transport');
 const stdout=gunzipSync(Buffer.from(encoded[1],'base64'),{maxOutputLength:128*1024*1024}).toString('utf8');
 assert.match(stdout,new RegExp(`^GAME_UI_HOST_TRACE_PASS checkpoints=${total}$`,'m'));
 assert.equal([...stdout.matchAll(/^HOST_TRACE /gm)].length,Math.max(0,Math.min(to,total)-from+1),'exact full trace count');
 assert.equal([...stdout.matchAll(/^HOST_EVENTS /gm)].length,Math.max(0,Math.min(to,total)-from+1),'exact ordered native stream count');
 console.log(`HOST_TRACE_BYTES ms=${Date.now()-started} encoded=${r.stdout.length} decoded=${Buffer.byteLength(stdout)}`);
 return stdout;
}

export function runPair({seed=1,from=1,to=6,scenario='',requiredBaselineMarker,expectedMutantMarker},mutate){
 const a=materialize('old'),b=materialize('new');
 try{
  for(const base of ['src/lua','build/lua'])for(const name of fs.readdirSync(path.join(a,base))){
   if(name==='abyss_game_ui.lua')continue;
   assert.equal(hash(fs.readFileSync(path.join(a,base,name))),hash(fs.readFileSync(path.join(b,base,name))),base+'/'+name);
  }
  const expected=execute(a,seed,scenario,from,to),actual=execute(b,seed,scenario,from,to);
  const tag=`${scenario||'main'}-${seed}-${from}-${to}`;
  fs.mkdirSync('build/ui-host-impl',{recursive:true});
  fs.writeFileSync(`build/ui-host-impl/old-${tag}.log`,expected);
  fs.writeFileSync(`build/ui-host-impl/new-${tag}.log`,actual);
  assert.ok(actual===expected,'complete ordered trace mismatch: '+tag);
  if(requiredBaselineMarker)assert.ok(expected.includes(requiredBaselineMarker),'required successful baseline boundary');
  if(expectedMutantMarker)assert.ok(!expected.includes(expectedMutantMarker),'original baseline must not fail the contract assertion');
  if(mutate){mutate(b);const mutant=execute(b,seed,scenario,from,to);fs.writeFileSync(`build/ui-host-impl/mutant-${tag}.log`,mutant);
   if(expectedMutantMarker)assert.ok(mutant.includes(expectedMutantMarker),'mutant must reach the named contract assertion');
   assert.ok(mutant!==expected,'assertion must kill semantic mutant');}
 }finally{removeTemporaryHost(a);removeTemporaryHost(b);}
}
function removeTemporaryHost(dir){
 const absolute=path.resolve(dir);
 assert.equal(path.dirname(absolute),path.resolve(os.tmpdir()),'cleanup must stay directly inside the test temporary root');
 assert.match(path.basename(absolute),/^abyss-host-(?:old|new)-/,'cleanup must target a created Host test root');
 assert.ok(!fs.lstatSync(absolute).isSymbolicLink(),'cleanup target must not be an alias');
 fs.rmSync(absolute,{recursive:true,force:true});
}
export function mutateSource(dir,module,before,after){
 const file=path.join(dir,`src/lua/abyss_game_ui_${module}.lua`);let source=fs.readFileSync(file,'utf8');
 const ast=lua.parse(source,{ranges:true});let range;
 function visit(n){if(!n||typeof n!=='object')return;
  if(n.range&&source.slice(...n.range)===before){if(range)assert.deepEqual(range,n.range,'mutation must have one source range');range=n.range;}
  for(const v of Object.values(n))if(Array.isArray(v))v.forEach(visit);else if(v&&typeof v==='object')visit(v);
 }visit(ast);assert.ok(range,'mutation must match complete parsed semantic node');
 source=source.slice(0,range[0])+after+source.slice(range[1]);lua.parse(source);fs.writeFileSync(file,source);
}
