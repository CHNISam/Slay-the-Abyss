import {preDefectPlanSource,defectPlanReader} from './defect-plan-source-inverse.mjs';
import {preAct1ChoiceSource,act1ChoiceReader} from './act1-choice-source-inverse.mjs';
// Exact outer epoch for read-only relic queries. Frozen source strings may be
// retained; authorization always comes from a new read of every linked owner.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {preInventoryResponsibilitiesSource,inventoryResponsibilitiesReader} from './inventory-responsibilities-source-inverse.mjs';
import {preM7FinalSource,m7FinalReader} from './m7-core-final-source-inverse.mjs';
import {preWatcherExecutionSource,watcherExecutionReader} from './watcher-final-execution-source-inverse.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const archive=readFileSync(new URL('./relic-query-baseline-391306af.json.gz',import.meta.url));
assert.equal(hash(archive),'df89de0002fee32b9300489b95432ce4287c467435af804f481241ee3c3bbdf2','complete relic query six-source archive');
const bytes=gunzipSync(archive);
assert.equal(hash(bytes),'15e29cde1cb94247da6813ca5a5c0dfe83de48646855913423cd2074671b3127','complete relic query six-source JSON');
const baseline=JSON.parse(bytes);
assert.equal(baseline.schemaVersion,1);assert.equal(baseline.revision,'391306af70d9f5c6fb510223e113fcb7dcb755df');assert.equal(baseline.normalization,'LF');
const after={
 abyss_relic_hooks:'5d929b950824caaa51db1934fd1c7c0fea82ee4a763dc45f63e615d083a7fcfa',
 abyss_uncommon_relics:'8e260bd5c52f8ca90f61281858099afbf98d7ec91a5f82a3c7b8f9e74108093c',
 abyss_rare_relics:'2b05387c8d77ef9818d38a43c2d1b1f9fcd2f69f930db47a919df75744f74788',
 abyss_boss_relics:'07202773300b3808fb154d473769f3c2c1ba9733141b2a6411f20748c88b147e',
 abyss_shop_relics:'4d193801023eb938b4a25878b61c0210ab3023f1133ab395daadbcdf11f810ba',
 abyss_card_pool:'dfc3a89f7df686a677b960430b8ad1be5a8042fcb4ae9a29537659795a2d0f90',
};
assert.deepEqual(Object.keys(baseline.files),Object.keys(after));
const files={};
for(const [name,file]of Object.entries(baseline.files)){
 assert.equal(file.path,'src/lua/'+name+'.lua');assert.equal(hash(file.source),file.sha256,'complete original relic source: '+name);
 assert.equal(normalize(file.source),file.source,'frozen relic source is LF');
 files[file.path]=Object.freeze({beforeSource:file.source,beforeSha256:file.sha256,afterSha256:after[name]});
}
files['src/lua/abyss_relic_queries.lua']=Object.freeze({afterSha256:'a9ede443094115bdf31363d530ac89fa9ab011211ee68bfac866f99e4f2dd214'});
const livingWall=normalize(readFileSync(new URL('./query-living-wall-before.lua',import.meta.url),'utf8'));
assert.equal(hash(livingWall),'6216528eecca0c6e2be5db454a39547b124c3302948f8347ae6535a78328311c','complete original Living Wall source');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(livingWall)+'\0').update(livingWall).digest('hex'),'5afe2f952d7fb29d201afa8b67bc361c59e4dbdf','independent 391 Living Wall Git blob');
files['src/lua/abyss_living_wall.lua']=Object.freeze({beforeSource:livingWall,beforeSha256:'6216528eecca0c6e2be5db454a39547b124c3302948f8347ae6535a78328311c',afterSha256:'9fdf91e1b9ae66511b6c6e80d0e2b250b7245d2077452095c32c8515d281432a'});
files['src/lua/abyss_purge_candidates.lua']=Object.freeze({afterSha256:'a1ab5102f39adf7f44159a45d9611458e67d3ee49a9c8aa6fa50432bee4ca592'});
const runtimeAfter={
 "abyss_actor": "8c65e3f385b412eac28c1ec7d56cac1495e4f91608320af46c2a6c11394be43a",
 "abyss_card_actions": "a89ef438e2f28f366fda05676b0724f5eac59c3447621d1253050b3105424578",
 "abyss_colorless_cards": "16dc66720b2eb4007e61c13f085335bf75ecec6d90728d6b77b3e8a64d3d3a5a",
 "abyss_combat": "74ef6eb1b4c7b18f2d71479af212b23c22758e34c0c8d9eb8e24999ddf825a80",
 "abyss_combat_effect_cards": "ad516e63bfa3528104d42a49bb7e8b5c446c2d0d6e4c855b984bcc524f2733e5",
 "abyss_combat_effect_dispatch": "02fdbcf79108fb702d6e9508a989e12f2eb296e59d8a181ebe3ed80435aa269d",
 "abyss_combat_native_play": "539c3a339016f9497b77f11daed7e0db0378f3e2fcb0923a2ebd39547881c6ec",
 "abyss_combat_queued_play": "ee51b70a7afbb8584b86dfd32477a9a9a29338128393f68a03065dcbd1b62ad7",
 "abyss_defect_engine_cards": "ecfccd24cac9aa6010555d4ac4d2502a75837e2ccfee4dc291aa511b494f76c0",
 "abyss_defect_utility_cards": "e9372f029db58b62e4fff8f4889826607e8d114dcab2cfa00ca4f124fe29f670",
 "abyss_effects_damage": "ae24c9ddd57d7ac2bac8c65d8f1f1768fad750ada74262501b9bad074d03ca41",
 "abyss_end_turn_powers": "0f8881d917f93efb26c7b53f67545c05e6c4f39b43b1694bc3d3d6080173ebda",
 "abyss_exhaust": "a896da79d8206d763a28622ba5544920d14ee9e9b33d6fef9b11d72d8491de48",
 "abyss_hp_loss": "c850a947b868859d6fc522ccf547e76253473f29d4ebe762da0507ec9d9331ed",
 "abyss_inventory": "8fb3dddab386d221c76de49a1ca4b9937a2edbde93511c06ef3810cd71a7557c",
 "abyss_original_v4_health": "ed0efdbcf41527cf87b5e9b53d6afb08d73e3462e7a1528a4f1f4a33008849bd",
 "abyss_player_revive": "735fe7d5b055c5ddd66335b45273e920282cd891c4814e1c13afb9ab0a3b0d92",
 "abyss_potion_fairy": "fe6a3d984f7387ef1f5a52a65e3874634022d9cab86f6b17576a89720607194e",
 "abyss_potion_generation": "3f6c2b85cbc01a77199402cd9bdf5efd943461b42d9883bb7196cd198752b766",
 "abyss_silent_tactics_cards": "8ea7cc9fcd64559b999431997613ae02f394de2eaa6cd04947e2695ff3d48d76",
 "abyss_watcher_final_cards": "343888e746943d3c97608033ac65f52fe02a390c0dba8283b23f18c4a2118018",
 "abyss_watcher_flow_cards": "08c363feb2269edbe1058457f5d7de39c1b1bf7e0b69b5ce05ad834641a961b9",
 "abyss_writhing_mass": "fc362d8be41e3744169067903fc979ad8bc671eda47c754e4c67f8fe6a7d2d4f"
};
function runtime391Sources(){
 const archive=readFileSync(new URL('./relic-lifecycle-baseline-391306af.json.gz',import.meta.url));
 assert.equal(hash(archive),'30c35c0b2298dc33ee3227a5dfc7aa32b5e0959fe11dbe30aef17a5af1ce5067','complete 391 lifecycle source archive');
 const bytes=gunzipSync(archive);assert.equal(hash(bytes),'0c1593569f1b3f849a15ade6981ebb56fe194e9a6b118f12749084d73ac15476','complete 391 lifecycle JSON');
 const corpus=JSON.parse(bytes);assert.equal(corpus.revision,'391306af70d9f5c6fb510223e113fcb7dcb755df');assert.equal(corpus.normalization,'LF');assert.equal(Object.keys(corpus.files).length,329);
 for(const [name,afterSha256]of Object.entries(runtimeAfter)){
  const file=corpus.files[name];assert.equal(file.path,'src/lua/'+name+'.lua');assert.equal(hash(file.source),file.sha256,'complete 391 Runtime source: '+name);assert.equal(normalize(file.source),file.source);
  assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(file.source)+'\0').update(file.source).digest('hex'),file.gitBlob,'391 Runtime Git blob: '+name);
  assert.equal(Object.hasOwn(files,file.path),false,'one source owner per epoch');
  files[file.path]=Object.freeze({beforeSource:file.source,beforeSha256:file.sha256,afterSha256});
 }
}
runtime391Sources();
files['src/lua/abyss_relic_combat_hooks.lua']=Object.freeze({afterSha256:'fda7e14cf4b4704ba30ca79f3fa8b3ed3c933f9d391887227ed463350f8755a9'});
files['src/lua/abyss_relic_family_combat.lua']=Object.freeze({afterSha256:'2e001da46754b81afda1dc592beaf8519a0f308fef65ca47c5779b2ae3607e4c'});
const architectureBytes=normalize(readFileSync(new URL('./relic-lifecycle-architecture-source-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(architectureBytes),'845e211aaf90bc9a4c9d9eca003c9cffd01146400a0eb70ea389a8cadefbd5b2','complete reviewed lifecycle architecture hunks');
const architecture=JSON.parse(architectureBytes);assert.equal(architecture.schemaVersion,1);assert.equal(architecture.revision,'391306af70d9f5c6fb510223e113fcb7dcb755df');assert.equal(architecture.path,'config/architecture.json');
for(const hunk of architecture.hunks){Object.freeze(hunk.before);Object.freeze(hunk.after);Object.freeze(hunk);}Object.freeze(architecture.hunks);Object.freeze(architecture);
files[architecture.path]=Object.freeze({beforeSha256:architecture.beforeSha256,beforeGitBlob:architecture.beforeGitBlob,afterSha256:architecture.afterSha256,afterTokenSha256:architecture.afterTokenSha256});
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
 let extractionRaw=rawReaders.get(readSource)??readSource;
 source=preDefectPlanSource(path,source,{readSource:extractionRaw});
 extractionRaw=defectPlanReader(extractionRaw);
 source=preAct1ChoiceSource(path,source,{readSource:extractionRaw});
 extractionRaw=act1ChoiceReader(extractionRaw);
 source=preInventoryResponsibilitiesSource(path,source,{readSource:extractionRaw});
 source=preWatcherExecutionSource(path,source,{readSource:extractionRaw});
 readSource=watcherExecutionReader(inventoryResponsibilitiesReader(extractionRaw));
 readSource=m7FinalReader(rawReaders.get(readSource)??readSource);
 source=preM7FinalSource(path,source,{readSource});
 if(!Object.hasOwn(files[path]??{},'beforeSha256')||!inputIdentity(path,source))return source;
 assert.equal(typeof readSource,'function','relic query linked reader must be a function');
 readSource=m7FinalReader(rawReaders.get(readSource)??readSource);
 let liveConfiguration;
 for(const linked of Object.keys(files)){
  let current;try{current=readSource(linked);}catch(error){assert.fail('relic query linked owner missing: '+linked+': '+String(error?.message??error));}
  assert.ok(identity(linked,current),'relic query linked owner identity: '+linked);
  if(linked==='config/architecture.json')liveConfiguration=current;
 }
 if(path!=='config/architecture.json')return files[path].beforeSource;
 const lines=normalize(liveConfiguration).split('\n');
 for(const hunk of [...architecture.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact complete lifecycle architecture hunk');
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),files[path].beforeSha256,'complete original relic query architecture');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),files[path].beforeGitBlob,'independent 391 architecture Git blob');
 return previous;
}
export function relicQueryReader(readSource=readLive){
 assert.equal(typeof readSource,'function','relic query linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preRelicQuerySource(path,readSource(path),{readSource});rawReaders.set(reader,readSource);return reader;
}
