import {restoreExactFixtureHunks} from './exact-fixture-hunks.mjs';
const reference="        reference.relics={'burning_blood'};reference.relicCounters={};reference.relicCombat={attackPlayed=false}";
const generation='        local generation=run.combatGeneration';
export const smallSlimesReferenceFixture=Object.freeze({
 path:'tests/lua/small_slimes.lua',
 beforeSha256:'dde5543a126f0991fba7fa7fabadd25d21e65b26c323f0a38acc686b5eda7258',
 afterSha256:'9bd483cc6ba2dbbe28eaeb30a51852e9054173da66ec681b0d723d6274ee2b02',
 hunks:[{at:265,
  before:[reference,generation].join('\n'),
  after:[reference,
   '        -- Pin the new first-turn hook owners independently of the actual Run.',
   '        reference.rareRelicCombat={firstPocketTurn=true,gamblingActivated=false,topCanDraw=true,topDisabled=false}',
   '        reference.shopRelicCombat={pellets={}}',generation].join('\n'),
 }],
});
// Original-body verification alone receives the exact pre-hook-owner fixture.
export function preSmallSlimesReferenceFixtureSource(path,source){
 return restoreExactFixtureHunks(smallSlimesReferenceFixture,path,source);
}
