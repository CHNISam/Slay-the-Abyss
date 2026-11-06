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
 abyss_boss_relics:'e4f1ec9a134300c4ac229a2da097c4a65c0b6872aec75ce283f6924a7ce26b67',
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
const livingWall=normalize(readFileSync(new URL('./query-living-wall-before.lua',import.meta.url),'utf8'));
assert.equal(hash(livingWall),'6216528eecca0c6e2be5db454a39547b124c3302948f8347ae6535a78328311c','complete original Living Wall source');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(livingWall)+'\0').update(livingWall).digest('hex'),'5afe2f952d7fb29d201afa8b67bc361c59e4dbdf','independent 391 Living Wall Git blob');
files['src/lua/abyss_living_wall.lua']=Object.freeze({beforeSource:livingWall,beforeSha256:'6216528eecca0c6e2be5db454a39547b124c3302948f8347ae6535a78328311c',afterSha256:'9fdf91e1b9ae66511b6c6e80d0e2b250b7245d2077452095c32c8515d281432a'});
files['src/lua/abyss_purge_candidates.lua']=Object.freeze({afterSha256:'a1ab5102f39adf7f44159a45d9611458e67d3ee49a9c8aa6fa50432bee4ca592'});
files['config/architecture.json']=Object.freeze({
 beforeSha256:'68d46e73d734f9684326b24ba040706d768349ce9a552daf52006bb900bfaabf',
 beforeGitBlob:'ad1880710f0b186d3532517d8f51496622141963',
 afterSha256:'fd60eede4377f9304db969adfae6b719ca4bba7772fc27454755d5dd73c575e3',
 afterTokenSha256:'73dec8066c26216229e6d4c5ef756fc067c8f5b58ebeb97bb13aac8e18d12236',
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
 const purgeRegistration='    "abyss_purge_candidates": "core",\n';
 const queryBoundary='    {\n      "id": "relic-query-independence",\n      "from": ["abyss_relic_queries"],\n      "forbiddenTargets": ["abyss_relic_hooks", "abyss_uncommon_relics", "abyss_rare_relics", "abyss_boss_relics", "abyss_shop_relics", "abyss_actor", "abyss_combat", "abyss_run", "abyss_card_actions"],\n      "reason": "Read-only relic identity and reward counts cannot load execution or state owners."\n    },\n';
 const cardPoolBoundary='    {\n      "id": "card-pool-read-queries",\n      "from": ["abyss_card_pool"],\n      "forbiddenTargets": ["abyss_relic_hooks", "abyss_uncommon_relics", "abyss_rare_relics", "abyss_boss_relics", "abyss_shop_relics"],\n      "reason": "Card reward selection reads relic queries without importing mixed execution facades."\n    },\n';
 const purgeBoundary='    {\n      "id": "purge-candidate-independence",\n      "from": ["abyss_purge_candidates"],\n      "forbiddenTargets": ["abyss_living_wall", "abyss_boss_relics", "abyss_run", "abyss_actor", "abyss_combat", "abyss_transform_card", "abyss_card_capability", "abyss_event_transform_context"],\n      "reason": "Permanent card candidates only copy legal rows; execution and state owners remain outside the query."\n    },\n';
 const bossBoundary='    {\n      "id": "boss-purge-query",\n      "from": ["abyss_boss_relics"],\n      "forbiddenTargets": ["abyss_living_wall"],\n      "reason": "Boss selection reads permanent card candidates without importing Living Wall event execution."\n    },\n';
 for(const delta of [registration,purgeRegistration,queryBoundary,cardPoolBoundary,purgeBoundary,bossBoundary]){
  assert.equal(previous.split(delta).length,2,'one complete relic query architecture delta');previous=previous.replace(delta,'');
 }
 const deferredReason='Relic callbacks load the already initialized runtime only when an actual obtain, choice, damage or card action executes; no module initialization import.';
 const deferredAnchor='{"from":"abyss_boss_relics","to":"abyss_build_actions","reason":"'+deferredReason+'"},\n';
 const livingWallDeferred='{"from":"abyss_boss_relics","to":"abyss_living_wall","reason":"'+deferredReason+'"},\n';
 assert.equal(previous.split(deferredAnchor).length,2,'one exact original Boss deferred insertion point');
 assert.equal(previous.includes(livingWallDeferred),false,'the final query epoch removed the old Boss event dependency');
 previous=previous.replace(deferredAnchor,deferredAnchor+livingWallDeferred);
 assert.equal(hash(previous),files[path].beforeSha256,'complete original relic query architecture');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),files[path].beforeGitBlob,'independent 391 architecture Git blob');
 return previous;
}
export function relicQueryReader(readSource=readLive){
 assert.equal(typeof readSource,'function','relic query linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preRelicQuerySource(path,readSource(path),{readSource});rawReaders.set(reader,readSource);return reader;
}
