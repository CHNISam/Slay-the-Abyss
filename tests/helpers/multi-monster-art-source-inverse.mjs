import {architectureSourceFormat} from './architecture-source-format.mjs';
// Exact test-only outer projection. Foreign/partial input never acquires permission.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/multi-monster-art-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'21a0f191c00c20fc21695f87d4cfe0242cf7f2571a20b5db4878c1f58397839f');
export const multiMonsterSourceLayer=JSON.parse(bytes);
assert.equal(multiMonsterSourceLayer.baseCommit,'03266f668eb5ab6d7ed72d840fa55eafa90a819c');
assert.deepEqual(Object.keys(multiMonsterSourceLayer.files).sort(),["config/architecture.json","data/presentation/native-monster-art.json","data/presentation/ui_theme.json","data/statuses.json","scripts/audit-native-candidate.mjs","scripts/build-native-candidate.mjs","scripts/build-ui.mjs","scripts/monster-art.mjs","scripts/native-candidate-scripts.mjs","scripts/platform-load.mjs","scripts/test-lua.mjs","scripts/ui-layout.mjs","src/lua/abyss_act2_powers.lua","src/lua/abyss_actor.lua","src/lua/abyss_battle_actions.lua","src/lua/abyss_battle_detail_bindings.lua","src/lua/abyss_battle_enemy_view.lua","src/lua/abyss_battle_input_state.lua","src/lua/abyss_battle_intent_view.lua","src/lua/abyss_battle_render_actors.lua","src/lua/abyss_battle_target_bindings.lua","src/lua/abyss_battle_targeting.lua","src/lua/abyss_battle_ui.lua","src/lua/abyss_battle_unit_view.lua","src/lua/abyss_combat.lua","src/lua/abyss_combat_effect_powers.lua","src/lua/abyss_combat_enemy_setup.lua","src/lua/abyss_controller.lua","src/lua/abyss_defect_engine_cards.lua","src/lua/abyss_event_combat.lua","src/lua/abyss_events.lua","src/lua/abyss_feedback.lua","src/lua/abyss_feedback_actor_painter.lua","src/lua/abyss_focus.lua","src/lua/abyss_game_ui.lua","src/lua/abyss_guardian_ai.lua","src/lua/abyss_monster_art.lua","src/lua/abyss_monster_displayed_intent.lua","src/lua/abyss_monster_escape.lua","src/lua/abyss_monster_intent_particle_view.lua","src/lua/abyss_monster_intent_particles.lua","src/lua/abyss_monster_power_surfaces.lua","src/lua/abyss_monster_power_view.lua","src/lua/abyss_monster_source_geometry.lua","src/lua/abyss_monster_source_intents.lua","src/lua/abyss_monster_source_positions.lua","src/lua/abyss_monster_surfaces.lua","src/lua/abyss_plated_armor.lua","src/lua/abyss_power_order.lua","src/lua/abyss_power_schedule.lua","src/lua/abyss_run_rooms.lua","src/lua/abyss_stances.lua","src/lua/abyss_ui.lua"]);
for(const entry of Object.values(multiMonsterSourceLayer.files)){
 if(entry.beforeSha256===null)assert.equal(entry.beforeSource,null);
 else assert.equal(hash(entry.beforeSource),entry.beforeSha256);
}
export function preMultiMonsterArtSource(path,source){
 const entry=multiMonsterSourceLayer.files[path];
 if(!entry||typeof source!=='string')return source;
 let current=normalize(source);
 // Retain only the pre-existing architecture JSON whitespace permission.
 if(path==='config/architecture.json')try{
  const {formatted:canonical,tokensEqual}=architectureSourceFormat(path,current);
  if(tokensEqual&&hash(canonical)===entry.afterSha256)current=canonical;
 }catch{/* Foreign tokens remain visible to historical guards. */}
 if(hash(current)!==entry.afterSha256)return source;
 return entry.beforeSource;
}

export const multiMonsterAddedPaths=Object.freeze(Object.entries(multiMonsterSourceLayer.files)
 .filter(([,entry])=>entry.beforeSha256===null).map(([path])=>path));
export function prepareMultiMonsterRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'multi-monster retirement requires separate historical destination');
 const targets=[];
 for(const path of multiMonsterAddedPaths){
  const target=join(directory,path);if(!existsSync(target))continue;
  assert.equal(hash(normalize(readFileSync(target,'utf8'))),multiMonsterSourceLayer.files[path].afterSha256,'unreviewed multi-monster module: '+path);
  targets.push(target);
 }
 return ()=>{for(const target of targets)rmSync(target);};
}
