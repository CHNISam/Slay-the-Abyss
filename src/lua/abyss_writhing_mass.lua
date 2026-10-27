-- A0 WrithingMass: source decisions and queued Reactive/master-deck boundary.
-- Actor owns Malleable arithmetic; the existing command owns all rollback.
local R=require('abyss_sts_random')
local ER=require('abyss_enemy_random')
local Events=require('abyss_events')
local Copy=require('abyss_copy').copy
local M={}
M.enemy={id='writhing_mass',sourceId='WrithingMass',name='Writhing Mass',tier='normal',hp=160,
 ai={kind='act3',policy='writhing_mass'},intents={
  {id='big_hit',kind='attack',effects={{op='damage',value=32}}},
  {id='multi_hit',kind='attack',effects={{op='damage',value=7,times=3}}},
  {id='attack_block',kind='attack',effects={{op='damage',value=15},{op='block',value=15,fixed=true}}},
  {id='attack_debuff',kind='attack',effects={{op='damage',value=10},
   {op='applyStatus',status='weak',value=2},{op='applyStatus',status='vulnerable',value=2}}},
  {id='implant',kind='debuff',effects={{op='writhingParasite'}}}}}
M.status={id='reactive',sourceId='Compulsive',name='应激',kind='buff',stack='none',decay='none',priority=50,
 description='受到非致命且未被格挡的普通伤害后，在已排队动作之后重新选择意图。'}
local function isMass(e)return e and e.ai and e.ai.kind=='act3'and e.ai.policy=='writhing_mass'end
local function select(e,id)
 for i,intent in ipairs(e.intents)do
  if intent.id==id then e.intentIndex=i;e.writhingLast=id;return end
 end
 error('unknown Writhing Mass intent')
end
local function integer(s,random,lo,hi)return lo+ER.integer(s,hi-lo+1,random)-1 end
local function chance(s,random,n)return ER.float(s,random)<R.float32(n)end
function M.advance(s,e,random)
 local n=integer(s,random,0,99)
 if e.writhingFirst then
  e.writhingFirst=false
  select(e,n<33 and 'multi_hit'or n<66 and 'attack_block'or 'attack_debuff');return
 end
 -- The original recursively resamples narrower intervals. This loop preserves
 -- every integer/float draw and updates history only once, at setMove.
 while true do
  local id
  if n<10 then
   if e.writhingLast~='big_hit'then id='big_hit'else n=integer(s,random,10,99)end
  elseif n<20 then
   if not e.writhingUsedImplant and e.writhingLast~='implant'then id='implant'
   elseif chance(s,random,.1)then id='big_hit'else n=integer(s,random,20,99)end
  elseif n<40 then
   if e.writhingLast~='attack_debuff'then id='attack_debuff'
   elseif chance(s,random,.4)then n=integer(s,random,0,19)else n=integer(s,random,40,99)end
  elseif n<70 then
   if e.writhingLast~='multi_hit'then id='multi_hit'
   elseif chance(s,random,.3)then id='attack_block'else n=integer(s,random,0,39)end
  elseif e.writhingLast~='attack_block'then id='attack_block'
  else n=integer(s,random,0,69)end
  if id then select(e,id);return end
 end
end
function M.initialize(s,e,random)
 e.writhingFirst,e.writhingUsedImplant,e.writhingLast=true,false,nil
 M.advance(s,e,random)
end
function M.preBattle(s,e,A)
 A.applyPower(s,e,'reactive',1,e);A.applyPower(s,e,'malleable',3,e)
end
function M.beforeAction(e,intent)
 if intent.id=='implant'then e.writhingUsedImplant=true end
end
-- Priority-5 Malleable has already appended its block. Priority-50 Reactive
-- appends a distinct RollMoveAction, never rerolls synchronously between hits.
function M.attacked(s,source,target,amount,fixed,push)
 if isMass(target)and source and not fixed and amount>0 and amount<target.hp
  and (target.statuses.reactive or 0)>0 then push(s,{op='writhingRoll',targetId=target.id})end
