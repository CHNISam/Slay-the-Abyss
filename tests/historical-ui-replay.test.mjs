import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {historicalUiSources,validateHistoricalUiSources,historicalUiIdentity} from './helpers/historical-ui-replay.mjs';
import {acceptedPresentationSource} from './helpers/presentation-m3-integration.mjs';

test('historical replay requires the entire exact frozen input closure, never loose current fallbacks',()=>{
 const files=historicalUiSources();validateHistoricalUiSources(files);
 assert.match(files['tests/lua/presentation_responsibilities_trace.lua'],/trace.count==81392 and trace.hash==1836812524/);
 assert.match(files['tests/lua/presentation_responsibilities_trace.lua'],/trace:assertNativeInteraction\(\)/);
 const entry='tests/lua/presentation_responsibilities_trace.lua';
 for(const changed of [files[entry].replace('81392','81391'),
  files[entry].replace('trace:assertNativeInteraction()','-- removed native guard')]){
  assert.notEqual(changed,files[entry]);
  assert.throws(()=>validateHistoricalUiSources({...files,[entry]:changed}),/historical source drift/);
 }
 for(const path of ['src/lua/abyss_run.lua','src/lua/abyss_map_ui.lua','scripts/build-ui.mjs',
  'tools/render_traveler_cards.py','tests/lua/support/game_ui_fixture.lua','data/presentation/ui_theme.json']){
  assert.equal(typeof files[path],'string');
  assert.throws(()=>validateHistoricalUiSources({...files,[path]:files[path]+'\n-- unreviewed drift\n'}),/historical source drift/);
  const missing={...files};delete missing[path];assert.throws(()=>validateHistoricalUiSources(missing),/exact historical source closure/);
 }
 assert.throws(()=>validateHistoricalUiSources({...files,'../unreviewed.lua':''}),/exact historical source closure/);
});

test('current-to-history source binding accepts only complete reviewed identities and rejects changed native gates',()=>{
 for(const path of ['src/lua/abyss_battle_ui.lua','src/lua/abyss_node_ui.lua','tests/lua/presentation_responsibilities_trace.lua']){
  const live=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.notEqual(historicalUiIdentity(path,live),live,'reviewed accepted UI has an explicit historical input');
  const drift=live+'\n-- unreviewed current drift\n';
  assert.equal(historicalUiIdentity(path,drift),drift,'unknown bytes never receive a historical substitute');
  assert.throws(()=>acceptedPresentationSource(path,drift),/unreviewed integrated (?:retirement|presentation) source drift/);
 }
});
