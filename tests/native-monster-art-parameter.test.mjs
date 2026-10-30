import test from 'node:test';
import assert from 'node:assert/strict';
import {createOptInArtFixture} from './helpers/opt-in-art-fixture.mjs';
test('native entry reads registered monster artwork parameter through GetParam',()=>{
 const fixture=createOptInArtFixture({artFeatures:{}});
 try{
  const result=fixture.runLua('tests/lua/support/native_monster_art_parameter.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_MONSTER_ART_PARAMETER_PASS/);
 }finally{fixture.dispose();}
});
