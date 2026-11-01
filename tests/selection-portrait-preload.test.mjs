import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import {createOptInArtFixture} from './helpers/opt-in-art-fixture.mjs';
import {portraitRuntimeInventory} from '../scripts/official-portraits.mjs';
const fixture=createOptInArtFixture({bindTemplates:true});
after(()=>fixture.dispose());
test('title preloads hidden selection art within budget and entering selection reuses it',()=>{
 const assets=portraitRuntimeInventory(fixture.directory).assets;
 const count=id=>{const a=assets.find(a=>a.asset===id);assert(a,'source inventory '+id);return a.images+a.groups+a.pages;};
 assert.equal(count('lowpolyHero')+count('traveler-geo/portraits/avatar96'),2512);
 assert.equal(count('traveler-geo/portraits/battle133'),4389);
 const r=fixture.runLua('tests/lua/support/selection_portrait_preload.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/SELECTION_PORTRAIT_PRELOAD_PASS/);
});
