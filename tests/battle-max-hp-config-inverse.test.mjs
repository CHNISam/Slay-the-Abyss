import {preRosterConfigSource} from './helpers/competition-roster-config-composition.mjs';
import {preNodesBattleMaxHpConfig} from './helpers/nodes-battle-max-hp-config-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {projectBattleMaxHpConfig,preCompositeBattleMaxHpConfig} from './helpers/battle-max-hp-config-inverse.mjs';
import {preIntegratedNodeUiSource} from './helpers/approved-node-ui-refactor.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
const path='config/architecture.json';
// The new exact outer proof supplies this unchanged inner proof's owned config.
const read=p=>preNodesBattleMaxHpConfig(p,preRosterConfigSource(p,readFileSync(p,'utf8').replaceAll('\r\n','\n')));
const hash=s=>createHash('sha256').update(s).digest('hex');
const battleHash='66b0aeb0d8a21a587cf67a14c1d503478674012045a303ece995db3532097244';
const maxHpHash='01c0e67dc5c791f9aeaf93afd3cd659ee93357958ac7ce45a474ce1cf720aaca';
const battleModules=['abyss_battle_actions','abyss_battle_action_bindings','abyss_battle_card_bindings','abyss_battle_card_gestures','abyss_battle_card_layout','abyss_battle_details','abyss_battle_detail_bindings','abyss_battle_input_state','abyss_battle_potion_bindings','abyss_battle_render','abyss_battle_render_actors','abyss_battle_render_hud','abyss_battle_render_state','abyss_battle_targeting','abyss_battle_target_bindings'];

test('combined config removes only known Battle or Max HP additions to the unchanged complete accepted identities',()=>{
 const source=read(path),battle=projectBattleMaxHpConfig(path,source,'battle'),maxHp=projectBattleMaxHpConfig(path,source,'maxHp');
 assert.equal(hash(battle),battleHash);assert.equal(hash(maxHp),maxHpHash);
 const live=JSON.parse(source),beforeBattle=JSON.parse(maxHp),beforeMaxHp=JSON.parse(battle);
 assert.deepEqual(Object.keys(live.layers).filter(key=>!Object.hasOwn(beforeBattle.layers,key)).sort(),[...battleModules].sort());
 for(const name of battleModules)assert.equal(live.layers[name],'ui');
 assert.deepEqual(Object.keys(live.layers).filter(key=>!Object.hasOwn(beforeMaxHp.layers,key)),['abyss_max_hp_relics']);
 assert.equal(live.layers.abyss_max_hp_relics,'core');
 for(const previous of [beforeBattle,beforeMaxHp]){
  for(const [key,value]of Object.entries(previous.layers))assert.equal(live.layers[key],value);
  assert.deepEqual({...live,layers:null},{...previous,layers:null},'no other architecture semantics are removed');
 }
 for(const [name,expected]of [['battle',battle],['maxHp',maxHp]])assert.equal(projectBattleMaxHpConfig(path,source.replaceAll('\n','\r\n'),name),expected);
 assert.equal(preCompositeBattleMaxHpConfig(path,source),maxHp);
 for(const previous of [battle,maxHp])assert.equal(preCompositeBattleMaxHpConfig(path,previous),previous,'older complete witnesses remain exact inputs to their own inverse');
});

test('combined projection rejects missing wrong-path unknown duplicated deleted reordered and unrelated inputs',()=>{
 const source=read(path),battleLine='    "abyss_battle_actions": "ui",\n',maxHpLine='    "abyss_max_hp_relics": "core",\n';
 assert.equal(source.split(battleLine).length,2);assert.equal(source.split(maxHpLine).length,2);
 const next='    "abyss_battle_action_bindings": "ui",\n';
 const mutants=[source+'\n',source.replace(battleLine,''),source.replace(maxHpLine,''),source.replace(battleLine,battleLine+battleLine),source.replace(maxHpLine,maxHpLine+maxHpLine),source.replace(battleLine+next,next+battleLine),source.replace('"dynamicExceptions": []','"dynamicExceptions": ["unknown"]'),source.replace('"abyss_run_potion_candidate": "core"','"abyss_run_potion_candidate": "ui"')];
 for(const mutant of mutants){
  assert.notEqual(mutant,source);
  for(const target of ['battle','maxHp'])assert.throws(()=>projectBattleMaxHpConfig(path,mutant,target),/unreviewed combined Battle Max HP/);
  assert.equal(preCompositeBattleMaxHpConfig(path,mutant),mutant);
  if(hash(mutant)===battleHash)assert.equal(preApprovedUiSource(path,mutant),preApprovedUiSource(path,projectBattleMaxHpConfig(path,source,'battle')),'removing all Max HP additions restores an exact older complete witness, never a partial drift');
  else assert.throws(()=>preApprovedUiSource(path,mutant),/unreviewed integrated/,'existing guard still rejects anything beyond the complete exact historical witnesses');
 }
 for(const missing of [null,undefined,''])assert.throws(()=>projectBattleMaxHpConfig(path,missing,'battle'),/combined Battle Max HP/);
 for(const wrongPath of ['config/other.json','src/lua/abyss_battle_ui.lua'])assert.throws(()=>projectBattleMaxHpConfig(wrongPath,source,'maxHp'),/combined Battle Max HP path/);
 assert.throws(()=>projectBattleMaxHpConfig(path,source,'all'),/combined Battle Max HP target/);
 assert.throws(()=>preApprovedUiSource(path,null),'a missing bound config remains rejected by the original guard');
});

test('combined source traverses the unchanged strict historical guards through either complete accepted config',()=>{
 const source=read(path),battle=projectBattleMaxHpConfig(path,source,'battle'),maxHp=projectBattleMaxHpConfig(path,source,'maxHp');
 const expected=preIntegratedNodeUiSource(path,maxHp);
 assert.equal(preIntegratedNodeUiSource(path,battle),expected);
 assert.equal(preIntegratedNodeUiSource(path,source),expected);
 assert.equal(preApprovedUiSource(path,source),preApprovedUiSource(path,battle));
 const frozen=[['tests/fixtures/battle-ui-governance-inverse.json','392785f4aa6d63795bbd42c9cb354339a175deddc0aa3bcd79a273e43e217e1f'],['tests/fixtures/max-hp-pr313-source-inverse.json','7c1d5bd39878668c7bdc811a4467d8726f811ca7db264d9d7c67e8f016fa85c9'],['tests/fixtures/approved-ui-latest-to-53fa.json','39f651e8ec7a3037947d1a76123c2d03a521dd4a05168565f80f7222590ec89a']];
 for(const [file,expectedHash]of frozen)assert.equal(hash(read(file)),expectedHash,'original full-source fixture stays unchanged: '+file);
});
