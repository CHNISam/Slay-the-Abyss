-- Independent definitions and pure-data hooks, pinned to aeubanks/sts@319009d.
-- Combat owns phase order, NORMAL snapshots, transactions and hook dispatch.
local Actors=require('abyss_actor')
local Events=require('abyss_events')
local M={}
local MAX=2147483647
local copy=require('abyss_copy').copy
local function integer(v,lo) return type(v)=='number' and v==v and v%1==0 and v>=(lo or 0) and v<=MAX end
local function gain(id,n) return {op='gainStrengthPower',status=id,value=n} end
local cards={
 {id='heavy_blade',name='重刃',sts_name='Heavy Blade',type='attack',rarity='common',cost=2,
  effects={{op='damage',value=14}},strengthMultiplier=3,upgrade={strengthMultiplier=5},
  text='造成14点伤害。力量对此牌的加成提高为3倍。',upgradeText='造成14点伤害。力量对此牌的加成提高为5倍。'},
 {id='perfected_strike',name='完美打击',sts_name='Perfected Strike',type='attack',rarity='common',cost=2,
  effects={{op='damage',value=6}},strikeBonus=2,sourceTags={'STRIKE'},upgrade={strikeBonus=3},
  text='造成6点伤害。你的抽牌堆、弃牌堆和手牌中每有一张带打击标签的牌，伤害增加2。',
  upgradeText='造成6点伤害。你的抽牌堆、弃牌堆和手牌中每有一张带打击标签的牌，伤害增加3。'},
 {id='combust',name='自燃',sts_name='Combust',type='power',rarity='uncommon',cost=1,
  effects={gain('combust',5)},upgrade={effects={gain('combust',7)}},
  text='每回合结束时，失去1点生命，对所有敌人造成5点伤害。',
  upgradeText='每回合结束时，失去1点生命，对所有敌人造成7点伤害。'},
 {id='rupture',name='撕裂',sts_name='Rupture',type='power',rarity='uncommon',cost=1,
  effects={gain('rupture',1)},upgrade={effects={gain('rupture',2)}},
  text='每当你因自己的效果失去生命，获得1点力量。',upgradeText='每当你因自己的效果失去生命，获得2点力量。'},
 {id='brutality',name='残暴',sts_name='Brutality',type='power',rarity='rare',cost=0,
  effects={gain('brutality',1)},upgrade={innate=true},
  text='在每回合开始时，额外抽1张牌，然后失去1点生命。',
  upgradeText='固有。在每回合开始时，额外抽1张牌，然后失去1点生命。'},
 {id='berserk',name='狂暴',sts_name='Berserk',type='power',rarity='rare',cost=0,
  effects={{op='gainStatus',status='vulnerable',value=2},gain('berserk',1)},
  upgrade={effects={{op='gainStatus',status='vulnerable',value=1},gain('berserk',1)}},
  text='获得2层易伤。在每回合开始时，获得1点能量。',upgradeText='获得1层易伤。在每回合开始时，获得1点能量。'},
 {id='spot_weakness',name='观察弱点',sts_name='Spot Weakness',type='skill',rarity='uncommon',cost=1,
  effects={{op='spotWeakness',value=3}},upgrade={effects={{op='spotWeakness',value=4}}},
  text='如果目标意图是攻击，获得3点力量。',upgradeText='如果目标意图是攻击，获得4点力量。'},
 {id='pummel',name='连续拳',sts_name='Pummel',type='attack',rarity='uncommon',cost=1,exhaust=true,
  effects={{op='damage',value=2,times=4}},upgrade={effects={{op='damage',value=2,times=5}}},
  text='造成2点伤害4次。消耗。',upgradeText='造成2点伤害5次。消耗。'},
 {id='power_through',name='硬撑',sts_name='Power Through',type='skill',rarity='uncommon',cost=1,
  effects={{op='makeTempCardInHand',card='wound',value=2},{op='block',value=15}},
  upgrade={effects={{op='makeTempCardInHand',card='wound',value=2},{op='block',value=20}}},
  text='将2张伤口放入手牌。获得15点格挡。',upgradeText='将2张伤口放入手牌。获得20点格挡。'},
}
local powers={
 {id='rupture',name='撕裂',description='每次自身效果使你失去生命，获得等同于层数的力量。'},
 {id='combust',name='自燃',description='回合结束时按自燃份数失去生命，再对所有敌人造成等同于层数的伤害。'},
 {id='brutality',name='残暴',description='回合开始的正常抽牌之后，额外抽等同于层数的牌，再失去等量生命。'},
 {id='berserk',name='狂暴',description='回合开始时，获得等同于层数的能量。'},
}
local powerIds={rupture=true,combust=true,brutality=true,berserk=true}
local strikeIds={strike=true,twin_strike=true,pommel_strike=true,perfected_strike=true}
function M.withCards(data)
 assert(type(data)=='table' and data.cards and data.cards.cards and data.statuses and data.statuses.statuses,'missing warrior strength data')
 assert(not data.experimentalWarriorStrength,'warrior strength data already prepared')
 local out,seen,statuses=copy(data),{},{}
 for _,card in ipairs(out.cards.cards) do
  assert(not seen[card.id],'duplicate source card');seen[card.id]=card
  if strikeIds[card.id] then
   local tags=card.sourceTags or {};local found=false
   for _,tag in ipairs(tags) do if tag=='STRIKE' then found=true end end
   if not found then tags[#tags+1]='STRIKE' end;card.sourceTags=tags
  end
 end
 for _,card in ipairs(cards) do
  local existing=seen[card.id]
  if existing then
   assert(not existing.experimental and existing.type==card.type and existing.sts_name==card.sts_name
    and type(existing.effects)=='table','incompatible native strength card: '..card.id)
  end
  local c=copy(card);c.color='red';c.experimental=true
  if existing then
   for i,d in ipairs(out.cards.cards) do if d==existing then out.cards.cards[i]=c;break end end
  else out.cards.cards[#out.cards.cards+1]=c end
 end
 if not seen.wound then
  out.cards.cards[#out.cards.cards+1]={id='wound',name='伤口',sts_name='Wound',type='status',rarity='common',cost=-2,
   effects={},text='无法打出。',experimental=true}
 end
 for _,status in ipairs(out.statuses.statuses) do assert(not statuses[status.id],'duplicate source status');statuses[status.id]=status end
 for _,status in ipairs(powers) do
  local existing=statuses[status.id]
  if existing then assert(existing.kind=='buff' and existing.stack=='intensity' and existing.decay=='none',
   'incompatible native strength status: '..status.id) end
  local d=copy(status);d.kind='buff';d.stack='intensity';d.decay='none'
  if existing then
   for i,s in ipairs(out.statuses.statuses) do if s==existing then out.statuses.statuses[i]=d;break end end
  else out.statuses.statuses[#out.statuses.statuses+1]=d end
 end
 out.experimentalWarriorStrength=true;return out
end
local function strike(def)
 for _,tag in ipairs(def.sourceTags or {}) do if tag=='STRIKE' then return true end end
 return strikeIds[def.id]==true
end
function M.adaptDefinition(state,instance,card)
 assert(type(card)=='table' and card~=state.catalog.cards[instance.cardId],'strength adapter requires detached definition')
 if card.id=='heavy_blade' then
  local mult=card.strengthMultiplier;local strength=state.player.statuses.strength or 0
  assert((mult==3 or mult==5) and integer(strength,-999) and strength<=999,'invalid Heavy Blade strength')
  local out=copy(card);out.effects[1].value=out.effects[1].value+0.0+(mult-1)*strength;return out
 elseif card.id=='perfected_strike' then
  assert(card.strikeBonus==2 or card.strikeBonus==3,'invalid Perfected Strike bonus')
  local count,seen=0,{}
  for _,name in ipairs({'hand','draw','discard'}) do
   for _,c in ipairs(state[name]) do
    assert(not seen[c.uid],'duplicate Perfected Strike UID');seen[c.uid]=true
    local d=assert(state.catalog.cards[c.cardId],'unknown Strike card')
    if c.upgraded and d.upgrade and d.upgrade.sourceTags then d=copy(d);d.sourceTags=d.upgrade.sourceTags end
    if strike(d) then count=count+1 end
   end
  end
  local out=copy(card);out.effects[1].value=out.effects[1].value+0.0+count*card.strikeBonus;return out
 end
 return card
end
local function amount(state,id)
 local n=state.player.statuses[id] or 0;assert(integer(n),'invalid strength power amount');return n
end
function M.applyPower(state,id,value)
 assert(powerIds[id] and integer(value,1),'invalid strength power application')
 local before=amount(state,id);assert(integer(before+0.0+value),'strength power overflow')
 local hpLoss
 if id=='combust' then
  hpLoss=state.player.combustHpLoss or 0
  assert(integer(hpLoss) and (before==0 or hpLoss>0) and integer(hpLoss+1),'invalid Combust HP loss')
 end
 local applied=Actors.applyPower(state,state.player,id,value,state.player)
 if applied and hpLoss then
  state.player.combustHpLoss=hpLoss+1
  state.events[#state.events].frame=Events.frame(state)
 end
 return applied
end
local function action(op,value,extra)
 local e={op=op,value=value};for k,v in pairs(extra or {}) do e[k]=v end
 return {kind='effect',effect=e}
end
function M.planHpLost(state,owner,damageAmount)
 assert(type(damageAmount)=='number' and damageAmount==damageAmount,'invalid HP-loss hook amount')
 local result={top={},bottom={}};local n=amount(state,'rupture')
 if damageAmount>0 and owner==state.player and n>0 then
  result.top[1]=action('gainStatus',n,{status='strength'})
 end
 return result
end
function M.planHook(state,id,phase)
 assert(powerIds[id],'unknown strength power hook')
 local result={top={},bottom={}};local n=amount(state,id)
 if n==0 then return result end
 if id=='berserk' and phase=='turn_start' then result.bottom[1]=action('energy',n)
 elseif id=='brutality' and phase=='turn_start_post_draw' then
  result.bottom={action('draw',n),action('loseHp',n)}
 elseif id=='combust' and phase=='turn_end' then
  local living=false;for _,e in ipairs(state.enemies) do if e.hp>0 and not e.escaped then living=true end end
  if living then
   local loss=state.player.combustHpLoss;assert(integer(loss,1),'missing Combust HP-loss count')
   result.bottom={action('loseHp',loss),action('combustDamage',n)}
  end
 end
 return result
end
return M
