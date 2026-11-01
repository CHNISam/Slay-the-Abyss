-- Phase-four opt-in definitions/plans; Core owns execution and transactions.
-- Rule facts: aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0.
local Actors=require('abyss_actor')
local Random=require('abyss_sts_random')
local Exhaust=require('abyss_exhaust')
local M={}
local MAX=2147483647
local copy=require('abyss_copy').copy
local function integer(n,lo) return type(n)=='number' and n==n and n%1==0 and n>=(lo or 0) and n<=MAX end
local function make(op,n,extra) local e={op=op,value=n};for k,v in pairs(extra or {}) do e[k]=v end;return e end
local function action(e) return {kind='effect',effect=e} end
local function plan() return {top={},bottom={}} end
local function power(id,n) return make('gainStatusPower',n,{status=id}) end
local function generate(id,pile) return make('makeTempCard',1,{card=id,pile=pile,randomSpot=true}) end
local cards={
 {id='wild_strike',name='狂野打击',sts_name='Wild Strike',type='attack',rarity='common',cost=1,sourceTags={'STRIKE'},
  effects={make('damage',12),generate('wound','draw')},upgrade={effects={make('damage',17),generate('wound','draw')}},
  text='造成12点伤害。将1张伤口洗入抽牌堆。',upgradeText='造成17点伤害。将1张伤口洗入抽牌堆。'},
 {id='reckless_charge',name='莽撞冲锋',sts_name='Reckless Charge',type='attack',rarity='uncommon',cost=0,
  effects={make('damage',7),generate('dazed','draw')},upgrade={effects={make('damage',10),generate('dazed','draw')}},
  text='造成7点伤害。将1张晕眩洗入抽牌堆。',upgradeText='造成10点伤害。将1张晕眩洗入抽牌堆。'},
 {id='intimidate',name='威吓',sts_name='Intimidate',type='skill',rarity='uncommon',cost=0,exhaust=true,
  effects={make('applyStatusAll',1,{status='weak'})},upgrade={effects={make('applyStatusAll',2,{status='weak'})}},
  text='对所有敌人施加1层虚弱。消耗。',upgradeText='对所有敌人施加2层虚弱。消耗。'},
 {id='immolate',name='燔祭',sts_name='Immolate',type='attack',rarity='rare',cost=2,
  effects={make('damageAll',21),make('makeTempCardInDiscard',1,{card='burn'})},
  upgrade={effects={make('damageAll',28),make('makeTempCardInDiscard',1,{card='burn'})}},
  text='对所有敌人造成21点伤害。将1张灼伤放入弃牌堆。',upgradeText='对所有敌人造成28点伤害。将1张灼伤放入弃牌堆。'},
 {id='limit_break',name='突破极限',sts_name='Limit Break',type='skill',rarity='rare',cost=1,exhaust=true,
  effects={make('limitBreak',0)},upgrade={exhaust=false},text='将你的力量翻倍。消耗。',upgradeText='将你的力量翻倍。'},
 {id='sever_soul',name='灵魂切断',sts_name='Sever Soul',type='attack',rarity='uncommon',cost=2,
  effects={make('exhaustNonAttacks',0),make('damage',16)},upgrade={effects={make('exhaustNonAttacks',0),make('damage',22)}},
  text='消耗手牌中所有非攻击牌。造成16点伤害。',upgradeText='消耗手牌中所有非攻击牌。造成22点伤害。'},
 {id='second_wind',name='重振精神',sts_name='Second Wind',type='skill',rarity='uncommon',cost=1,
  effects={make('secondWind',5)},upgrade={effects={make('secondWind',7)}},
  text='消耗手牌中所有非攻击牌。每消耗1张，获得5点格挡。',upgradeText='消耗手牌中所有非攻击牌。每消耗1张，获得7点格挡。'},
 {id='fiend_fire',name='恶魔之焰',sts_name='Fiend Fire',type='attack',rarity='rare',cost=2,exhaust=true,
  effects={make('fiendFire',7)},upgrade={effects={make('fiendFire',10)}},
  text='消耗所有手牌。每消耗1张，对目标造成7点伤害。消耗。',upgradeText='消耗所有手牌。每消耗1张，对目标造成10点伤害。消耗。'},
 {id='flame_barrier',name='火焰屏障',sts_name='Flame Barrier',type='skill',rarity='uncommon',cost=2,
  effects={make('block',12),power('flame_barrier',4)},upgrade={effects={make('block',16),power('flame_barrier',6)}},
  text='获得12点格挡。下回合开始前，每次受到攻击时对攻击者造成4点伤害。',
  upgradeText='获得16点格挡。下回合开始前，每次受到攻击时对攻击者造成6点伤害。'},
 {id='evolve',name='进化',sts_name='Evolve',type='power',rarity='uncommon',cost=1,
  effects={power('evolve',1)},upgrade={effects={power('evolve',2)}},
  text='每当抽到一张状态牌，额外抽1张牌。',upgradeText='每当抽到一张状态牌，额外抽2张牌。'},
 {id='fire_breathing',name='火焰吐息',sts_name='Fire Breathing',type='power',rarity='uncommon',cost=1,
  effects={power('fire_breathing',6)},upgrade={effects={power('fire_breathing',10)}},
  text='每当抽到一张状态牌或诅咒牌，对所有敌人造成6点伤害。',upgradeText='每当抽到一张状态牌或诅咒牌，对所有敌人造成10点伤害。'},
 {id='blood_for_blood',name='以血还血',sts_name='Blood for Blood',type='attack',rarity='uncommon',cost=4,
  effects={make('damage',18)},upgrade={cost=3,effects={make('damage',22)}},
  text='造成18点伤害。本场战斗每次失去生命，本牌耗能降低1。',upgradeText='造成22点伤害。本场战斗每次失去生命，本牌耗能降低1。'},
}
local states={
 {id='wound',name='伤口',sts_name='Wound',type='status',rarity='common',cost=-2,effects={},text='无法打出。'},
 {id='dazed',name='晕眩',sts_name='Dazed',type='status',rarity='common',cost=-2,ethereal=true,effects={},text='无法打出。虚无。'},
 {id='burn',name='灼伤',sts_name='Burn',type='status',rarity='common',cost=-2,effects={},burnDamage=2,
  upgrade={burnDamage=4},text='无法打出。回合结束时受到2点伤害。',upgradeText='无法打出。回合结束时受到4点伤害。'},
}
local powers={
 {id='flame_barrier',name='火焰屏障',description='每次受到攻击时对攻击者造成等同于层数的伤害；下回合开始时移除。'},
 {id='evolve',name='进化',description='抽到状态牌时，额外抽等同于层数的牌。'},
 {id='fire_breathing',name='火焰吐息',description='抽到状态牌或诅咒牌时，对所有敌人造成等同于层数的伤害。'},
}
local powerIds={flame_barrier=true,evolve=true,fire_breathing=true}
M.ops={limitBreak=true,exhaustNonAttacks=true,secondWind=true,fiendFire=true,gainStatusPower=true}
function M.withCards(data)
 assert(type(data)=='table' and data.cards and data.cards.cards and data.statuses and data.statuses.statuses,'missing warrior status data')
 assert(not data.experimentalWarriorStatus,'warrior status data already prepared')
 local out,ids,statusIds=copy(data),{},{}
 for _,c in ipairs(out.cards.cards) do assert(not ids[c.id],'duplicate source card');ids[c.id]=c end
 for _,c in ipairs(cards) do
  local existing=ids[c.id]
  if existing then
   assert(not existing.experimental and existing.type==c.type and existing.sts_name==c.sts_name
    and type(existing.effects)=='table','incompatible native status-build card: '..c.id)
  end
  local d=copy(c);d.color='red';d.experimental=true
  if existing then
   for i,old in ipairs(out.cards.cards) do if old==existing then out.cards.cards[i]=d;break end end
  else out.cards.cards[#out.cards.cards+1]=d end
 end
 for _,c in ipairs(states) do
  local existing=ids[c.id]
  if existing then
   assert(existing.type=='status' and existing.cost==-2 and type(existing.effects)=='table' and next(existing.effects)==nil
    and (existing.ethereal==true)==(c.ethereal==true) and not existing.exhaust,'incompatible reused status card: '..c.id)
   if c.id=='burn' then
    assert((existing.burnDamage==2 and existing.upgrade and existing.upgrade.burnDamage==4)
     or (existing.burnDamage==nil and existing.endTurnDamage==2),'incompatible reused Burn lifecycle')
   end
   -- Normalize only the detached opt-in copy to this helper's lifecycle schema.
   for i,old in ipairs(out.cards.cards) do if old==existing then out.cards.cards[i]=copy(c);break end end
  else out.cards.cards[#out.cards.cards+1]=copy(c) end
 end
 for _,d in ipairs(out.statuses.statuses) do assert(not statusIds[d.id],'duplicate source status');statusIds[d.id]=d end
 for _,d in ipairs(powers) do
  local existing=statusIds[d.id]
  if existing then assert(existing.kind=='buff' and existing.stack=='intensity' and existing.decay=='none',
   'incompatible native status-build Power: '..d.id) end
  local c=copy(d);c.kind='buff';c.stack='intensity';c.decay='none'
  if existing then
   for i,old in ipairs(out.statuses.statuses) do if old==existing then out.statuses.statuses[i]=c;break end end
  else out.statuses.statuses[#out.statuses.statuses+1]=c end
 end
 out.experimentalWarriorStatus=true;return out
end
local function amount(s,id) local n=s.player.statuses[id] or 0;assert(integer(n),'invalid status Power amount');return n end
local function resolved(s,c)
 local d=copy(assert(s.catalog.cards[c.cardId],'unknown status-build card'))
 if c.upgraded then for k,v in pairs(d.upgrade or {}) do d[k]=copy(v) end end;return d
end
function M.adaptDefinition(s,c,d)
 assert(d~=s.catalog.cards[c.cardId],'status adapter requires detached definition')
 if c.cardId=='blood_for_blood' then
  local n=c.turnCost;if n==nil then n=c.combatCost end
  if n~=nil then assert(integer(n),'invalid Blood for Blood cost');d=copy(d);d.cost=n end
 end
 return d
end
function M.prepareEffect(s,e,target)
 assert(M.ops[e.op],'unknown warrior status effect');local out=copy(e)
 if e.op=='secondWind' then out.fixedBlock=Actors.blockAmount(s,s.player,e.value)
 elseif e.op=='fiendFire' then
  assert(Actors.isActive(target),'Fiend Fire requires an active target')
  out.targetId=target.id;out.normalAmount=Actors.attackAmount(s,s.player,target,e.value)
 end
 return out
end
-- TOP is execution order. Host pushes this list in REVERSE with pushTop.
function M.planEffect(s,e)
 assert(M.ops[e.op],'unknown warrior status effect');local p=plan()
 if e.op=='limitBreak' then
  local n=s.player.statuses.strength
  if n~=nil then assert(integer(n,-999) and n<=999,'invalid signed Strength');p.top[1]=action(make('gainStatus',n,{status='strength'})) end
 elseif e.op=='exhaustNonAttacks' or e.op=='secondWind' then
  local count=0
  for i=#s.hand,1,-1 do
   local c=s.hand[i]
   if resolved(s,c).type~='attack' then p.top[#p.top+1]=action(make('exhaustHand',0,{uid=c.uid}));count=count+1 end
  end
  if e.op=='secondWind' then
   assert(integer(e.fixedBlock),'Second Wind must be prepared')
   for _=1,count do p.top[#p.top+1]=action(make('block',e.fixedBlock,{fixed=true})) end
  end
 elseif e.op=='fiendFire' then
  assert(integer(e.normalAmount) and type(e.targetId)=='string','Fiend Fire must be prepared')
  for _=1,#s.hand do p.top[#p.top+1]=action(make('exhaustRandomAny',1)) end
  for _=1,#s.hand do p.top[#p.top+1]=action(make('damage',e.value,{normalAmount=e.normalAmount,targetId=e.targetId})) end
 elseif e.op=='gainStatusPower' then error('gainStatusPower requires applyPower, not a plan') end
 return p
end
function M.exhaustRandomAny(s,queue)
 if #s.hand==0 then return true end
 local context={onExhaustRelics=s.onExhaustRelics or {}}
 for _,c in ipairs(s.hand) do Exhaust.plan(s,c,context) end
 assert(s.cardRandomRng,'Fiend Fire requires cardRandomRng');Random.snapshot(s.cardRandomRng)
 local c=s.hand[Random.randomInt(s.cardRandomRng,#s.hand-1)+1]
 return Exhaust.move(s,c,'hand',queue,context)
end
function M.applyPower(s,id,n)
 assert(powerIds[id] and integer(n,1),'invalid status Power application')
 local applied=Actors.applyPower(s,s.player,id,n,s.player)
 if applied and (id=='evolve' or id=='fire_breathing') then
  s.statusDrawPowerOrder=s.statusDrawPowerOrder or {};local found=false
  for _,old in ipairs(s.statusDrawPowerOrder) do if old==id then found=true end end
  if not found then s.statusDrawPowerOrder[#s.statusDrawPowerOrder+1]=id end
 end
 return applied
end
function M.onDraw(s,c,id)
 local p=plan();local d=resolved(s,c)
 local order=id and {id} or s.statusDrawPowerOrder or {}
 if not id then
  local found={};for _,key in ipairs(order) do assert((key=='evolve' or key=='fire_breathing') and not found[key],'invalid status draw order');found[key]=true end
  for _,key in ipairs({'evolve','fire_breathing'}) do assert(amount(s,key)==0 or found[key],'missing status draw Power order') end
 end
 for _,key in ipairs(order) do
  local n=amount(s,key)
  if key=='evolve' and n>0 and d.type=='status' and not s.player.noDraw then p.bottom[#p.bottom+1]=action(make('draw',n))
  elseif key=='fire_breathing' and n>0 and (d.type=='status' or d.type=='curse') then p.bottom[#p.bottom+1]=action(make('statusFireDamage',n))
  else assert(key=='evolve' or key=='fire_breathing','unknown draw Power') end
 end
 return p
end
function M.onAttacked(s,owner,damageType)
 assert(damageType=='NORMAL' or damageType=='THORNS' or damageType=='HP_LOSS','unknown attack damage type')
 local p=plan();local n=amount(s,'flame_barrier')
 if n>0 and owner and owner~=s.player and damageType=='NORMAL' then
  assert(type(owner.id)=='string','Flame Barrier attacker needs identity')
  p.top[1]=action(make('flameBarrierDamage',n,{targetId=owner.id}))
 end
 return p
end
function M.planHook(s,id,phase)
 assert(id=='flame_barrier' and phase=='turn_start','unknown warrior status phase hook')
 local p=plan();if amount(s,id)>0 then p.bottom[1]=action(make('removeStatusPower',0,{status=id})) end;return p
end
local function cost(s,c)
 local d=resolved(s,c);local base=c.combatCost or d.cost;local turn=c.turnCost
 if turn==nil then turn=base end
 assert(integer(base) and integer(turn),'invalid Blood for Blood cost metadata');return base,turn
end
function M.onHpLost(s,n)
 assert(integer(n),'invalid Blood for Blood HP loss');if n==0 then return false end
 local times=s.player.damagedThisCombat or 0;assert(integer(times) and integer(times+1),'damagedThisCombat overflow')
 local changes={};local seen={}
 for _,name in ipairs({'hand','draw','discard'}) do
  for _,c in ipairs(s[name]) do
   assert(not seen[c.uid],'duplicate damage-notification UID');seen[c.uid]=true
   if c.cardId=='blood_for_blood' then
    local base,turn=cost(s,c);local nextBase=math.max(0,base-1)
    if nextBase~=base then changes[#changes+1]={card=c,base=nextBase,turn=math.max(0,turn-1)} end
   end
  end
 end
 for _,change in ipairs(changes) do change.card.combatCost=change.base;change.card.turnCost=change.turn end
 s.player.damagedThisCombat=times+1;return true
end
function M.created(s,c,mode,source)
 if c.cardId~='blood_for_blood' then return false end
 assert(mode=='make_copy' or mode=='stat_equivalent','Blood for Blood creation mode must be explicit')
 if mode=='stat_equivalent' then
  assert(source and source.cardId==c.cardId and source.upgraded==c.upgraded,'incompatible Blood for Blood source copy')
  local base,turn=cost(s,source);c.combatCost=base;c.turnCost=turn
 else
  local times=s.player.damagedThisCombat or 0;assert(integer(times),'invalid damagedThisCombat')
  c.combatCost=math.max(0,resolved(s,c).cost-times);c.turnCost=c.combatCost
 end
 return true
end
-- Host invokes before changing the upgraded flag. Catalog upgrade damage is
-- still applied by ordinary definition merging, never copied into the instance.
function M.onUpgrade(s,c)
 assert(c.cardId=='blood_for_blood' and not c.upgraded,'invalid Blood for Blood upgrade')
 local base,turn=cost(s,c);local rawBase=base<4 and base-1 or 3
 c.combatCost=math.max(0,rawBase);c.turnCost=turn>0 and math.max(0,rawBase+turn-base) or 0
 return true
end
return M
