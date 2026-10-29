import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {projectRunMaxHpConfig,preRunMaxHpConfig} from './helpers/run-max-hp-config-inverse.mjs';
import {projectNodesBattleMaxHpConfig} from './helpers/nodes-battle-max-hp-config-inverse.mjs';
import {preCoreArchitectureSource} from './helpers/core-architecture-inverse.mjs';
import {preIntegratedNodeUiSource} from './helpers/approved-node-ui-refactor.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
const path='config/architecture.json';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const expected={live:'3476d3d6407f1a64c194add9937c48da1eb2ce6ba98cc90617feb3751aeb9c44',combined:'df2d58668d69864a61e3d177c8ab4183cedd11fb12bdb6f9e14312b008bf6f9b',run:'bc1a6dca0701091f73a8464de978a4b202597c70500c84c73f33a855a510240e'};
const run=['abyss_run_initialization','abyss_run_transition','abyss_run_rooms','abyss_run_settlement','abyss_run_potions'];
const nodes=['abyss_nodes_common','abyss_nodes_entry','abyss_nodes_events','abyss_nodes_sources'];
const battle=['abyss_battle_actions','abyss_battle_action_bindings','abyss_battle_card_bindings','abyss_battle_card_gestures','abyss_battle_card_layout','abyss_battle_details','abyss_battle_detail_bindings','abyss_battle_input_state','abyss_battle_potion_bindings','abyss_battle_render','abyss_battle_render_actors','abyss_battle_render_hud','abyss_battle_render_state','abyss_battle_targeting','abyss_battle_target_bindings'];
const additions=['abyss_max_hp_relics',...battle,...nodes,...run];
const project=(source,target)=>projectRunMaxHpConfig(path,source,target);

test('a historical projection cannot hide a missing MaxHP registration from the current production architecture gate',()=>{
 const sources=Object.fromEntries(readdirSync('src/lua').filter(file=>file.endsWith('.lua')).sort().map(file=>[file.slice(0,-4),read('src/lua/'+file)]));
 const live=JSON.parse(read(path));
 assert.deepEqual(analyzeSources(sources,live).errors,[]);
 const missing=structuredClone(live);delete missing.layers.abyss_max_hp_relics;
 assert.ok(analyzeSources(sources,missing).errors.some(error=>error.file==='src/lua/abyss_max_hp_relics.lua'&&error.message==='Module needs explicit classification'));
});

test('current union retains literal accepted Run config plus only MaxHP and the complete prior reviewed triple config',()=>{
 const source=read(path);assert.equal(hash(source),expected.live);
 const combined=project(source,'combined'),acceptedRun=project(source,'run');
 assert.equal(hash(combined),expected.combined);assert.equal(hash(acceptedRun),expected.run);
 const live=JSON.parse(source),previous=JSON.parse(combined),accepted=JSON.parse(acceptedRun);
 assert.deepEqual(Object.keys(live.layers),[...Object.keys(previous.layers),...run]);
 for(const target of [previous,accepted]){
  assert.deepEqual({...live,layers:null},{...target,layers:null});
  for(const [name,layer]of Object.entries(target.layers))assert.equal(live.layers[name],layer);
 }
 assert.deepEqual(Object.keys(live.layers).filter(name=>!Object.hasOwn(accepted.layers,name)),['abyss_max_hp_relics']);
 for(const name of [...run,...nodes,'abyss_max_hp_relics'])assert.equal(live.layers[name],'core');
 for(const name of battle)assert.equal(live.layers[name],'ui');
});

test('exact Run outer layer composes both unchanged inner complete-source proofs and preserves their old witnesses',()=>{
 const source=read(path),combined=project(source,'combined'),acceptedRun=project(source,'run');
 assert.throws(()=>projectNodesBattleMaxHpConfig(path,source,'nodes'),/unreviewed combined Nodes Battle Max HP/);
 assert.throws(()=>preCoreArchitectureSource(path,source),/unreviewed integrated core registration base/);
 for(const target of ['combined','run']){
  const projected=project(source,target);
  assert.equal(project(source.replaceAll('\n','\r\n'),target),projected);
  assert.equal(preRunMaxHpConfig(path,source,target),projected);
  assert.equal(preRunMaxHpConfig(path,projected,target),projected);
 }
 for(const witness of [source,source.replaceAll('\n','\r\n'),combined,acceptedRun]){
  assert.equal(preIntegratedNodeUiSource(path,witness),preIntegratedNodeUiSource(path,combined));
  assert.equal(preApprovedUiSource(path,witness),preApprovedUiSource(path,combined));
 }
});

