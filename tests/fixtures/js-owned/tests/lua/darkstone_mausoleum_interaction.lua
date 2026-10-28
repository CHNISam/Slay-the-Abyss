-- DEPENDENCY PROOF ONLY: real public Act1 win/rewards prefix; explicitly staged
-- Act2 navigation seam below, NOT natural Act2/campaign/native acceptance.
local C,Run,Nodes,Map,Data=require('abyss_combat'),require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data')
local Pool,R,Relics=require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_relic_pool')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)if a==b then return end;eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function snap(r)return C.copy(r,{[r.data]=r.data})end
local function boolean(r,wanted)
 for n=0,31 do local state=R.atCounter(r.eventSeed,n);local nextState=R.cloneState(state)
  if R.randomBoolean(nextState)==wanted then r.miscRng=state;return end
 end
 error('bounded boolean input unavailable')
end
local function front(r,id)
 for n=0,31 do local state=R.atCounter(r.eventSeed,n);local nextState=R.cloneState(state)
  if Relics.rarity('event',R.randomInt(nextState,99))=='uncommon' then r.relicPool.rng=state;break end
 end
 local q=r.relicPool.queues.uncommon
 for i,v in ipairs(q)do if v==id then table.remove(q,i);table.insert(q,1,id);return end end
 error('missing staged source ID')
end
local function enter(r,stagedChapterNavigation)
 r.act,r.floor=2,17;r.unknown.pools=Pool.new('full',false,2)
 local m=Map.generate(r.data,r.runSeed,2);local next=Map.available(m)[1]
 for _,n in ipairs(m.nodes)do if n.id==next.id then n.type='event';n.eventId='mausoleum' end end
 -- This fixture explicitly stages prior chapter navigation; it is not earned history.
 -- Keep the actual pending reward owner intact so Nodes.enter must expire it.
 if stagedChapterNavigation then r.nodeFlow=nil end
 assert(Nodes.enter(r,m,next.id));return m
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Darkstone/Mausoleum '..count..' '..name)end

test('newly equipped Darkstone receives delayed Writhe exactly once, maximum before heal',function()
 local r=Run.new(Data,'42',{experimental=true,campaign=true});local m=enter(r)
 boolean(r,true);front(r,'Darkstone Periapt');r.hp=r.maxHp;local before=snap(r)
 assert(Nodes.chooseEvent(r,'open'));eq(r.nodeFlow.event.obtainedRelicId,'darkstone_periapt')
 eq(r.deck[#r.deck].cardId,'writhe');eq(r.maxHp,before.maxHp+6);eq(r.hp,before.hp+6)
 eq(r.nextDeckUid,before.nextDeckUid+1);eq(r.miscRng.counter,before.miscRng.counter+1)
 eq(r.relicPool.rng.counter,before.relicPool.rng.counter+1);eq(#r.relicPool.queues.uncommon,#before.relicPool.queues.uncommon-1)
 local after=snap(r);eq(Nodes.chooseEvent(r,'open'),false);same(r,after)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(Nodes.chooseEvent(r,'open'),false)
end)

test('old Omamori prevents new Darkstone health and UID gains; false boolean does neither',function()
 for _,cursed in ipairs({true,false})do
  local r=Run.new(Data,'42',{experimental=true,campaign=true});enter(r);assert(Run.obtainRelic(r,'Omamori'))
  boolean(r,cursed);front(r,'Darkstone Periapt');r.hp=1;local before=snap(r)
  assert(Nodes.chooseEvent(r,'open'));eq(r.nodeFlow.event.obtainedRelicId,'darkstone_periapt')
  eq(r.hp,1);eq(r.maxHp,before.maxHp);eq(r.nextDeckUid,before.nextDeckUid)
  eq(r.relicCounters.omamori,cursed and 1 or 2);eq(r.nodeFlow.event.curseBlocked,cursed and true or nil)
 end
end)

test('health refusal rolls back new relic, Writhe, old protection, complete queues and RNG',function()
 local r=Run.new(Data,'42',{experimental=true,campaign=true});enter(r);boolean(r,true);front(r,'Darkstone Periapt')
 r.maxHp=2147483642;local before=snap(r);local event,owner,deck=r.nodeFlow.event,r.relicPool,r.deck
 local ok,why=Nodes.chooseEvent(r,'open');eq(ok,false);eq(why,'invalid_max_hp');same(r,before)
 eq(r.nodeFlow.event,event);eq(r.relicPool,owner);eq(r.deck,deck);eq(r.relicPool.queues.uncommon[1],'Darkstone Periapt')
end)

test('actual public Act1 victory and reward Proceed expire retained combat before staged Act2 event seam',function()
 local r=Run.new(Data,'1',{experimental=true,campaign=true});local m=Map.generate(r.data,r.runSeed,1)
 local first=Map.available(m)[1];assert(Nodes.enter(r,m,first.id));eq(r.phase,'combat')
 for _=1,150 do
  if r.phase~='combat' then break end
  local target
  for i,e in ipairs(r.combat.enemies)do if e.hp>0 and not e.escaped then target=i;break end end
  local chosen
  for _,card in ipairs(r.combat.hand)do
   if C.canPlay(r.combat,card.uid,target or 1) and (not chosen or C.cardDefinition(r.combat,card).type=='attack') then chosen=card end
  end
  if chosen then assert(Run.play(r,chosen.uid,target or 1)) else assert(Run.endTurn(r))end
 end
 eq(r.phase,'reward');eq(r.lastResult.outcome,'victory');assert(r.combat);local old=r.combat
 if not r.rewards.goldClaimed then assert(Run.claimGoldReward(r))end
 assert(Run.claimCardReward(r,1));if r.rewards.potion and not r.rewards.potion.resolved then assert(Run.skipPotionReward(r))end
 assert(Run.leaveCombatRewards(r));eq(r.phase,'map');eq(r.combat,nil);eq(r.pendingCombatRewards.combat,old)
 assert(Nodes.completeCombat(r,m));eq(r.pendingCombatRewards.flow,r.nodeFlow)
 -- The prior chapter-navigation seam is explicitly staged after the actual
 -- public battle/rewards/Proceed prefix; PR234 already supplies Act2 combat.
 print('REAL_ACT1_PREFIX floor='..r.floor..' turn='..old.turn..' hp='..r.hp..' victory='..r.lastResult.outcome..' combat=nil pending=true')
 local max,hp=r.maxHp,r.hp;local nextMap=enter(r,true);eq(r.combat,nil);eq(r.pendingCombatRewards,nil)
 boolean(r,true);front(r,'Darkstone Periapt');assert(Nodes.chooseEvent(r,'open'))
 eq(r.maxHp,max+6);eq(r.hp,hp+6);eq(r.nodeFlow.event.obtainedRelicId,'darkstone_periapt')
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
 -- Stage only a source Act2 queue, then exercise candidate's real resolver.
 r.encounters=require('abyss_encounter_queue').new(r.runSeed,2);r.floor=18
 local before=#r.encounters.normal;local ok,why=Run.startRoomCombat(r,'normal');assert(ok,why)
 eq(r.phase,'combat');eq(#r.encounters.normal,before-1)
 for _,enemy in ipairs(r.combat.enemies)do eq(enemy.ai.kind,'act2')end
end)
print('DARKSTONE_MAUSOLEUM_INTERACTION '..count..' passed')
