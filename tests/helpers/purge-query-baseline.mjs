import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';

export const purgeQueryRevision='a27b86a5ffa7f7d344b11413eb5e0c13953af50b';
export const purgeQueryArchiveSha256='7ddb2bf87ff3d7a56a80f34a4bb06e6249e7dd7d0811afd391afad16a5f39dee';
export const purgeQueryJsonSha256='33bd447e719b8a929f9384450f4d00a64a57388332784fc17aead0f6cb47c1d6';
const hash=value=>createHash('sha256').update(value).digest('hex');
export function frozenPurgeQuerySources(){
 const archive=readFileSync(new URL('./purge-query-baseline-a27b86a5.json.gz',import.meta.url));
 assert.equal(hash(archive),purgeQueryArchiveSha256,'complete LivingWall/Boss compressed witness');
 const bytes=gunzipSync(archive);assert.equal(hash(bytes),purgeQueryJsonSha256,'complete LF JSON witness');
 const proof=JSON.parse(bytes);
 assert.equal(proof.schemaVersion,1);assert.equal(proof.revision,purgeQueryRevision);assert.equal(proof.normalization,'LF');
 assert.deepEqual(Object.keys(proof.files),['abyss_living_wall','abyss_boss_relics']);
 for(const [module,file]of Object.entries(proof.files)){
  assert.equal(file.path,`src/lua/${module}.lua`);assert(!file.source.includes('\r'));
  assert.equal(hash(file.source),file.sha256,`complete source identity: ${module}`);
 }
 return proof;
}

// Raw and traced fixtures use the existing runner's unchanged 30s/1MiB limits.
// Every old/current call executes in a separate VM with real shared dependencies.
export function runPurgeQueryFixture(fixture,{frozen=false}={}){
 assert.match(fixture,/^tests\/lua\/purge_query_[a-z_]+\.lua$/);
 const directory='build/purge-query-baseline';mkdirSync(directory,{recursive:true});
 const version=frozen?'frozena27':'current',name=fixture.split('/').at(-1).slice(0,-4);
 const driver=`${directory}/${name}-${version}.lua`;
 let source="package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\n";
 if(frozen)for(const [module,file]of Object.entries(frozenPurgeQuerySources().files)){
  source+=`assert(package.loaded[${luaString(module)}]==nil,'fresh pinned module');package.preload[${luaString(module)}]=function()return assert(load(${luaString(file.source)},${luaString('@frozena27/'+module+'.lua')},'t'))()end\n`;
 }
 source+=`dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})\n`;
 writeFileSync(driver,source);
 const started=Date.now(),result=runLua(driver);
 writeFileSync(`${directory}/${name}-${version}.stdout.log`,result.stdout);
 writeFileSync(`${directory}/${name}-${version}.stderr.log`,result.stderr);
 writeFileSync(`${directory}/${name}-${version}.result.json`,JSON.stringify({fixture,version,status:result.status,milliseconds:Date.now()-started,bytes:Buffer.byteLength(result.stdout),stdoutSha256:hash(result.stdout),revision:frozen?purgeQueryRevision:null},null,2)+'\n');
 return result;
}

// Existing graph fixture also reports its measured cold module inventory.
// That inventory may shrink; semantic traces and all its graph assertions stay.
export function purgeQueryBehaviorTrace(stdout){
 return stdout.split('\n').filter(line=>!line.startsWith('LIVING_COPY_COLD ')&&!line.startsWith('LIVING_COPY_MODULES ')).join('\n');
}
