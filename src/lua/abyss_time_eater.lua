-- A0 Time Eater; independent adaptation of sts@319009d5's bounded methods.
-- Combat and the existing two queue hosts retain transactions/turn ownership.
local A=require('abyss_actor')
local ER=require('abyss_enemy_random')
local Events=require('abyss_events')
local Schedule=require('abyss_power_schedule')
local M={}
M.enemy={id='time_eater',sourceId='TimeEater',name='时蚀者',tier='boss',hp=456,
 sourcePosition={x=-50,y=30},ai={kind='act3_boss',policy='time_eater'},intents={
  {id='reverberate',name='回响',kind='attack',effects={{op='damage',value=7,times=3}}},
  {id='head_slam',name='震颅',kind='attack',effects={{op='damage',value=26},
   {op='applyStatus',status='draw_reduction',value=1}}},
  {id='ripple',name='涟漪',kind='defend',effects={{op='block',value=20,fixed=true},
   {op='applyStatus',status='vulnerable',value=1},{op='applyStatus',status='weak',value=1}}},
  {id='haste',name='加速',kind='buff',effects={{op='timeEater',kind='cleanse'},
   {op='timeEater',kind='removeShackled'},{op='timeEater',kind='heal'}}}}}
M.statuses={
 {id='time_warp',sourceId='Time Warp',name='时间扭曲',kind='buff',stack='intensity',decay='none',
  description='每使用12张牌，立即停止后续自动出牌，本张牌结算后结束回合；所有敌人获得2点力量。计数跨回合保留。'},
 {id='draw_reduction',sourceId='Draw Reduction',name='抽牌减少',kind='debuff',stack='duration',decay='round_end_minus_1',
  description='回合开始时少抽1张牌；剩余层数表示持续回合，叠加不继续减少每回合抽牌数。'}}
local function select(e,id)
 for i,intent in ipairs(e.intents)do if intent.id==id then
  e.timeEaterPrevious,e.timeEaterLast=e.timeEaterLast,id;e.intentIndex=i;return
 end end
 error('unknown Time Eater intent '..tostring(id))
end
function M.register(catalog,copy)
 assert(not catalog.enemies.time_eater,'duplicate Time Eater')
 catalog.enemies.time_eater=copy(M.enemy)
 for _,status in ipairs(M.statuses)do
  assert(not catalog.statuses[status.id],'duplicate Time Eater Power')
  catalog.statuses[status.id]=copy(status)
 end
end
-- Recursive rerolls do not enter rollMove again: they consume precisely the
-- source's inclusive secondary integer/float draw, never another primary roll.
local function choose(state,e,random,n)
 if e.hp<math.floor(e.maxHp/2)and not e.timeEaterUsedHaste then
  e.timeEaterUsedHaste=true;select(e,'haste');return
 end
 if n<45 then
  if e.timeEaterLast~='reverberate'or e.timeEaterPrevious~='reverberate'then select(e,'reverberate')
  else choose(state,e,random,random(state,50)+49)end
 elseif n<80 then
  if e.timeEaterLast~='head_slam'then select(e,'head_slam')
  elseif ER.float(state,random)<0.6600000262260437 then select(e,'reverberate')
  else select(e,'ripple')end
 elseif e.timeEaterLast~='ripple'then select(e,'ripple')
 else choose(state,e,random,random(state,75)-1)end
end
function M.advance(state,e,random)choose(state,e,random,random(state,100)-1)end
function M.initialize(state,e,random)
 e.timeEaterUsedHaste=false;e.timeEaterLast,e.timeEaterPrevious=nil,nil
 M.advance(state,e,random)
end
function M.active(state)
 for _,e in ipairs(state.enemies)do if e.statuses.time_warp~=nil then return true end end
 return false
end
function M.preBattle(state,e)A.applyPower(state,e,'time_warp',0,e)end
function M.beforeAction(_,e,intent)
 -- HealAction captures the missing half-HP at takeTurn, before queued cleanse.
 if intent.id=='haste'then e.timeEaterHealAmount=math.floor(e.maxHp/2)-e.hp end
end
function M.drawCount(state,base)
 return math.max(0,base-((state.player.statuses.draw_reduction or 0)>0 and 1 or 0))
