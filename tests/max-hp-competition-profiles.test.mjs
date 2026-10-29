import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua}from'../scripts/test-lua.mjs';
for(const profile of ['ironclad','raiden'])test(`actual ${profile} retains Max HP definitions, outside obtains and the explicit active-owner boundary`,()=>{
 const result=runLua('tests/lua/max_hp_competition_profiles.lua',{caseName:profile});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp(`MAX_HP_COMPETITION_PROFILES_PASS 2 ${profile}; active V4 refusal remains explicit`));
});
