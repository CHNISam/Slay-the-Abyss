import {restoreExactFixtureHunks} from './exact-fixture-hunks.mjs';
const body=[
 'local function sameRunCombat(run,expected)',
 ' local generation=run.combatGeneration',
 " assert(type(generation)=='number'and generation%1==0 and generation>=1 and generation<=2147483647,'invalid Run combat generation')",
 " eq(run.combat.combatGeneration,generation,'Run/battle generation ownership')",
 " eq(expected.combatGeneration,nil,'standalone Core generation')",
 ' local reference=C.copy(expected)',
 ' reference.combatGeneration=generation',
];
export const gremlinGangOwnerFixture=Object.freeze({
 path:'tests/lua/support/gremlin_gang_fixture.lua',
 beforeSha256:'da93d70d58efd55caa1cd80000cad0d921d2c059592e96dcd2ca4ef0ebe0eb5a',
 afterSha256:'4438b5e2630ed27b101e6ff80103b12fa52bb5f24f79ab803365829a6c51843a',
 hunks:[{at:15,
  before:['-- Normalize this single proven host field on a copy, then compare everything.',...body,
   ' same(run.combat,reference)','end'].join('\n'),
  after:['-- Pin host metadata and first-turn hook owners independently, then compare everything.',...body,
   ' reference.rareRelicCombat={firstPocketTurn=true,gamblingActivated=false,topCanDraw=true,topDisabled=false}',
   ' reference.shopRelicCombat={pellets={}}',' same(run.combat,reference)','end'].join('\n'),
 }],
});
// Only the historical whole-body budget proof receives the original helper.
export function preGremlinGangOwnerFixtureSource(path,source){
 return restoreExactFixtureHunks(gremlinGangOwnerFixture,path,source);
}
