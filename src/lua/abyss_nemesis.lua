-- Fixed319009 Nemesis A0. Existing Actor/Combat own damage and transactions.
local Random=require('abyss_enemy_random')
local Events=require('abyss_events')
local M={}
M.enemy={id='nemesis',sourceId='Nemesis',name='天罚',tier='elite',hp=185,
 hpRange={min=185,max=185},sourcePosition={x=0,y=0},ai={kind='nemesis'},intents={
  {id='fire',kind='attack',effects={{op='damage',value=6,times=3}}},
  {id='scythe',kind='attack',effects={{op='damage',value=45}}},
  {id='burn',kind='debuff',effects={{op='makeTempCardInDiscard',card='burn',value=3}}}}}
-- Intangible (monster) and IntangiblePlayer are different source Power objects.
M.status={id='nemesis_intangible',sourceId='Intangible',name='无实体',kind='buff',
 stack='duration',decay='none',priority=75,
 description='每次受到的伤害或生命损失最多为1。自身回合结束时减少1层，首次不减少。'}
local function select(e,id)
 for i,move in ipairs(e.intents)do if move.id==id then e.intentIndex=i;return end end
 error('unknown Nemesis intent: '..tostring(id))
end
function M.advance(state,e,random)
 local n=random(state,100)-1
 e.nemesisCooldown=e.nemesisCooldown-1
 local last,twice=e.nemesisLast,e.nemesisLast=='fire'and e.nemesisPrevious=='fire'
 local id
 if e.nemesisFirst then e.nemesisFirst=false;id=n<50 and 'fire'or 'burn'
 elseif n<30 then
  if last~='scythe'and e.nemesisCooldown<=0 then id='scythe'
  elseif Random.boolean(state,random)then id=twice and 'burn'or 'fire'
  else id=last~='burn'and 'burn'or 'fire'end
 elseif n<65 then
  if not twice then id='fire'
  elseif Random.boolean(state,random)and e.nemesisCooldown<=0 then id='scythe'
  else id='burn'end
 elseif last~='burn'then id='burn'
 elseif Random.boolean(state,random)and e.nemesisCooldown<=0 then id='scythe'
 else id='fire'end
 if id=='scythe'then e.nemesisCooldown=2 end
 e.nemesisPrevious,e.nemesisLast=last,id
 select(e,id)
end
function M.initialize(state,e,random)
 e.nemesisFirst,e.nemesisCooldown=true,0
 e.nemesisLast,e.nemesisPrevious=nil,nil
 M.advance(state,e,random)
end
function M.beforeAction(_,e)
 -- takeTurn tests membership when queueing, before any damage or retaliation.
 e.nemesisApplyIntangible=rawget(e.statuses,'nemesis_intangible')==nil
end
function M.afterEffects(api,state,e)
 if e.nemesisApplyIntangible then
  api.applyPower(state,e,'nemesis_intangible',1,e)
 end
 e.nemesisApplyIntangible=nil
end
function M.applied(e,id,before)
 if id=='nemesis_intangible'and before==nil then e.nemesisIntangibleJustApplied=true end
end
-- MonsterGroup applies these owner-end hooks after ALL monster actions and
-- before the player's atEndOfRound. No player IntangiblePlayer decay is reused.
function M.ownerEnd(api,state,e)
 local n=rawget(e.statuses,'nemesis_intangible')
 if not api.isActive(e)or n==nil then return end
 if e.nemesisIntangibleJustApplied then e.nemesisIntangibleJustApplied=false;return end
 if n<=1 then
  e.statuses.nemesis_intangible=nil
  require('abyss_power_schedule').remove(state,e,'nemesis_intangible')
  local order={};for _,id in ipairs(e.powerOrder or {})do if id~='nemesis_intangible'then order[#order+1]=id end end
  e.powerOrder=order
 else e.statuses.nemesis_intangible=n-1 end
 Events.emit(state,'status',{source=e.id,target=e.id,status='nemesis_intangible',amount=n<=1 and -n or -1})
end
return M
