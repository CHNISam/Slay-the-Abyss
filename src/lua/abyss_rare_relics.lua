-- STS 319009d5 rare relic hooks. Action/transaction ownership stays in Combat.

local Queries=require('abyss_relic_queries').rare
local Combat=require('abyss_relic_family_combat').rare
local queryFields={canSpawn=true,extraCardRewards=true,localId=true,owns=true}
local combatFields={applyEffect=true,atTurnStart=true,battleStart=true,bindBattle=true,blockAtTurnStart=true,blockPower=true,chooseGambling=true,disableTop=true,modifyHealing=true,onAttacked=true,onExhaust=true,onPlayCard=true,onPlayerEndTurn=true,onRefreshHand=true,onUseCard=true,onVictory=true,onVulnerableApplied=true,postDraw=true,randomCardId=true,rechargeEnergy=true}
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
local owns=Queries.privateOwns
local function counters(s)s.relicCounters=s.relicCounters or {};return s.relicCounters end

function M.onMasterDeckChange(run)
 if not owns(run,'du_vu_doll')then return end
 local catalog={};for _,d in ipairs(run.data.cards.cards)do catalog[d.id]=d end
 local n=0;for _,card in ipairs(run.deck)do if assert(catalog[card.cardId],'unknown master card').type=='curse'then n=n+1 end end
 counters(run).du_vu_doll=n
end
function M.onEquip(run,id)
 id=M.localId(id)
 if id=='girya'or id=='incense_burner'then counters(run)[id]=0
 elseif id=='winged_greaves'then counters(run)[id]=3
 elseif id=='du_vu_doll'then M.onMasterDeckChange(run)end
end

function M.campOptions(run,removable)
 local result={}
 for _,held in ipairs(run.relics or {})do
  local id=M.localId(held)
  if id=='shovel'then result[#result+1]={id='dig',enabled=true}
  elseif id=='girya'then result[#result+1]={id='lift',enabled=(counters(run).girya or 0)<3}
  elseif id=='peace_pipe'then result[#result+1]={id='toke',enabled=removable==true}end
 end
 return result
end
function M.lift(run)
 if not owns(run,'girya')or (counters(run).girya or 0)>=3 then return false,'lift_unavailable'end
 counters(run).girya=(counters(run).girya or 0)+1;return true
end
function M.canWingedTravel(run)
 return owns(run,'winged_greaves')and (counters(run).winged_greaves or 0)>0
end
function M.useWingedTravel(run)
 if not M.canWingedTravel(run)then return false,'winged_travel_unavailable'end
 local c=counters(run);c.winged_greaves=c.winged_greaves-1
 if c.winged_greaves==0 then c.winged_greaves=-2 end
 return true
end

return M
