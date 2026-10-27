-- A0 Reptomancer/SnakeDagger methods independently implemented from sts@319009.
-- Combat retains the existing summon constructor, queues and immutable IDs.
local M={}
local positions={{210,75},{-220,115},{180,345},{-250,335}}
M.enemies={
 {id='reptomancer',sourceId='Reptomancer',name='唤刃蛇使',tier='elite',hp=190,
  hpRange={min=180,max=190},sourcePosition={x=-20,y=10},
  ai={kind='reptomancer',policy='reptomancer',preHpRoll=11},intents={
   {id='summon',kind='unknown',effects={{op='reptomancerSummon'}}},
   {id='snake_strike',kind='attack',effects={{op='damage',value=13,times=2},{op='applyStatus',status='weak',value=1}}},
   {id='big_bite',kind='attack',effects={{op='damage',value=30}}}}},
 {id='snake_dagger',sourceId='Dagger',name='浮游蛇刃',tier='normal',hp=25,
  hpRange={min=20,max=25},ai={kind='reptomancer',policy='dagger'},intents={
   {id='stab',kind='attack',effects={{op='damage',value=9},{op='makeTempCardInDiscard',card='wound',value=1}}},
   {id='explode',kind='attack',effects={{op='damage',value=25},{op='daggerSacrifice'}}}}},
}
function M.register(catalog,copy)
 for _,enemy in ipairs(M.enemies)do
  assert(not catalog.enemies[enemy.id],'duplicate Reptomancer enemy')
  catalog.enemies[enemy.id]=copy(enemy)
 end
end
function M.owns(e)return e and e.ai and e.ai.kind=='reptomancer'end
local function select(e,id)
 for i,move in ipairs(e.intents)do if move.id==id then
  e.reptomancerPrevious,e.reptomancerLast=e.reptomancerLast,id;e.intentIndex=i;return
 end end
 error('unknown Reptomancer intent: '..tostring(id))
end
local function canSpawn(state,leader)
 local alive=0
 for _,e in ipairs(state.enemies)do if e~=leader and e.hp>0 and not e.isDying then alive=alive+1 end end
 return alive<=3
end
local function choose(state,e,n,random)
 if n<33 then
  if e.reptomancerLast~='snake_strike'then return 'snake_strike'end
  return choose(state,e,random(state,67)+32,random) -- source inclusive 33..99
 elseif n<66 then
  if not (e.reptomancerLast=='summon'and e.reptomancerPrevious=='summon')and canSpawn(state,e)then return 'summon'end
  return 'snake_strike'
 elseif e.reptomancerLast~='big_bite'then return 'big_bite'end
 return choose(state,e,random(state,66)-1,random) -- source inclusive 0..65
end
function M.initialize(state,e,random)
 random(state,100) -- inherited init rolls even for both fixed opening moves.
 e.reptomancerLast,e.reptomancerPrevious=nil,nil
 select(e,e.ai.policy=='dagger'and 'stab'or 'summon')
end
function M.advance(state,e,random)
 local n=random(state,100)-1
 select(e,e.ai.policy=='dagger'and 'explode'or choose(state,e,n,random))
end
function M.preBattle(api,state,leader)
 if leader.ai.policy~='reptomancer'then return end
 local slots,minions={},{}
 local after=false
 for _,e in ipairs(state.enemies)do
  if e==leader then after=true
  elseif e.sourceId~=leader.sourceId then
   minions[#minions+1]=e
   if e.definitionId=='snake_dagger'then slots[after and 1 or 2]=e.id end
  end
 end
 -- usePreBattleAction builds every slot before its queued ApplyPower actions.
 leader.reptomancerSlots=slots
 for _,e in ipairs(minions)do e.minion=true;api.applyPower(state,e,'minion',1,e)end
end
function M.bindSummon(state,ownerId,slot,childId)
 for _,leader in ipairs(state.enemies)do if leader.id==ownerId then
  assert(M.owns(leader)and leader.ai.policy=='reptomancer'and slot>=1 and slot<=4,'invalid Reptomancer summon slot')
  local slots={};for i=1,4 do slots[i]=leader.reptomancerSlots[i]end
  slots[slot]=childId;leader.reptomancerSlots=slots;return
 end end
 error('missing Reptomancer summon owner')
end

function M.summon(combat,state,leader)
 assert(M.owns(leader)and leader.ai.policy=='reptomancer','Reptomancer summon only')
 local slots=assert(leader.reptomancerSlots,'missing Reptomancer slots')
 for i,p in ipairs(positions)do
  local present
  for _,e in ipairs(state.enemies)do if e.id==slots[i]then present=e;break end end
  if not present or present.hp<=0 or present.escaped then
   -- A0 constructs precisely one Dagger before its SpawnMonsterAction/init.
   combat.summonEnemies(state,{{id='snake_dagger',x=p[1],y=p[2],reptomancerOwner=leader.id,reptomancerSlot=i}})
   return
  end
 end
end
function M.died(state,e,push)
 if not M.owns(e)or e.ai.policy~='reptomancer'then return end
 -- Reptomancer.die adds each Suicide(true) at TOP: reverse group order.
 -- Health-bar hiding is handled by the existing death presentation, not a kill.
 for _,ally in ipairs(state.enemies)do if ally~=e and ally.hp>0 and not ally.isDying then
  push(state,{op='reptomancerSuicide',targetId=ally.id},true)
 end end
end
function M.cleanup(api,state,effect)
 for _,e in ipairs(state.enemies)do if e.id==effect.targetId then
  api.suicideReptomancerMinion(state,e);return true
 end end
 error('missing Reptomancer cleanup target')
end
function M.resolve(source,tier)
 if source~='Reptomancer'then return nil,'act_content_unavailable'end
 if tier~='elite'then return nil,'encounter_tier_mismatch'end
 return {id='act3_reptomancer',tier=tier,source=source,sourceEncounter=source}
end
return M
