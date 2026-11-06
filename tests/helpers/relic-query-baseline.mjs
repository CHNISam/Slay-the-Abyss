import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
import {frozenRelicLifecycleSources,relicLifecycleFrozenPrelude} from './relic-lifecycle-baseline.mjs';

export const relicQueryRevision='391306af70d9f5c6fb510223e113fcb7dcb755df';
export const relicQueryArchiveSha256='df89de0002fee32b9300489b95432ce4287c467435af804f481241ee3c3bbdf2';
export const relicQueryJsonSha256='15e29cde1cb94247da6813ca5a5c0dfe83de48646855913423cd2074671b3127';
const hash=value=>createHash('sha256').update(value).digest('hex');
const modules=['abyss_relic_hooks','abyss_uncommon_relics','abyss_rare_relics','abyss_boss_relics','abyss_shop_relics','abyss_card_pool'];
export function frozenRelicQuerySources(){
 const archive=readFileSync(new URL('./relic-query-baseline-391306af.json.gz',import.meta.url));
 assert.equal(hash(archive),relicQueryArchiveSha256,'complete six-source compressed witness');
 const bytes=gunzipSync(archive);
 assert.equal(hash(bytes),relicQueryJsonSha256,'complete six-source LF JSON witness');
 const proof=JSON.parse(bytes);
 assert.equal(proof.schemaVersion,1);assert.equal(proof.revision,relicQueryRevision);assert.equal(proof.normalization,'LF');
 assert.deepEqual(Object.keys(proof.files),modules,'exact frozen source inventory');
 for(const [name,file]of Object.entries(proof.files)){
  assert.equal(file.path,`src/lua/${name}.lua`);assert(!file.source.includes('\r'),'LF frozen source');
  assert.equal(hash(file.source),file.sha256,`complete source identity: ${name}`);
 }
 return proof;
}

// Each call delegates to the unchanged 30-second/1-MiB runner in a fresh process.
// The original six-source proof remains immutable; execution uses the complete
// matching epoch so new runtime capabilities cannot leak into the old VM.
export function runRelicQueryFixture(fixture,{frozen=false}={}){
 assert.match(fixture,/^tests\/lua\/relic_query_[a-z_]+\.lua$/);
 const directory='build/relic-query-baseline';mkdirSync(directory,{recursive:true});
 const version=frozen?'frozen391':'current',name=fixture.split('/').at(-1).slice(0,-4);
 const driver=`${directory}/${name}-${version}.lua`;
 let source="package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\n";
 if(frozen){
  const corpus=frozenRelicLifecycleSources();
  for(const [module,file]of Object.entries(frozenRelicQuerySources().files))
   assert.equal(corpus.files[module].source,file.source,'original six-source proof agrees with complete 391 execution epoch');
  source+=relicLifecycleFrozenPrelude();
  source+=`assert(RELIC_LIFECYCLE_FROZEN.revision==${luaString(relicQueryRevision)})\n`;
 }
 source+=`dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})\n`;
 if(frozen)source+='assert(RELIC_LIFECYCLE_FROZEN.audit())\n';
 writeFileSync(driver,source);
 const started=Date.now(),result=runLua(driver);
 writeFileSync(`${directory}/${name}-${version}.stdout.log`,result.stdout);
 writeFileSync(`${directory}/${name}-${version}.stderr.log`,result.stderr);
 writeFileSync(`${directory}/${name}-${version}.result.json`,JSON.stringify({fixture,version,status:result.status,milliseconds:Date.now()-started,bytes:Buffer.byteLength(result.stdout),stdoutSha256:hash(result.stdout),revision:frozen?relicQueryRevision:null},null,2)+'\n');
 return result;
}