test('all twenty-five live additive registrations reject missing duplicate renamed wrong-layer and cross-scope drift',()=>{
 const source=read(path),lines=source.split('\n'),mutants=[];
 for(const name of additions){
  const line=lines.find(line=>line.includes(`"${name}":`));assert.ok(line,name);
  mutants.push(source.replace(line+'\n',''),source.replace(line+'\n',line+'\n'+line+'\n'),source.replace(`"${name}":`,`"${name}_unknown":`),source.replace(line,line.replace(/: "(core|ui)"/,(_,layer)=>`: "${layer==='core'?'ui':'core'}"`)));
 }
 const first='    "abyss_run_initialization": "core",\n',next='    "abyss_run_transition": "core",\n';
 mutants.push(source+'\n',source.replace(first+next,next+first),source.replace(first,'').replace('  "layers": {\n','  "layers": {\n'+first),source.replace('"abyss_run_potions": "core"','"abyss_run_potions": "core",\n    "unknown": "core"'),source.replace('"dynamicExceptions": []','"dynamicExceptions": ["unknown"]'),source.replace('"abyss_run_potion_candidate": "core"','"abyss_run_potion_candidate": "ui"'),source.replace('"reason": "Potion/upgrade/HP','"reason": "unreviewed Potion/upgrade/HP'));
 let acceptedBaselineWitnesses=0;
 for(const mutant of mutants){
  assert.notEqual(mutant,source);
  for(const target of ['combined','run']){
   assert.throws(()=>project(mutant,target),/unreviewed combined Run Max HP/);
   assert.equal(preRunMaxHpConfig(path,mutant,target),mutant,'unmatched complete bytes remain visible to the original guards');
  }
  if(hash(mutant)===expected.run){
   acceptedBaselineWitnesses++;
   assert.equal(mutant,project(source,'run'),'only literal accepted58f config, not a partial or wildcard exemption');
   assert.equal(preIntegratedNodeUiSource(path,mutant),preIntegratedNodeUiSource(path,source));
   assert.equal(preApprovedUiSource(path,mutant),preApprovedUiSource(path,source));
  }else{
   assert.throws(()=>preIntegratedNodeUiSource(path,mutant),/unreviewed integrated/);
   assert.throws(()=>preApprovedUiSource(path,mutant),/unreviewed integrated/);
  }
 }
 assert.equal(acceptedBaselineWitnesses,1);
 assert.equal(mutants.length,107);
});

test('explicit Run proof rejects missing source wrong path unknown target and preserves all frozen prior witnesses',()=>{
 const source=read(path);
 for(const missing of [null,undefined,''])assert.throws(()=>project(missing,'combined'),/combined Run Max HP/);
 for(const wrongPath of ['config/other.json','data/presentation/ui_theme.json','src/lua/abyss_run.lua']){
  assert.throws(()=>projectRunMaxHpConfig(wrongPath,source,'run'),/combined Run Max HP path/);
  assert.equal(preRunMaxHpConfig(wrongPath,source),source);
 }
 assert.throws(()=>project(source,'unknown'),/combined Run Max HP target/);
 const frozen=[['tests/fixtures/nodes-battle-max-hp-config-inverse.json','5e130a11180cb03714f315a21f5cf90a722374c2833dda033529851ad2809b92'],['tests/fixtures/battle-max-hp-config-inverse.json','79bca8cc4391e1906049dd815dd143267894f37425253ca6ac9a836d7aa21456']];
 for(const [file,expectedHash]of frozen)assert.equal(hash(read(file)),expectedHash);
});
