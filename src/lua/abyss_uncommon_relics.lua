-- STS 319009d5: uncommon relic callbacks; the caller owns queue placement.
local M={}
local aliases={['Bottled Tornado']='bottled_tornado',Sundial='sundial',Kunai='kunai',
 ['Blue Candle']='blue_candle',['Eternal Feather']='eternal_feather',StrikeDummy='strike_dummy',
 ['Singing Bowl']='singing_bowl',Matryoshka='matryoshka',InkBottle='ink_bottle',
 ['Ornamental Fan']='ornamental_fan',['Bottled Lightning']='bottled_lightning',
 ['Gremlin Horn']='gremlin_horn',HornCleat='horn_cleat',['Letter Opener']='letter_opener',
 ['Question Card']='question_card',['Bottled Flame']='bottled_flame',Shuriken='shuriken',
 ['Meat on the Bone']='meat_on_the_bone',['Mummified Hand']='mummified_hand',
 ['Mercury Hourglass']='mercury_hourglass',['Self Forming Clay']='self_forming_clay',['Paper Frog']='paper_frog'}
local bottles={bottled_flame={'attack','inBottleFlame'},bottled_lightning={'skill','inBottleLightning'},bottled_tornado={'power','inBottleTornado'}}
function M.localId(id)return aliases[id]or id end
function M.owns(owner,id)
 for _,held in ipairs(owner.relics or {})do if M.localId(held)==id then return true end end
 return false
end
local function counters(owner)owner.relicCounters=owner.relicCounters or {};return owner.relicCounters end
local function effect(op,value,extra)
 local e=extra or {};e.op=op;e.value=value;return e
end
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
function M.atTurnStart(state,singleId)
 local out,c={},counters(state)
 for _,id in ipairs(singleId and {singleId}or state.relics or {})do
  id=M.localId(id)
  if id=='kunai'or id=='shuriken'or id=='ornamental_fan'or id=='letter_opener'then c[id]=0
  elseif id=='horn_cleat'and state.turn==2 then out[#out+1]=effect('block',14,{fixed=true})
  elseif id=='mercury_hourglass'then out[#out+1]=effect('damageAll',3,{fixed=true,nullSource=true})end
 end
 return out
end
local function advance(owner,id,limit)
 local c=counters(owner);local old=c[id]or 0
 assert(type(old)=='number'and old%1==0 and old>=0 and old<limit,'invalid '..id..' counter')
 c[id]=(old+1)%limit;return c[id]==0
end
function M.onShuffle(state)
 if M.owns(state,'sundial')and advance(state,'sundial',3)then return {effect('energy',2)}end
 return {}
end
local function mummify(state,instance,combat)
 assert(combat and combat.cardDefinition and combat.cardRandom,'Mummified Hand requires card API')
 local eligible,queued={},{}
 for _,entry in ipairs(state.queuedCards or {})do local card=entry.card or entry.instance;if card then queued[card]=true end end
 for _,card in ipairs(state.hand)do
  local base=assert(state.catalog.cards[card.cardId]);local cost=card.combatCost or card.costOverride or base.cost
  if card.upgraded and base.upgrade and base.upgrade.cost~=nil and card.combatCost==nil and card.costOverride==nil then cost=base.upgrade.cost end
  local current=combat.cardDefinition(state,card)
  if card~=instance and not queued[card]and cost>0 and current.cost>0 and not card.freeToPlayOnce and not current.costMode then eligible[#eligible+1]=card end
 end
 if #eligible>0 then local card=eligible[combat.cardRandom(state,#eligible)];card.costForTurn=0;if card.turnCost~=nil then card.turnCost=0 end end
end
function M.onUseCard(state,definition,instance,combat)
 local out={}
 for _,held in ipairs(state.relics or {})do
  local id=M.localId(held)
  if definition.type=='attack'and(id=='kunai'or id=='shuriken'or id=='ornamental_fan')and advance(state,id,3)then
   if id=='ornamental_fan'then out[#out+1]=effect('block',4,{fixed=true})
   else out[#out+1]=effect('gainStatus',1,{status=id=='kunai'and 'dexterity'or 'strength'})end
  elseif id=='letter_opener'and definition.type=='skill'and advance(state,id,3)then out[#out+1]=effect('damageAll',5,{fixed=true,nullSource=true})
  elseif id=='ink_bottle'and advance(state,id,10)then out[#out+1]=effect('draw',1)
  elseif id=='blue_candle'and definition.type=='curse'then
   assert(instance,'Blue Candle requires card instance');instance.exhaust=true;out[#out+1]=effect('loseHp',1)
  elseif id=='mummified_hand'and definition.type=='power'then mummify(state,instance,combat)end
 end
 return out
end
function M.onMonsterDeath(state,enemy)
 if not M.owns(state,'gremlin_horn')or enemy.hp~=0 then return {}end
 for _,other in ipairs(state.enemies)do
  if other~=enemy and require('abyss_actor').isPresent(other)and not other.isDying then return {effect('energy',1),effect('draw',1)}end
 end
 return {}
end
function M.wasHpLost(state,actor,amount)
 if actor==state.player and amount>0 and M.owns(state,'self_forming_clay')then return {effect('gainStatus',3,{status='next_turn_block'})}end
 return {}
end
function M.strikeBonus(owner,definition)return definition.strikeTag and M.owns(owner,'strike_dummy')and 3 or 0 end
function M.vulnerablePercent(owner,target)if target~=owner.player and M.owns(owner,'paper_frog')then return 175 end end
function M.rewardCardCount(owner,base)return base+(M.owns(owner,'question_card')and 1 or 0)end
function M.canPlayCurse(owner,definition)return definition.type=='curse'and M.owns(owner,'blue_candle')end
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
function M.isBottled(card)return card.inBottleFlame==true or card.inBottleLightning==true or card.inBottleTornado==true end
return M
