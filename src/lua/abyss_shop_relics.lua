-- Independently adapted from STS 319009d5 relics and UseCardAction.
-- The caller owns transactions and action ordering; this module never rerolls
-- an unavailable item or silently completes an unresolved reward screen.

local R=require('abyss_sts_random')
local Queries=require('abyss_relic_queries').shop
local Combat=require('abyss_relic_family_combat').shop
local queryFields={aliases=true,drawOrderVisible=true,localId=true,owns=true,xBonus=true}
local combatFields={battleStartActions=true,beginToolbox=true,chooseToolbox=true,execute=true,exhaustAfterUse=true,medicalCard=true,onBlockBroken=true,onShuffle=true,onUseCard=true,turnStartActions=true}
local function queryIndex(_,key)
 if queryFields[key] then return Queries[key] end
 if combatFields[key] then return Combat[key] end
end
local function queryNewIndex(self,key,value)
 if queryFields[key] then Queries[key]=value
 elseif combatFields[key] then Combat[key]=value
 else rawset(self,key,value) end
end
local M=setmetatable({}, {__index=queryIndex,__newindex=queryNewIndex})
function M.onEquip(run,id,api)
 id=M.aliases[id]or id
 api=api and api.openRewards and api or require('abyss_relic_choices').adapter()
 if id=='prismatic_shard' then
  if run.character~='defect'and (run.masterMaxOrbs or 0)==0 then run.masterMaxOrbs=1 end
 elseif id=='dollys_mirror' then
  assert(not run.shopRelicChoice,'unresolved shop relic choice')
  local uids={};for _,card in ipairs(run.deck)do uids[#uids+1]=card.uid end
  run.shopRelicChoice={relic=id,kind='copy',uids=uids}
 elseif id=='orrery' or id=='cauldron' then
  assert(api and type(api.openRewards)=='function','shop relic requires reward-screen adapter')
  local rewards={}
  for i=1,5 do
   if id=='orrery' then
    assert(type(api.createCardReward)=='function','Orrery requires ordinary card reward adapter')
    rewards[i]={kind='card',reward=assert(api.createCardReward(run)),claimed=false}
   else
    local pool=require('abyss_potion_random')
    if not run.shopRng then
     local seed=run.eventSeed or string.format('%.0f',run.seed)
     run.shopRng={merchant=R.fromSeed(seed),potion=R.fromSeed(seed)}
    end
    assert(run.shopRng.potion,'Cauldron requires potionRng')
    local potion=pool.sample({potionRng=run.shopRng.potion},{character=pool.character(run)})
    rewards[i]={kind='potion',id=potion.id,claimed=false}
   end
  end
  api.openRewards(run,id,rewards)
 end
end
function M.chooseMirror(run,uid,api)
 local choice=run.shopRelicChoice
 if not choice or choice.kind~='copy'or choice.relic~='dollys_mirror'then return false,'no_shop_relic_choice'end
 local eligible=false;for _,id in ipairs(choice.uids)do if id==uid then eligible=true end end
 if not eligible then return false,'invalid_card_choice'end
 api=api or require('abyss_relic_choices').adapter()
 assert(type(api.obtainCardCopy)=='function','Dolly requires permanent card-copy adapter')
 local ok,why=api.obtainCardCopy(run,uid)
 if not ok then return false,why end
 run.shopRelicChoice=nil;return true,why
end

-- Deep Breath must place constructor reactions before its shuffle continuation.
-- Other shuffle callers retain the existing BOTTOM enqueue by default.

return M
