import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import {createOptInArtFixture} from './helpers/opt-in-art-fixture.mjs';
const fixture=createOptInArtFixture({bindTemplates:true});
after(()=>fixture.dispose());
test('title preloads hidden selection art within budget and entering selection reuses it',()=>{
 const r=fixture.runLua('tests/lua/support/selection_portrait_preload.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/SELECTION_PORTRAIT_PRELOAD_PASS/);
});
