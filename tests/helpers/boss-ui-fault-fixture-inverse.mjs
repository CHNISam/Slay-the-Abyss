// Historical witnesses only. The current Boss UI still executes the complete
// explicit missing-definition adversary against production modules.
import {restoreExactFixtureHunks} from './exact-fixture-hunks.mjs';
export const bossUiFaultFixture=Object.freeze({
 path:'tests/lua/game_ui_boss_treasure.lua',
 beforeSha256:'b551bca139eb44e7a84b96a3d12be598dab9dc28592b903a9438623577b78073',
 afterSha256:'973b7bb108d5cb7c0f06823efc321852c1856f6b99e7211ea69ddf4cb2a5d2e2',
 hunks:[{at:136,
  before:[
   "test('real seed1 source offer keeps unavailable identities visible and rejects every claim atomically',function()",
   '    local ui,root=enterTreasure(nil,nil,true)',
  ].join('\n'),
  after:[
   "test('real seed1 source offer keeps injected missing definitions visible and rejects every claim atomically',function()",
   '    local ui,root=enterTreasure(nil,function(run)',
   '        -- Fault input only: these effects are now implemented. Preserve the',
   '        -- complete source catalog/RNG while retaining the refusal regression.',
   "        local missing={['Snecko Eye']=true,['Calling Bell']=true,['Cursed Key']=true}",
   '        run.data=F.Combat.copy(run.data);local removed=0',
   '        for i=#run.data.relics.relics,1,-1 do',
   '            if missing[run.data.relics.relics[i].sourceId]then table.remove(run.data.relics.relics,i);removed=removed+1 end',
   '        end',
   "        assert(removed==3,'missing-definition adversary must start from all three implemented effects')",
   '    end,true)',
  ].join('\n'),
 }],
});
export function preBossUiFaultFixtureSource(path,source){return restoreExactFixtureHunks(bossUiFaultFixture,path,source);}