end
function M.roll(s,id)
 for _,e in ipairs(s.enemies)do if e.id==id then
  assert(isMass(e),'invalid Reactive owner')
  -- RollMoveAction has no owner-death guard. Final victory clears this action
  -- through the existing queue, but a dead owner with a living ally still rolls.
  M.advance(s,e,ER.legacyInteger)
  Events.emit(s,'enemy_interrupt',{enemy=e.id,id=e.intents[e.intentIndex].id});return
 end end
 error('missing Reactive owner')
end
function M.bindMaster(s,deck,nextUid)
 s.masterDeck=Copy(deck or {})
 local enabled=false;for _,e in ipairs(s.enemies)do if isMass(e)then enabled=true end end
 if not enabled then return end
 local minimum=1
 for _,card in ipairs(s.masterDeck)do minimum=math.max(minimum,card.uid+1.0)end
 s.nextMasterDeckUid=nextUid or minimum
end
function M.obtainParasite(s,source)
 assert(isMass(source),'Parasite requires Writhing Mass')
 local Relics=require('abyss_relic_hooks')
 local definition=assert(s.catalog.cards.parasite,'missing permanent Parasite')
 assert(definition.type=='curse'and definition.onRemoveMaxHpLoss==3,'invalid Parasite definition')
 local context={phase='combat',combat=s,relics=s.relics,relicCounters=s.relicCounters,gold=s.player.gold}
 if not Relics.beforeObtainCard(context,definition)then
  Events.emit(s,'permanent_card_blocked',{cardId='parasite',relic='omamori'});return
 end
 local uid=s.nextMasterDeckUid
 assert(type(uid)=='number'and uid%1==0 and uid>=1 and uid<9007199254740991.0,'invalid master-deck UID')
 for _,card in ipairs(s.masterDeck)do assert(card.uid~=uid,'duplicate master-deck UID')end
 local card={uid=uid,cardId='parasite',upgraded=false}
 local ok,why=Relics.onObtainCard(context,card,definition,{combatContext=s,increaseMaxHp=function(_,n)
  return require('abyss_inventory').apply(s,{{op='increaseMaxHp',value=n}},nil,context,true)
 end})
 assert(ok,why)
 s.player.gold=context.gold
 s.masterDeck[#s.masterDeck+1]=card;s.nextMasterDeckUid=uid+1.0
 s.masterDeckObtains=s.masterDeckObtains or {};s.masterDeckObtains[#s.masterDeckObtains+1]=Copy(card)
 Events.emit(s,'permanent_card_obtained',{source=source.id,cardId='parasite',uid=uid})
end
-- Public Run obtains can occur while a battle is active. Only this encounter
-- owns an acquisition cursor; preserve every other battle's historical shape.
function M.externalObtain(run,card)
 local s=run.phase=='combat'and run.combat
 if not s or not s.nextMasterDeckUid then return end
 if card then
  assert(card.uid==s.nextMasterDeckUid,'stale active master-deck UID')
  s.masterDeck[#s.masterDeck+1]=Copy(card)
 end
 s.nextMasterDeckUid=run.nextDeckUid
 s.relicCounters=Copy(run.relicCounters or {})
 s.player.gold=run.gold
end
function M.syncMaster(run)
 local s=run.combat
 if not s.masterDeckObtains then return end
 for _,card in ipairs(s.masterDeckObtains)do
  assert(card.uid==run.nextDeckUid,'invalid obtained master-deck UID')
  for _,old in ipairs(run.deck)do assert(old.uid~=card.uid,'duplicate obtained master-deck UID')end
  run.deck[#run.deck+1]=Copy(card);run.nextDeckUid=run.nextDeckUid+1.0
 end
 run.hp,run.maxHp=s.player.hp,s.player.maxHp
 s.masterDeckObtains=nil
end
return M
