import {preRunMaxHpConfig} from './helpers/run-max-hp-config-inverse.mjs';
import {preRosterConfigSource} from './helpers/competition-roster-config-composition.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {projectNodesBattleMaxHpConfig,preNodesBattleMaxHpConfig,projectHistoricalNodesBattleMaxHpConfig,preHistoricalNodesBattleMaxHpConfig} from './helpers/nodes-battle-max-hp-config-inverse.mjs';
import {projectBattleMaxHpConfig} from './helpers/battle-max-hp-config-inverse.mjs';
import {preCoreArchitectureSource} from './helpers/core-architecture-inverse.mjs';
import {preIntegratedNodeUiSource} from './helpers/approved-node-ui-refactor.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
const path='config/architecture.json';
const read=p=>preRunMaxHpConfig(p,preRosterConfigSource(p,readFileSync(p,'utf8').replaceAll('\r\n','\n')));
const hash=s=>createHash('sha256').update(s).digest('hex');
const expected={combined:'df2d58668d69864a61e3d177c8ab4183cedd11fb12bdb6f9e14312b008bf6f9b',candidate:'2cca90fbe128e36911e5a810ac45a63ad7612e99198a4613742c6a47c77d1ddc',nodes:'4c98aac4741ad87a2465dfec893022801ea42d19f9895cc3969cea4ebb8addbc',base:'0c15a29fa24a4284eb0760b750356b658eb02e28b71d23b46839520777222cdb'};
const nodes=['abyss_nodes_common','abyss_nodes_entry','abyss_nodes_events','abyss_nodes_sources'];
const battle=['abyss_battle_actions','abyss_battle_action_bindings','abyss_battle_card_bindings','abyss_battle_card_gestures','abyss_battle_card_layout','abyss_battle_details','abyss_battle_detail_bindings','abyss_battle_input_state','abyss_battle_potion_bindings','abyss_battle_render','abyss_battle_render_actors','abyss_battle_render_hud','abyss_battle_render_state','abyss_battle_targeting','abyss_battle_target_bindings'];
const maxHp=['abyss_max_hp_relics'];
const project=(source,target)=>projectHistoricalNodesBattleMaxHpConfig(path,source,target);

test('triple config retains every prior classification and unrelated field while adding only the exact reviewed registrations',()=>{
 const source=read(path);assert.equal(hash(source),expected.combined);
 const candidate=project(source,'candidate'),onlyNodes=project(source,'nodes');
 assert.equal(hash(candidate),expected.candidate);assert.equal(hash(onlyNodes),expected.nodes);
 const live=JSON.parse(source),targets={candidate:JSON.parse(candidate),nodes:JSON.parse(onlyNodes)};
 assert.deepEqual(Object.keys(live.layers),[...Object.keys(targets.candidate.layers),...nodes],'the whole prior candidate order and the exact Nodes tail remain');
 for(const [target,previous]of Object.entries(targets)){
  assert.deepEqual({...live,layers:null},{...previous,layers:null},'no unrelated architecture field changes: '+target);
  for(const [name,layer]of Object.entries(previous.layers))assert.equal(live.layers[name],layer,'prior classification remains: '+name);
  assert.deepEqual(Object.keys(live.layers).filter(name=>!Object.hasOwn(previous.layers,name)),target==='candidate'?nodes:[...maxHp,...battle]);
 }
 for(const name of [...nodes,...maxHp])assert.equal(live.layers[name],'core');
 for(const name of battle)assert.equal(live.layers[name],'ui');
});

test('exact outer proof composes both unchanged inner identities and leaves older complete witnesses usable',()=>{
 const source=read(path),candidate=project(source,'candidate'),onlyNodes=project(source,'nodes');
 assert.equal(projectNodesBattleMaxHpConfig(path,source,'candidate'),candidate,'public composition reaches the same historical inverse');
 assert.equal(preNodesBattleMaxHpConfig(path,preRosterConfigSource(path,readFileSync(path,'utf8'))),candidate,'current production source still bridges through the roster owner to the frozen candidate');
 // The old helpers stay strict: neither owns or accepts the raw triple union.
 assert.throws(()=>projectBattleMaxHpConfig(path,source,'maxHp'),/unreviewed combined Battle Max HP/);
 assert.throws(()=>preCoreArchitectureSource(path,source),/unreviewed integrated core registration base/);
 assert.equal(hash(preCoreArchitectureSource(path,onlyNodes)),expected.base);
 for(const [name,target]of [['candidate',candidate],['nodes',onlyNodes]]){
  assert.equal(project(source.replaceAll('\n','\r\n'),name),target);
  assert.equal(preHistoricalNodesBattleMaxHpConfig(path,source,name),target);
  assert.equal(preHistoricalNodesBattleMaxHpConfig(path,source.replaceAll('\n','\r\n'),name),target);
  assert.equal(preHistoricalNodesBattleMaxHpConfig(path,target,name),target);
 }
 assert.equal(preHistoricalNodesBattleMaxHpConfig(path,source),candidate);
 assert.equal(preHistoricalNodesBattleMaxHpConfig('other.json',source),source);
 const ui=preIntegratedNodeUiSource(path,candidate),approved=preApprovedUiSource(path,candidate);
 for(const witness of [source,source.replaceAll('\n','\r\n'),onlyNodes]){
  assert.equal(preIntegratedNodeUiSource(path,witness),ui);
  assert.equal(preApprovedUiSource(path,witness),approved);
 }
});

