// Exact outer epoch for read-only relic queries. Frozen source strings may be
// retained; authorization always comes from a new read of every linked owner.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const archive=readFileSync(new URL('./relic-query-baseline-391306af.json.gz',import.meta.url));
assert.equal(hash(archive),'df89de0002fee32b9300489b95432ce4287c467435af804f481241ee3c3bbdf2','complete relic query six-source archive');
const bytes=gunzipSync(archive);
assert.equal(hash(bytes),'15e29cde1cb94247da6813ca5a5c0dfe83de48646855913423cd2074671b3127','complete relic query six-source JSON');
const baseline=JSON.parse(bytes);
assert.equal(baseline.schemaVersion,1);assert.equal(baseline.revision,'391306af70d9f5c6fb510223e113fcb7dcb755df');assert.equal(baseline.normalization,'LF');
const after={
 abyss_relic_hooks:'c3bc73e73d7b835fac49d42b12ac199f243fd76f6c2988a3d9d147759c96911f',
 abyss_uncommon_relics:'1b86859b174c9c6986fe26a3bc98281321bd8a4446a879193ca35cb7952f1d20',
 abyss_rare_relics:'01364ecb3eed3e3da82f3a4606a3ca2f759496d3c2c04cf8d1773fb2c4903330',
 abyss_boss_relics:'652915c305681443034bc618963bd6bbedc128c6b40516d32ea681a0ac8048b1',
 abyss_shop_relics:'058568afbf864bf8ad4d90ff7c9de10d129193dd7edabff39805181721097281',
 abyss_card_pool:'dfc3a89f7df686a677b960430b8ad1be5a8042fcb4ae9a29537659795a2d0f90',
};
assert.deepEqual(Object.keys(baseline.files),Object.keys(after));
const files={};
for(const [name,file]of Object.entries(baseline.files)){
 assert.equal(file.path,'src/lua/'+name+'.lua');assert.equal(hash(file.source),file.sha256,'complete original relic source: '+name);
 assert.equal(normalize(file.source),file.source,'frozen relic source is LF');
 files[file.path]=Object.freeze({beforeSource:file.source,beforeSha256:file.sha256,afterSha256:after[name]});
}
files['src/lua/abyss_relic_queries.lua']=Object.freeze({afterSha256:'c0f79cbc6c37dc66df34a2d0ee0e3e45b813a20caec6524a196cb42880a8dedd'});
files['config/architecture.json']=Object.freeze({
 beforeSha256:'68d46e73d734f9684326b24ba040706d768349ce9a552daf52006bb900bfaabf',
 beforeGitBlob:'ad1880710f0b186d3532517d8f51496622141963',
 afterSha256:'aa03240ef422e3ba71cde0b713b57d08f750348c33e1a1f0d81edaea56dcc3db',
 afterTokenSha256:'f4cf3be2d29ce51f729eac4869d10aed31e2ff37bd1214c6213b32c9826a1eae',
});
export const relicQuerySourceProof=Object.freeze({files:Object.freeze(files)});
const readLive=p=>readFileSync(p,'utf8'),rawReaders=new WeakMap();
const identity=(path,source)=>typeof source==='string'&&Object.hasOwn(files,path)&&hash(normalize(source))===files[path].afterSha256;
const tokens=s=>s.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,t=>t.startsWith('"')?t:'');
function inputIdentity(path,source){
 if(identity(path,source))return true;
 if(path!=='config/architecture.json'||typeof source!=='string'||!source.includes('"abyss_relic_queries"'))return false;
 try{
  const formatted=JSON.stringify(JSON.parse(source),null,2)+'\n';
  return tokens(source)===tokens(formatted)&&hash(formatted)===files[path].afterTokenSha256;
 }catch{return false;}
}
export function preRelicQuerySource(path,source,{readSource=readLive}={}){
 if(!Object.hasOwn(files[path]??{},'beforeSha256')||!inputIdentity(path,source))return source;
 assert.equal(typeof readSource,'function','relic query linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 let liveConfiguration;
 for(const linked of Object.keys(files)){
  let current;try{current=readSource(linked);}catch(error){assert.fail('relic query linked owner missing: '+linked+': '+String(error?.message??error));}
  assert.ok(identity(linked,current),'relic query linked owner identity: '+linked);
  if(linked==='config/architecture.json')liveConfiguration=current;
 }
 if(path!=='config/architecture.json')return files[path].beforeSource;
 let previous=normalize(liveConfiguration);
 const registration='    "abyss_relic_queries": "core",\n';
 const queryBoundary='    {\n      "id": "relic-query-independence",\n      "from": ["abyss_relic_queries"],\n      "forbiddenTargets": ["abyss_relic_hooks", "abyss_uncommon_relics", "abyss_rare_relics", "abyss_boss_relics", "abyss_shop_relics", "abyss_actor", "abyss_combat", "abyss_run", "abyss_card_actions"],\n      "reason": "Read-only relic identity and reward counts cannot load execution or state owners."\n    },\n';
 const cardPoolBoundary='    {\n      "id": "card-pool-read-queries",\n      "from": ["abyss_card_pool"],\n      "forbiddenTargets": ["abyss_relic_hooks", "abyss_uncommon_relics", "abyss_rare_relics", "abyss_boss_relics", "abyss_shop_relics"],\n      "reason": "Card reward selection reads relic queries without importing mixed execution facades."\n    },\n';
 for(const delta of [registration,queryBoundary,cardPoolBoundary]){
  assert.equal(previous.split(delta).length,2,'one complete relic query architecture delta');previous=previous.replace(delta,'');
 }
 assert.equal(hash(previous),files[path].beforeSha256,'complete original relic query architecture');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),files[path].beforeGitBlob,'independent 391 architecture Git blob');
 return previous;
}
export function relicQueryReader(readSource=readLive){
 assert.equal(typeof readSource,'function','relic query linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preRelicQuerySource(path,readSource(path),{readSource});rawReaders.set(reader,readSource);return reader;
}
