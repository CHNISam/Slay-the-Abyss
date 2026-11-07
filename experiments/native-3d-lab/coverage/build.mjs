import {readFileSync,writeFileSync,readdirSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {proposalFor,assignmentIds,phases} from './mapping.mjs';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../../..');
const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const definitions=['abyss_event_combat_enemies','abyss_act1_bosses','abyss_act2_enemies','abyss_act3_enemies','abyss_act3_bosses','abyss_awakened_one','abyss_reptomancer','abyss_darklings','abyss_spire_pair','abyss_corrupt_heart','abyss_giant_head','abyss_nemesis','abyss_time_eater','abyss_writhing_mass'];
const base=read(join(root,'data/enemies.json'));
const catalog=JSON.parse(JSON.stringify(read(join(toolRoot,'src/scene/asset-catalog.json'))));
const assets=new Map(catalog.assets.map(a=>[a.id,a]));
const animations=read(join(toolRoot,'src/scene/media/creature-animations.json'));
const existingBindings=read(join(root,'data/presentation/native-monster-art.json')).bindings;
const raw=execFileSync(process.execPath,[join(root,'node_modules/fengari-node-cli/src/lua-cli.js'),join(here,'catalog.lua')],{cwd:root,encoding:'utf8',timeout:30000});
if(raw.includes('stack traceback:')||raw.includes('error:'))throw Error('Lua catalog audit failed: '+raw.slice(-300));
const records=raw.trim().split(/\r?\n/).map(line=>{const [id,name,tier,aiKind,aiPolicy,sourceId,hp]=line.split('\t');return {id,name,tier,aiKind,aiPolicy,sourceId,hp:Number(hp)}});
if(records.length!==assignmentIds.length||new Set(records.map(r=>r.id)).size!==records.length||assignmentIds.some(id=>!records.some(r=>r.id===id)))throw Error('Coverage must match the actual full registration catalog exactly');
function sourceFor(id){
 if(base.enemies.some(e=>e.id===id))return 'data/enemies.json';
 for(const name of definitions){const path='src/lua/'+name+'.lua',text=readFileSync(join(root,path),'utf8');const escaped=id.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');if(new RegExp("\\bid\\s*=\\s*'"+escaped+"'\\s*,(?:sourceId\\s*=\\s*'[^']+'\\s*,)?name\\s*=").test(text))return path;}
 throw Error('Missing definition evidence: '+id);
}
function actsFor(r,path){
 if(path.includes('act4')||path.includes('spire_pair')||path.includes('corrupt_heart'))return [4];
 if(path.includes('act2'))return [2];
 if(path.includes('event_combat'))return r.id==='lagavulin_awake'?[1]:[2];
 if(path.includes('act3')||['awakened_one','reptomancer','snake_dagger','darkling','giant_head','nemesis','time_eater','writhing_mass'].includes(r.id))return [3];
 const shared={cultist:[1,2,3],looter:[1,2],fungi_beast:[1,2],sentry:[1,2],blue_slaver:[1,2],red_slaver:[1,2],mad_gremlin:[1,2],sneaky_gremlin:[1,2],fat_gremlin:[1,2],shield_gremlin:[1,2],wizard_gremlin:[1,2]};
 return shared[r.id]??[1];
}
const rows=records.map(r=>{
 const definitionSource=sourceFor(r.id),p=proposalFor(r.id),asset=p.assetId&&assets.get(p.assetId);
 if(p.assetId&&!asset)throw Error('Invented asset ID '+p.assetId);
 const known=p.assetId&&animations.creatures[String(p.assetId)];
 const existing=existingBindings[r.id]??null;
 return {...r,internalId:r.id,acts:actsFor(r,definitionSource),definitionSource,...p,officialAssetName:asset?.name??null,
  assetGroup:asset?.group??null,animationListRead:Boolean(known),knownAnimationCount:known?.length??0,
  knownAnimationKinds:known?.filter(x=>/待机|攻击|受击|战败|死亡/.test(x[1])).map(x=>({id:x[0],name:x[1]}))??[],
  recommendationStatus:p.strategy==='keep-shapes'?'recommended':known?'recommended':'structural-only',
  runtimeStatus:'runtime-unverified',existing2DRegistryBinding:existing,
  displayNamePolicy:'suggestion-only; do not change gameplay name/ID/references without explicit presentation binding',
  ruleMutation:false};
});
const groupCounts={};for(const r of rows)groupCounts[r.reuseGroup]=(groupCounts[r.reuseGroup]??0)+1;
const phaseSources=[...new Set(phases.map(p=>p.source))];
const summary={schemaVersion:1,denominator:rows.length,denominatorContract:'unique registered enemy definition IDs across full-source Combat catalog; runtime suffixes and duplicate encounter instances are not new definitions',
 phaseDefinitions:phases.length,phaseStates:phases.reduce((n,p)=>n+p.states.length,0),
 nativeModelCandidates:rows.filter(r=>r.strategy==='native-model').length,keepShapes:rows.filter(r=>r.strategy==='keep-shapes').length,
 readAnimationCandidates:rows.filter(r=>r.assetId&&r.animationListRead).length,structuralOnly:rows.filter(r=>r.recommendationStatus==='structural-only').length,
 officiallyValidatedCoverage:0,runtimeStatus:'runtime-unverified',groupCounts,
 limitations:['asset catalogue presence is not spawnability or controllable animation proof','known lists are editor-read metadata, not verification of every clip','shape recommendations remain existing simple presentation; no custom rig is proposed','current milestone competition scope remains two acts; this is isolated full-source research'],
 sources:[...new Set(['data/enemies.json','src/lua/abyss_combat_enemy_setup.lua',...definitions.map(n=>'src/lua/'+n+'.lua'),...phaseSources])].map(path=>({path,sha256:hash(join(root,path))})),
 toolSources:['src/scene/asset-catalog.json','src/scene/media/creature-animations.json'].map(path=>({path,sha256:hash(join(toolRoot,path))})),
 generatedBy:'node experiments/native-3d-lab/coverage/build.mjs'};
summary.counts={registeredDefinitions:rows.length,nativeModelCandidates:summary.nativeModelCandidates,keepShapes:summary.keepShapes,
 uniqueNativeAssets:new Set(rows.filter(r=>r.assetId).map(r=>r.assetId)).size,
 uniqueAssetsWithReadAnimations:new Set(rows.filter(r=>r.assetId&&r.animationListRead).map(r=>r.assetId)).size,
 phaseDefinitions:phases.length,phaseStates:summary.phaseStates,
 definitionOriginByAct:Object.fromEntries([1,2,3,4].map(act=>[act,rows.filter(r=>r.acts[0]===act).length]))};
summary.method={registration:'Catalog.prepare(data) + Catalog.enemies(data) + Combat EnemySetup.register(catalog)',
 deduplication:'exact registered definition ID set; assignment set must equal live Lua catalogue set',
 phases:'explicit same-ID state appendix; descendants with separate IDs already in primary denominator',
 recommendations:'presentation-only proposal; catalogue lookup and metadata presence are never runtime verification'};
summary.provenance={sourceCommit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
 catalogData:{path:'build/lua/abyss_data.lua',sha256:hash(join(root,'build/lua/abyss_data.lua'))},
 luaEnumeration:{path:'experiments/native-3d-lab/coverage/catalog.lua',sha256:hash(join(here,'catalog.lua'))},
 mapping:{path:'experiments/native-3d-lab/coverage/mapping.mjs',sha256:hash(join(here,'mapping.mjs'))}};
writeFileSync(join(here,'catalog.tsv'),raw);
writeFileSync(join(here,'enemy-coverage.json'),JSON.stringify({summary,enemies:rows,phases},null,2)+'\n');
const columns=['internalId','name','acts','definitionSource','tier','strategy','reuseGroup','assetId','officialAssetName','scale','animationListRead','knownAnimationCount','recommendationStatus','runtimeStatus','fallbackAssetId','reason'];
const cell=v=>'"'+String(Array.isArray(v)?v.join('|'):v??'').replaceAll('"','""')+'"';
writeFileSync(join(here,'enemy-coverage.csv'),columns.join(',')+'\n'+rows.map(r=>columns.map(k=>cell(r[k])).join(',')).join('\n')+'\n');
writeFileSync(join(here,'phase-coverage.csv'),['internalId,states,source,presentation',...phases.map(p=>[p.enemyId,p.states,p.source,p.presentation].map(cell).join(','))].join('\n')+'\n');
console.log(JSON.stringify({denominator:summary.denominator,nativeModelCandidates:summary.nativeModelCandidates,keepShapes:summary.keepShapes,readAnimationCandidates:summary.readAnimationCandidates,structuralOnly:summary.structuralOnly,phaseDefinitions:summary.phaseDefinitions}));
