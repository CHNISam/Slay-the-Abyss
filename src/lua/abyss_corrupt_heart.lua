-- Fixed sts@319009d5 A0 Heart owner. Shared combat executes the returned plans.
-- Registration alone does not install damage, queue or Act4 routing hooks.
local Copy=require('abyss_copy').copy
local EnemyRandom=require('abyss_enemy_random')
local M={}
M.enemy={id='corrupt_heart',sourceId='CorruptHeart',name='腐化之心',tier='boss',hp=750,
 sourcePosition={x=-50,y=30},ai={kind='corrupt_heart'},intents={
  {id='debilitate',kind='debuff',effects={
   {op='applyStatus',status='vulnerable',value=2},
   {op='applyStatus',status='weak',value=2},
   {op='applyStatus',status='frail',value=2},
   {op='heartStatusDraw',card='dazed',value=1},
   {op='heartStatusDraw',card='slimed',value=1},
   {op='heartStatusDraw',card='wound',value=1},
   {op='heartStatusDraw',card='burn',value=1},
   {op='heartStatusDraw',card='void',value=1}}},
  {id='blood_shots',kind='attack',effects={{op='damage',value=2,times=12}}},
  {id='echo_attack',kind='attack',effects={{op='damage',value=40}}},
  {id='buff',kind='buff',effects={{op='heartBuff'}}}}}
M.statuses={
 {id='invincible',sourceId='Invincible',name='无敌',kind='buff',stack='intensity',
  decay='none',priority=99,description='每个自身回合最多受到300点伤害。'},
 {id='beat_of_death',sourceId='BeatOfDeath',name='死亡律动',kind='buff',stack='intensity',
  decay='none',priority=5,description='玩家每打出一张牌，受到相应点数的伤害。'}}
local void={id='void',sourceId='Void',name='虚空',type='status',rarity='common',cost=-2,
 ethereal=true,effects={},text='不能打出。抽到时失去1点能量。虚无。'}
function M.owns(enemy)return enemy~=nil and enemy.ai~=nil and enemy.ai.kind=='corrupt_heart'end
function M.register(catalog,copy)
 copy=copy or Copy
 assert(not catalog.enemies.corrupt_heart,'duplicate Corrupt Heart')
 for _,status in ipairs(M.statuses)do
  assert(not catalog.statuses[status.id],'duplicate Heart power: '..status.id)
 end
 catalog.enemies.corrupt_heart=copy(M.enemy)
 for _,status in ipairs(M.statuses)do catalog.statuses[status.id]=copy(status)end
 if not catalog.cards.void then catalog.cards.void=copy(void)end
end
local function select(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then
  enemy.intentIndex=i;enemy.heartLast=id;enemy.heartBuffPlan=nil;return
 end end
 error('unknown Heart intent: '..tostring(id))
end
function M.advance(state,enemy,random)
 assert(M.owns(enemy),'not a Heart owner')
 random(state,100) -- AbstractMonster.rollMove always consumes its primary draw.
 if enemy.heartFirst then
  enemy.heartFirst=false;select(enemy,'debilitate');return
 end
 local cycle=enemy.heartMoveCount%3
 if cycle==0 then
  select(enemy,EnemyRandom.boolean(state,random)and 'blood_shots'or 'echo_attack')
 elseif cycle==1 then
  select(enemy,enemy.heartLast=='echo_attack'and 'blood_shots'or 'echo_attack')
 else select(enemy,'buff')end
 enemy.heartMoveCount=enemy.heartMoveCount+1
end
function M.initialize(state,enemy,random)
 enemy.heartFirst=true;enemy.heartMoveCount=0;enemy.heartBuffCount=0
 return M.advance(state,enemy,random)
end
function M.preBattle(_state,enemy)
 assert(M.owns(enemy),'not a Heart owner')
 enemy.heartInvincibleMax=300
 return {{op='gainStatus',status='invincible',value=300},
  {op='gainStatus',status='beat_of_death',value=1}}
end
function M.buffPlan(enemy)
 assert(M.owns(enemy),'not a Heart owner')
 local strength=(enemy.statuses or {}).strength or 0
 local stage=enemy.heartBuffCount or 0
 local extra={op='gainStatus',status='strength',value=50}
 if stage==0 then extra.status,extra.value='artifact',2
 elseif stage==1 then extra.status,extra.value='beat_of_death',1
 elseif stage==2 then extra.status,extra.value='painful_stabs',-1
 elseif stage==3 then extra.value=10 end
 return {{op='gainStatus',status='strength',value=math.max(0,-strength)+2},extra}
end
function M.previewEffects(enemy,intent)
 if intent.id~='buff'then return Copy(intent.effects)end
 return Copy(enemy.heartBuffPlan or M.buffPlan(enemy))
end
function M.actions(_state,enemy,intent)
 assert(M.owns(enemy),'not a Heart owner')
 if intent.id~='buff'then return Copy(intent.effects)end
 local plan=M.buffPlan(enemy)
 -- Immutable captured plan survives detached animation frames. Replace it only
 -- on the next move, so preview never advances escalation or repairs strength.
 enemy.heartBuffPlan=Copy(plan)
 enemy.heartBuffCount=(enemy.heartBuffCount or 0)+1
 return plan
end
function M.capDamage(enemy,amount)
 if not M.owns(enemy)or not enemy.statuses or enemy.statuses.invincible==nil then return amount end
 assert(type(amount)=='number'and amount>=0 and amount%1==0,'invalid committed damage')
 local budget=enemy.statuses.invincible
 assert(type(budget)=='number'and budget>=0 and budget%1==0,'invalid Invincible budget')
 local allowed=math.min(amount,budget)
 enemy.statuses.invincible=budget-allowed -- zero is a present power, not removal.
 return allowed
end
function M.startTurn(enemy)
 if M.owns(enemy)and enemy.statuses and enemy.statuses.invincible~=nil then
  enemy.statuses.invincible=assert(enemy.heartInvincibleMax,'Heart preBattle missing')
 end
end
function M.afterUse(state,enemy,card,enqueue)
 if not M.owns(enemy)or card.dontTriggerOnUseCard then return end
 local amount=(enemy.statuses or {}).beat_of_death or 0
 if amount>0 then
  -- THORNS survives lethal-card post-combat cleanup and permits a dead source.
  -- Capture the DamageInfo amount now; the host runs damage only when dequeued.
  enqueue(state,{op='heartBeat',sourceId=enemy.id,value=amount})
 end
end
function M.retained(effect)return effect~=nil and effect.op=='heartBeat'end
return M