test('all live registration classes reject partial duplicate renamed wrong-layer reordered and unrelated drift before the old guards',()=>{
 const source=read(path),lines=source.split('\n'),mutants=[];
 for(const name of [...maxHp,...battle,...nodes]){
  const line=lines.find(line=>line.includes(`"${name}":`));assert.ok(line,name);
  mutants.push(source.replace(line+'\n',''),source.replace(line+'\n',line+'\n'+line+'\n'),source.replace(`"${name}":`,`"${name}_unknown":`),source.replace(line,line.replace(/: "(core|ui)"/,(_,layer)=>`: "${layer==='core'?'ui':'core'}"`)));
 }
 const first='    "abyss_nodes_common": "core",\n',next='    "abyss_nodes_entry": "core",\n';
 const battleFirst='    "abyss_battle_actions": "ui",\n',battleNext='    "abyss_battle_action_bindings": "ui",\n';
 mutants.push(source+'\n',source.replace(first+next,next+first),source.replace(battleFirst+battleNext,battleNext+battleFirst),source.replace('"abyss_nodes_sources": "core"','"abyss_nodes_sources": "core",\n    "unknown": "core"'),source.replace('"dynamicExceptions": []','"dynamicExceptions": ["unknown"]'),source.replace('"abyss_run_potion_candidate": "core"','"abyss_run_potion_candidate": "ui"'),source.replace('"reason": "Potion/upgrade/HP','"reason": "unreviewed Potion/upgrade/HP'));
 let acceptedBaselineWitnesses=0;
 for(const mutant of mutants){
  assert.notEqual(mutant,source);
  for(const target of ['candidate','nodes']){
   assert.throws(()=>project(mutant,target),/unreviewed combined Nodes Battle Max HP/);
   assert.equal(preHistoricalNodesBattleMaxHpConfig(path,mutant,target),mutant,'unmatched bytes must reach the old full-source guards');
  }
  // Removing MaxHP alone is now the literal accepted Nodes+Battle base, not
  // unknown drift. Its complete identity is separately retained by PR308.
  if(hash(mutant)==='bab439c579d813dc91a631e29aac4bff41237030efdd33a90a5b84158df7367d'){
   acceptedBaselineWitnesses++;
   assert.equal(mutant,source.replace('    "abyss_max_hp_relics": "core",\n',''));
   assert.equal(preIntegratedNodeUiSource(path,mutant),preIntegratedNodeUiSource(path,source));
   assert.equal(preApprovedUiSource(path,mutant),preApprovedUiSource(path,source));
  }
 }
 assert.equal(acceptedBaselineWitnesses,1,'only the literal accepted Nodes+Battle complete source is newly valid');
 assert.equal(mutants.length,87,'all twenty live additions have four mutation classes plus seven cross-scope controls');
 // The complete matrix above owns this inverse's rejection. One unchanged
 // unknown source checks forwarding through each later composition guard;
 // their own suites own later-layer rejection matrices.
 const drift=source+'\n';
 assert.equal(preNodesBattleMaxHpConfig(path,drift),drift);
 assert.throws(()=>projectNodesBattleMaxHpConfig(path,drift,'candidate'),/unreviewed combined Nodes Battle Max HP/);
 assert.throws(()=>preIntegratedNodeUiSource(path,drift),/unreviewed integrated/);
 assert.throws(()=>preApprovedUiSource(path,drift),/unreviewed integrated/);
});

test('explicit proof rejects missing unknown targets and wrong paths; missing bound sources still fail original guards',()=>{
 const source=read(path);
 for(const missing of [null,undefined,'']){
  assert.throws(()=>project(missing,'candidate'),/combined Nodes Battle Max HP/);
  assert.throws(()=>preApprovedUiSource(path,missing));
  if(typeof missing==='string')assert.equal(preCoreArchitectureSource(path,missing),missing,'an optional projection leaves unmatched bytes for the full guard');
  else assert.throws(()=>preCoreArchitectureSource(path,missing));
 }
 for(const wrongPath of ['config/other.json','data/presentation/ui_theme.json','src/lua/abyss_battle_ui.lua']){
  assert.throws(()=>projectNodesBattleMaxHpConfig(wrongPath,source,'nodes'),/combined Nodes Battle Max HP path/);
  assert.equal(preNodesBattleMaxHpConfig(wrongPath,source),source);
 }
 assert.throws(()=>project(source,'unknown'),/combined Nodes Battle Max HP target/);
});

test('all original config and Nodes source fixtures retain their complete frozen identities',()=>{
 const frozen=[['tests/fixtures/battle-max-hp-config-inverse.json','79bca8cc4391e1906049dd815dd143267894f37425253ca6ac9a836d7aa21456'],['tests/fixtures/battle-ui-governance-inverse.json','392785f4aa6d63795bbd42c9cb354339a175deddc0aa3bcd79a273e43e217e1f'],['tests/fixtures/max-hp-pr313-source-inverse.json','7c1d5bd39878668c7bdc811a4467d8726f811ca7db264d9d7c67e8f016fa85c9'],['tests/fixtures/approved-ui-post-node-layer.json','7d12b5b51d93795162ed4fa9869f5585db30d77fe99650de86ef3938caa737ee'],['tests/nodes-governance-baseline.lua','74ffe0af91db89dc800878d1385bddba27eeef6b232099336eccad04c2859a04']];
 for(const [file,expectedHash]of frozen)assert.equal(hash(read(file)),expectedHash,'original source fixture remains unchanged: '+file);
});
