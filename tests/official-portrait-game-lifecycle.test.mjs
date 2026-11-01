import test from 'node:test';
import assert from 'node:assert/strict';
import {createOptInArtFixture} from './helpers/opt-in-art-fixture.mjs';

test('generated cached formal portrait survives real combat death, reward, map and next battle',()=>{
 const fixture=createOptInArtFixture({artFeatures:{battlePortrait:true},bindTemplates:true});
 try {
  const result=fixture.runLua('tests/lua/support/official_portrait_game_lifecycle.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/OFFICIAL_PORTRAIT_GAME_LIFECYCLE_PASS/);
 }finally{fixture.dispose();}
});
