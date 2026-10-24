-- Actual Act 1 room bindings, distinct from historical explicit-ID fixtures.
-- All 17 Exordium queue names are retained. No floor filter or renormalization.
local C=require('abyss_encounter_formation')
local M={}
local fixed={
 ['Cultist']={'cultist_solo','cultist'},['Jaw Worm']={'jaw_solo','jaw_worm'},
 ['Blue Slaver']={'blue_slaver_solo','blue_slaver'},['Looter']={'looter_solo','looter'},
 ['Red Slaver']={'red_slaver_solo','red_slaver'},['2 Fungi Beasts']={'fungi_pair','fungi_beast','fungi_beast'},
 ['Gremlin Nob']={'elite_nob','gremlin_nob'},['Lagavulin']={'elite_lagavulin','lagavulin'},
 ['3 Sentries']={'elite_sentries','sentry','sentry','sentry'},
}
local dynamic={['Small Slimes']='small_slimes',['Gremlin Gang']='gremlin_gang',
 ['2 Louse']='louse_pair',['3 Louse']='louse_trio',['Large Slime']='large_slime',
 ['Lots of Slimes']='lots_of_slimes',['Exordium Thugs']='exordium_thugs',['Exordium Wildlife']='wildlife'}
function M.resolve(source,tier)
 if tier~='normal' and tier~='elite' then return nil,'invalid_encounter_tier' end
 local isElite=source=='Gremlin Nob' or source=='Lagavulin' or source=='3 Sentries'
 if (tier=='elite')~=isElite then return nil,'encounter_tier_mismatch' end
 if dynamic[source] then
  assert(C.supports(source),'missing source formation')
  return {id=dynamic[source],tier=tier,source=source,sourceEncounter=source}
 end
 local entry=fixed[source]
 if not entry then return nil,'unknown_source_encounter' end
 local enemies={};for i=2,#entry do enemies[#enemies+1]=entry[i]end
 return {id=entry[1],tier=tier,source=source,enemies=enemies}
end
return M
