import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import {loadPerformancePack} from '../scripts/art/performance-pack.mjs';
import {createOptInArtFixture} from './helpers/opt-in-art-fixture.mjs';
const fixture=createOptInArtFixture({bindTemplates:true});
after(()=>fixture.dispose());
test('reduced selection preserves battle art and reuses both cached selection hosts',()=>{
 const r=fixture.runLua('tests/lua/support/selection_budget_loading.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/SELECTION_BUDGET_LOADING_PASS/);
});
test('native startup shows official scenery without loading custom background art',()=>{
 const r=fixture.runLua('tests/lua/support/direct_selection_startup.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/OFFICIAL_TITLE_STARTUP_PASS/);
});
test('performance pack has all 75 cards and bounded source-verified character assets',()=>{
 const pack=loadPerformancePack();
 assert.equal(Object.keys(pack.assets).length,78);
 assert(pack.assets.background.count<=3600);
 assert(pack.assets.avatar96.count<=1024);
 assert(pack.assets.battle133.count<=2304);
 assert(Object.values(pack.assets).filter(a=>a.rectangles).every(a=>a.count<=1056));
});
test('adaptive background builds hidden, loads with progress and reuses without navigation or teardown destruction',()=>{
 const r=fixture.runLua('tests/lua/support/compact_art_loading.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/COMPACT_ART_LOADING_PASS/);
});
test('actual default run activates Geo portrait without changing other classes',()=>{
 const r=fixture.runLua('tests/lua/default_traveler_portrait.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/DEFAULT_TRAVELER_PORTRAIT_PASS/);
});