end
local function remove(state,e,id)
 local n=e.statuses[id]
 if n==nil then return end
 Schedule.remove(state,e,id);e.statuses[id]=nil;e[id..'JustApplied']=nil
 local order={};for _,old in ipairs(e.powerOrder or {})do if old~=id then order[#order+1]=old end end;e.powerOrder=order
 Events.emit(state,'status',{source=e.id,target=e.id,status=id,amount=-n})
end
function M.retained(effect)
 return effect.op=='timeEater'and (effect.kind=='cancelledUse'or effect.kind=='heal')
end
-- UseCardAction.update's onAfterUseCard: this must see the physical instance,
-- after all card effects but before its flag reset/disposal/exhaust callbacks.
function M.afterUse(state,instance,enqueue,owner)
 if instance.dontTriggerOnUseCard then return end
 for _,e in ipairs(owner and {owner}or state.enemies)do if e.statuses.time_warp~=nil then
  local before=e.statuses.time_warp
  assert(before>=0 and before<12 and before%1==0,'invalid Time Warp count')
  e.statuses.time_warp=(before+1)%12
  Events.emit(state,'status',{source=e.id,target=e.id,status='time_warp',amount=e.statuses.time_warp-before})
  if before==11 then
   state.endTurnAfterCard=true
   -- callEndTurnEarlySequence disposes only autoplay queue entries, appending
   -- their UseCardActions BEFORE the per-monster Strength actions.
   for _,entry in ipairs(state.queuedCards or {})do if entry.autoplay and entry.card then
    entry.card.dontTriggerOnUseCard=true
    enqueue(state,{op='timeEater',kind='cancelledUse',entry=entry})
   end end
   state.queuedCards=nil
   for _,ally in ipairs(state.enemies)do
    enqueue(state,{op='timeEater',kind='strength',targetId=ally.id})
   end
  end
 end end
end
function M.execute(combat,state,effect,source,actions)
 local kind=effect.kind
 if kind=='cancelledUse'then
  local entry=effect.entry;local c=assert(entry.card);local d=combat.cardDefinition(state,c)
  c.freeToPlayOnce=nil
  if entry.purge or d.type=='power'then return true end
  local exhaust=entry.exhaustCards;if exhaust==nil then exhaust=entry.autoplay end
  if exhaust or require('abyss_exhaust').shouldExhaust(state,d)then
   if state.actionQueue then
    -- Reuse the current queue's existing exhaust owner: TOP Sentinel must
    -- precede already queued Strength, while Power BOT hooks stay after it.
    assert(state.cardInUse==nil,'cancelled autoplay overlaps a using card')
    state.cardInUse=c
    require('abyss_exhaust').move(state,c,'using',require('abyss_action_queue'),
     {onExhaustRelics=state.onExhaustRelics or {}})
   else actions.exhaust(combat,state,c)end
  elseif d.shuffleBackIntoDrawPile then
   if #state.draw>0 then table.insert(state.draw,combat.cardRandom(state,#state.draw),c)else state.draw[#state.draw+1]=c end
  else state.discard[#state.discard+1]=c end
  c.dontTriggerOnUseCard=false
 elseif kind=='strength'then
  for _,ally in ipairs(state.enemies)do if ally.id==effect.targetId then A.applyPower(state,ally,'strength',2,ally);break end end
 else
  assert(source and source.ai and source.ai.policy=='time_eater','Time Eater action owner required')
  if not A.isActive(source)then return true end
  if kind=='cleanse'then
   -- RemoveDebuffsAction inserts each removal at TOP, reversing Power order.
   local powers,order={},{}
   for i,id in ipairs(source.powerOrder or {})do order[id]=i end
   for id,n in pairs(source.statuses)do local d=source.statusDefinitions[id]
    if d.kind=='debuff'or (id=='strength'or id=='dexterity'or id=='focus')and n<=0 then
     powers[#powers+1]={id=id,priority=d.priority or 5,order=order[id]or math.huge}
    end
   end
   table.sort(powers,function(a,b)
    if a.priority~=b.priority then return a.priority<b.priority end
    if a.order~=b.order then return a.order<b.order end
    return a.id<b.id
   end)
   for i=#powers,1,-1 do remove(state,source,powers[i].id)end
  elseif kind=='removeShackled'then remove(state,source,'shackled')
  else
   assert(kind=='heal','unknown Time Eater action')
   local amount=assert(source.timeEaterHealAmount,'missing captured Haste heal')
   local before=source.hp;source.hp=math.min(source.maxHp,source.hp+amount)
   Events.emit(state,'heal',{source=source.id,target=source.id,amount=source.hp-before})
   source.timeEaterHealAmount=nil
  end
 end
 return true
end
return M
