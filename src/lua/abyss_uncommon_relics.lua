-- STS 319009d5: uncommon relic callbacks; the caller owns queue placement.
local Queries=require('abyss_relic_queries').uncommon
local Combat=require('abyss_relic_family_combat').uncommon
local queryFields={isBottled=true,localId=true,owns=true,rewardCardCount=true}
local combatFields={atTurnStart=true,canPlayCurse=true,onMonsterDeath=true,onShuffle=true,onUseCard=true,onVictory=true,strikeBonus=true,vulnerablePercent=true,wasHpLost=true}
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
local bottles={bottled_flame={'attack','inBottleFlame'},bottled_lightning={'skill','inBottleLightning'},bottled_tornado={'power','inBottleTornado'}}
local function counters(owner)owner.relicCounters=owner.relicCounters or {};return owner.relicCounters end

local function heal(run,amount)
 if run.hp>0 and not require('abyss_potion_health').blocked(run.relics)then run.hp=math.min(run.maxHp,run.hp+amount)end
end
function M.onEquip(run,id)
 id=M.localId(id)
 if id=='sundial'or id=='ink_bottle'then counters(run)[id]=0
 elseif id=='matryoshka'then counters(run)[id]=2 end
end
function M.onEnterRoom(run,kind,phase)
 if phase~='entered'and kind=='camp'and M.owns(run,'eternal_feather')then heal(run,math.floor(#run.deck/5)*3)end
end
function M.battleEnd(run)
 if run.hp>0 and M.owns(run,'meat_on_the_bone')and run.hp<=run.maxHp/2 then require('abyss_run').heal(run,12)end
end

function M.singingBowl(run,api)
 if not M.owns(run,'singing_bowl')then return false,'missing_singing_bowl'end
 assert(api and api.increaseMaxHp,'Singing Bowl requires permanent health API')
 return api.increaseMaxHp(run,2)
end
function M.onChestOpen(run,boss,randomBoolean)
 if boss or not M.owns(run,'matryoshka')then return nil end
 local c=counters(run);local count=c.matryoshka;assert(count==2 or count==1 or count==-2,'invalid Matryoshka counter')
 if count==-2 then return nil end
 assert(type(randomBoolean)=='function','Matryoshka requires relicRng randomBoolean')
 c.matryoshka=count==1 and -2 or count-1
 return randomBoolean(.75)and 'common'or 'uncommon'
end
local function definition(run,card)
 for _,d in ipairs(run.data.cards.cards)do if d.id==card.cardId then return d end end
 error('unknown bottle card')
end
function M.bottleCandidates(run,id)
 local spec=bottles[M.localId(id)];assert(spec,'unknown bottle')
 local out={}
 for _,card in ipairs(run.deck)do if definition(run,card).type==spec[1]then out[#out+1]=card.uid end end
 return out
end
function M.equipBottle(run,id,uid)
 id=M.localId(id);local spec=bottles[id];assert(spec,'unknown bottle')
 if not M.owns(run,id)then return false,'missing_bottle'end
 for _,card in ipairs(run.deck)do
  if card.uid==uid and definition(run,card).type==spec[1]then
   for _,held in ipairs(run.deck)do held[spec[2]]=nil end
   card[spec[2]]=true;return true
  end
 end
 return false,'invalid_bottle_card'
end

return M
