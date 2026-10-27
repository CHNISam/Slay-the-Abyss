-- A0 encounter/phase rules independently implemented from sts@319009d5.
-- Actor owns damage and death callbacks; Combat owns its existing queues.
local Events=require('abyss_events')
local M={}
local function action(kind,actor,value)
 return {op='awakenedAction',kind=kind,targetId=actor and actor.id,value=value}
end
function M.owns(actor)return actor and actor.ai and actor.ai.kind=='awakened_one'end
function M.active(state)
 for _,actor in ipairs(state.enemies)do if M.owns(actor)then return true end end
 return false
end
local function select(actor,id)
 for i,intent in ipairs(actor.intents)do if intent.id==id then
  actor.intentIndex=i
  local history={}
  for _,old in ipairs(actor.awakenedHistory or {})do history[#history+1]=old end
  history[#history+1]=id;actor.awakenedHistory=history
  return
 end end
 error('unknown Awakened intent: '..tostring(id))
end
M.enemy={id='awakened_one',sourceId='AwakenedOne',name='苏醒的羽冠',tier='boss',hp=300,
 sourcePosition={x=100,y=15},ai={kind='awakened_one'},intents={
  {id='slash',kind='attack',effects={{op='damage',value=20}}},
  {id='soul_strike',kind='attack',effects={{op='damage',value=6,times=4}}},
  {id='rebirth',kind='unknown',effects={}},
  {id='dark_echo',kind='attack',effects={{op='damage',value=40}}},
  {id='sludge',kind='attack',effects={{op='damage',value=18},{op='awakenedVoid'}}},
  {id='tackle',kind='attack',effects={{op='damage',value=10,times=3}}},
 }}
M.statuses={
 {id='regenerate_monster',sourceId='Regenerate',name='再生',kind='buff',stack='intensity',decay='none',
  description='自身回合结束后回复等同层数的生命；不消耗层数。'},
 {id='curiosity',sourceId='Curiosity',name='好奇',kind='buff',stack='intensity',decay='none',
  description='每当你打出能力牌，获得等同层数的力量。'},
 {id='unawakened',sourceId='Unawakened',name='未醒',kind='buff',stack='none',decay='none',
  description='首次生命归零时进入重生准备，下一次行动恢复生命。'},
}
function M.register(catalog,copy)
 assert(not catalog.enemies[M.enemy.id],'duplicate Awakened One')
 catalog.enemies[M.enemy.id]=copy(M.enemy)
 for _,definition in ipairs(M.statuses)do
  assert(not catalog.statuses[definition.id],'duplicate Awakened Power')
  catalog.statuses[definition.id]=copy(definition)
 end
end
function M.prepare(state)
 -- The same Void identity/effect is used by the existing draw/ethereal paths.
 -- Register only for this encounter, not in ordinary card or source pools.
 if not state.catalog.cards.void then
  state.catalog.cards.void={id='void',sourceId='Void',name='虚空',type='status',rarity='common',
   cost=-2,ethereal=true,effects={},text='不能打出。抽到时失去1点能量。虚无。'}
 end
end
function M.initialize(state,actor,random)
 random(state,100)
 actor.awakenedForm,actor.awakenedFirst=1,false
 select(actor,'slash')
end
function M.preBattle(api,state,actor)
 state.awakenedCannotLose=true
 api.applyPower(state,actor,'regenerate_monster',10,actor)
 api.applyPower(state,actor,'curiosity',1,actor)
 api.applyPower(state,actor,'unawakened',-1,actor)
end
function M.beforeAction(actor,intent)
 if intent.id=='dark_echo'then actor.awakenedFirst=false end
end
function M.afterAction(state,actor,random)
 local roll=random(state,100)-1
 local h=actor.awakenedHistory or {}
 local last,previous=h[#h],h[#h-1]
 if actor.awakenedForm==1 then
  if roll<25 then select(actor,last~='soul_strike'and 'soul_strike'or 'slash')
  else select(actor,last=='slash'and previous=='slash'and 'soul_strike'or 'slash')end
 elseif actor.awakenedFirst then select(actor,'dark_echo')
 elseif roll<50 then select(actor,last=='sludge'and previous=='sludge'and 'tackle'or 'sludge')
 else select(actor,last=='tackle'and previous=='tackle'and 'sludge'or 'tackle')end
end
-- Called before the superclass-style Power death visits. First form's die is
-- suppressed by cannotLose, but its damage override still visits onDeath.
function M.deathStart(state,actor,before)
 if not M.owns(actor)or before<=0 or actor.hp>0 or actor.halfDead then return nil end
 if state.awakenedCannotLose then actor.block=0;actor.halfDead=true;return 'first'end
 actor.isDying=true
 return 'final'
end
function M.finalEscapes(state,push)
 -- AwakenedOne.die queues escapes, not kills, before its override's second
 -- Power visit. Do not mark the cultists escaped while constructing callbacks.
 for _,actor in ipairs(state.enemies)do
  if actor.definitionId=='cultist'and actor.hp>0 and not actor.escaped then
   push(state,action('escape',actor))
  end
 end
end
function M.deathFinish(state,actor,push)
 push(state,action('clearCards'),true)
 local removed={}
 for id,n in pairs(actor.statuses)do
  local definition=assert(actor.statusDefinitions[id],'unknown Awakened Power')
  if definition.kind=='debuff'or id=='curiosity'or id=='unawakened'or id=='shackled'
   or (id=='strength'or id=='dexterity'or id=='focus')and n<=0 then removed[id]=true end
 end
 for id in pairs(removed)do
  actor.statuses[id]=nil;actor[id..'JustApplied']=nil
  require('abyss_power_schedule').remove(state,actor,id)
 end
 local order={};for _,id in ipairs(actor.powerOrder or {})do if not removed[id]then order[#order+1]=id end end
 actor.powerOrder=order
 actor.awakenedForm,actor.awakenedFirst=2,true
 select(actor,'rebirth')
 Events.emit(state,'enemy_interrupt',{enemy=actor.id,id='rebirth'})
 push(state,action('setRebirth',actor))
end
function M.rebirth(state,actor,push)
 assert(M.owns(actor)and actor.halfDead and actor.hp==0,'invalid Awakened Rebirth')
 actor.maxHp,actor.halfDead,actor.awakenedRebirthPending=300,false,true
 push(state,action('heal',actor,actor.maxHp))
 push(state,action('canLose',actor))
end
function M.ownerEnd(api,state,actor,push)
 if not M.owns(actor)or not api.isActive(actor)then return end
 for _,id in ipairs(api.powerSequence(actor,{'regenerate_monster','shackled'}))do
  local n=actor.statuses[id]
  if id=='regenerate_monster'then push(state,action('heal',actor,n))
  else push(state,action('restoreStrength',actor,n));push(state,action('removeShackled',actor))end
 end
end
function M.useEffect(actor,card,entry)
 if entry.id=='curiosity'and card.type=='power'and not card.dontTriggerOnUseCard then
  return action('curiosity',actor,entry.amount)
 end
end
function M.resolve(api,state,effect)
 if effect.kind=='clearCards'then state.queuedCards=nil;return end
 local actor
 for _,enemy in ipairs(state.enemies)do if enemy.id==effect.targetId then actor=enemy;break end end
 assert(actor,'missing Awakened action target')
 if effect.kind=='escape'then
  if actor.hp>0 and not actor.escaped then
   actor.escaped=true;Events.emit(state,'enemy_escape',{enemy=actor.id})
  end
 elseif effect.kind=='setRebirth'then select(actor,'rebirth')
 elseif effect.kind=='curiosity'then api.applyPower(state,actor,'strength',effect.value,actor)
 elseif effect.kind=='restoreStrength'then api.applyPower(state,actor,'strength',effect.value,actor)
 elseif effect.kind=='removeShackled'then
  local n=actor.statuses.shackled
  if n~=nil then
   actor.statuses.shackled=nil;require('abyss_power_schedule').remove(state,actor,'shackled')
   Events.emit(state,'status',{source=actor.id,target=actor.id,status='shackled',amount=-n})
  end
 elseif effect.kind=='canLose'then state.awakenedCannotLose=nil
 elseif effect.kind=='heal'then
  if not actor.isDying then
   local healed=math.min(actor.maxHp-actor.hp,effect.value)
   actor.hp=actor.hp+healed;actor.awakenedRebirthPending=nil
   Events.emit(state,'heal',{target=actor.id,amount=healed})
  end
 else error('unknown Awakened action')end
end
function M.void(state,actor)
 assert(M.owns(actor),'Awakened Void source required')
 local random=require('abyss_sts_random')
 local position=#state.draw==0 and 1 or random.randomInt(assert(state.cardRandomRng,'Void needs card RNG'),#state.draw-1)+1
 local uid=state.nextUid;local nextUid=uid+0.0+1
 assert(type(uid)=='number'and uid>0 and uid%1==0 and nextUid>uid and nextUid<math.huge,'invalid Void UID')
 table.insert(state.draw,position,{uid=uid,uuid=uid,cardId='void',upgraded=false})
 state.nextUid=nextUid
 Events.emit(state,'cards_created',{source=actor.id,cardId='void',amount=1,pile='draw'})
end
return M
