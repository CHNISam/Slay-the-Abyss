import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {luaString,toLua} from '../../scripts/build-lua-data.mjs';
import {generatedRuntimeModules} from '../../scripts/build-native-candidate.mjs';

export const relicLifecycleRevision='391306af70d9f5c6fb510223e113fcb7dcb755df';
export const relicLifecycleArchiveSha256='30c35c0b2298dc33ee3227a5dfc7aa32b5e0959fe11dbe30aef17a5af1ce5067';
export const relicLifecycleJsonSha256='0c1593569f1b3f849a15ade6981ebb56fe194e9a6b118f12749084d73ac15476';
export const relicPurgeA27Revision='a27b86a5ffa7f7d344b11413eb5e0c13953af50b';
export const relicPurgeA27ArchiveSha256='68112b06f51194a9523ea287549c29c2871eec56164fa21ace64a1f576efaaac';
export const relicPurgeA27JsonSha256='d46762b99b99d4c3ff8e5bbfa3ec627c08d21c799a155460c2b79d069b2f6e0a';
export const relicLifecycleGroups=['hp','fatal_native','fatal_shared','fatal_orb','fatal_guardian','hooks_turns','hooks_attacks','hooks_opening',
 ...Array.from({length:11},(_,i)=>`uncommon_${String(i+1).padStart(2,'0')}`),'rare','shop_early','shop_late','session',
 ...Array.from({length:9},(_,i)=>`parasite_${String(i+1).padStart(2,'0')}`),'special','dynamic','contracts'];
export const lifecycleHash=value=>createHash('sha256').update(value).digest('hex');
function verifyCorpus(file,archiveSha,jsonSha,revision,count){
 const archive=readFileSync(new URL(file,import.meta.url));
 assert.equal(lifecycleHash(archive),archiveSha,`complete ${count}-source gzip witness`);
 const bytes=gunzipSync(archive);assert.equal(lifecycleHash(bytes),jsonSha,'complete LF source JSON witness');
 const proof=JSON.parse(bytes);assert.equal(proof.schemaVersion,1);assert.equal(proof.normalization,'LF');
 assert.equal(proof.revision,revision);assert.equal(Object.keys(proof.files).length,count);
 for(const [name,file]of Object.entries(proof.files)){
  assert.equal(file.path,`src/lua/${name}.lua`);assert(!file.source.includes('\r'),'LF frozen source');
  assert.equal(lifecycleHash(file.source),file.sha256,`complete LF source: ${name}`);
  assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(file.source)}\0`).update(file.source).digest('hex'),file.gitBlob,`Git blob: ${name}`);
 }
 return proof;
}
export function frozenRelicLifecycleSources(){
 return verifyCorpus('./relic-lifecycle-baseline-391306af.json.gz',relicLifecycleArchiveSha256,relicLifecycleJsonSha256,relicLifecycleRevision,329);
}
export function frozenPurgeA27Sources(){
 return verifyCorpus('./relic-lifecycle-baseline-a27b86a5.json.gz',relicPurgeA27ArchiveSha256,relicPurgeA27JsonSha256,relicPurgeA27Revision,330);
}
function readSource(proof,path){
 assert.match(path,/^src\/lua\/[a-z0-9_]+\.lua$/,'exact original Lua source path');
 const file=proof.files[path.slice(8,-4)];assert.equal(file?.path,path,'registered complete historical source');
 return file.source;
}
export function readFrozenRelic391Source(path){return readSource(frozenRelicLifecycleSources(),path);}
export function readFrozenPurgeA27Source(path){return readSource(frozenPurgeA27Sources(),path);}
export function relicLifecycleGeneratedBindings(){
 return Object.fromEntries([...Object.keys(generatedRuntimeModules),'abyss_map_controls','abyss_ui_layout','abyss_ui_templates'].sort().map(name=>{
  const path=`build/lua/${name}.lua`,source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  return [name,{path,sha256:lifecycleHash(source),source}];
 }));
}
function frozenPrelude(proof,label){
 const generated=relicLifecycleGeneratedBindings(),allowed={},origins={},lines=[];
 for(const [name,file]of Object.entries(proof.files)){
  allowed[name]=true;origins[name]='handwritten';
  lines.push(`assert(package.loaded[${luaString(name)}]==nil,'fresh complete frozen source');package.preload[${luaString(name)}]=function()return assert(load(${luaString(file.source)},${luaString('@'+label+'/'+file.path)},'t'))()end`);
 }
 for(const [name,file]of Object.entries(generated)){
  assert(!allowed[name],'generated source must not shadow a handwritten source');allowed[name]=true;origins[name]='generated';
  lines.push(`assert(package.loaded[${luaString(name)}]==nil,'fresh generated source');package.preload[${luaString(name)}]=function()return assert(load(${luaString(file.source)},${luaString('@generated-current/'+file.path)},'t'))()end`);
 }
 const binding=Object.fromEntries(Object.entries(generated).map(([name,{path,sha256}])=>[name,{path,sha256}]));
 return `do local allowed=${toLua(allowed)};local origins=${toLua(origins)};local originalRequire=require;RELIC_LIFECYCLE_FROZEN={revision=${luaString(proof.revision)},loaded={},generated=${toLua(binding)}};require=function(name)if type(name)=='string'and name:match('^abyss_')then assert(allowed[name],'[RELIC_FROZEN_SOURCE] module outside complete epoch: '..name);local value=originalRequire(name);RELIC_LIFECYCLE_FROZEN.loaded[name]=assert(origins[name]);return value end;return originalRequire(name)end;RELIC_LIFECYCLE_FROZEN.audit=function()for name in pairs(package.loaded)do if type(name)=='string'and name:match('^abyss_')then assert(allowed[name]and RELIC_LIFECYCLE_FROZEN.loaded[name]==origins[name],'[RELIC_FROZEN_SOURCE] unbound loaded module: '..name)end end;return true end end\n`+lines.join('\n')+'\n';
}
export function relicLifecycleFrozenPrelude(){return frozenPrelude(frozenRelicLifecycleSources(),'frozen391');}
export function purgeA27FrozenPrelude(){return frozenPrelude(frozenPurgeA27Sources(),'frozena27');}
// Independent processes retain the original raw runner's 30s / 1MiB limits.
// Native observation is the existing shared observer, with complete readable
// graph records written to a dedicated file rather than stdout transport.
export function runRelicLifecycle(group,{frozen=false,trace=true,isolation=false,a27=false}={}){
 assert(relicLifecycleGroups.includes(group),'registered lifecycle group');
 const variant=a27?'frozena27':frozen?'frozen391':'current',directory=resolve('build/relic-lifecycle',`${group}-${variant}${isolation?'-isolation':''}`);
 mkdirSync(directory,{recursive:true});
 const started=Date.now();
 const result=spawnSync(process.execPath,[resolve('tests/helpers/relic-lifecycle-baseline-vm.mjs'),group,variant,directory,isolation?'isolation':trace?'trace':'raw'],{
  cwd:process.cwd(),encoding:'utf8',timeout:30000,maxBuffer:1024*1024,
 });
 writeFileSync(`${directory}/stdout.log`,result.stdout??'');writeFileSync(`${directory}/stderr.log`,result.stderr??'');
 const receipt={group,variant,status:result.status,signal:result.signal,error:result.error?.message??null,
  milliseconds:Date.now()-started,stdoutBytes:Buffer.byteLength(result.stdout??''),stdoutSha256:lifecycleHash(result.stdout??'')};
 writeFileSync(`${directory}/process.json`,JSON.stringify(receipt,null,2)+'\n');
 assert(!result.error&&!result.signal,`lifecycle subprocess infrastructure failure: ${JSON.stringify(receipt)}`);
 return {...result,directory,manifest:JSON.parse(readFileSync(`${directory}/manifest.json`,'utf8')),
  graph:trace&&!isolation?readFileSync(`${directory}/trace.jsonl`,'utf8'):null};
}
