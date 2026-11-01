package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,Pool=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_relic_pool')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS permanent '..count..' '..name)end
test('generated source catalog initializes one complete private relic owner',function()
 local run=Run.new(Data,42)
 assert(run.relicPool,'production run must own complete source queues')
 eq(#run.relicPool.queues.common,33);eq(#run.relicPool.queues.uncommon,30)
 eq(#run.relicPool.queues.rare,28);eq(#run.relicPool.queues.shop,17);eq(#run.relicPool.queues.boss,22)
 eq(run.relicPool.rng.counter,5)
 local other=Run.new(Data,42);run.relicPool.queues.common[1]=nil;eq(#other.relicPool.queues.common,33)
end)
test('transaction failure leaves every permanent value and owner unchanged',function()
 local run=Run.new(Data,42);local before=C.copy(run);local deck,owner,data=run.deck,run.relicPool,run.data
 local ok,reason=Run.transaction(run,function(staged)
  staged.gold=1;staged.deck={};R.randomInt(staged.relicPool.rng,99);return false,'rejected'
 end)
 eq(ok,false);eq(reason,'rejected');same(run,before);eq(run.deck,deck);eq(run.relicPool,owner);eq(run.data,data)
 ok,reason=Run.transaction(run,function(staged)staged.hp=1;error('injected failure')end)
 eq(ok,false);same(run,before)
end)
test('Omamori blocks before UID allocation and Ceramic Fish sees only actual obtains',function()
 local run=Run.new(Data,42);assert(Run.obtainRelic(run,'Omamori'));assert(Run.obtainRelic(run,'CeramicFish'))
 local uid,gold=run.nextDeckUid,run.gold
 for _=1,2 do local ok,why=Run.obtainCard(run,'Regret');assert(ok);eq(why,'curse_blocked');eq(run.nextDeckUid,uid);eq(run.gold,gold)end
 local ok,obtained=Run.obtainCard(run,'Regret');assert(ok);eq(obtained,uid);eq(run.nextDeckUid,uid+1);eq(run.gold,gold+9)
end)
test('source relic offer is prepared privately without implementation-driven rerolls',function()
 local run=Run.new(Data,42);run.relicPool.queues.common={'Anchor'}
 local before=C.copy(run);local offer,nextPool=Run.prepareRelic(run,{tier='common',room='event'})
 eq(offer.sourceId,'Anchor');eq(offer.id,'anchor');eq(#nextPool.queues.common,0);same(run,before)
 run.relicPool.queues.common={'Whetstone','Anchor'}
 for i=#run.data.relics.relics,1,-1 do
  local relic=run.data.relics.relics[i]
  if relic.id=='whetstone' or relic.sourceId=='Whetstone' then table.remove(run.data.relics.relics,i)end
 end
 before=C.copy(run)
 local missing,why=Run.prepareRelic(run,{tier='common',room='event'})
 eq(missing,nil);eq(why,'relic_content_unavailable');same(run,before)
end)
test('an offered curse freezes old Omamori before a new relic is equipped',function()
 local run=Run.new(Data,42);local offer=assert(Run.prepareCard(run,'Regret'))
 assert(Run.obtainRelic(run,'Omamori'));local uid=run.nextDeckUid
 local ok,obtained=Run.commitCard(run,offer);assert(ok);eq(obtained,uid);eq(run.relicCounters.omamori,2)
 local before=C.copy(run)
 ok=Run.transaction(run,function(staged)
  assert(Run.prepareCard(staged,'Regret').blocked)
  return Run.obtainRelic(staged,'not_a_source_relic')
 end)
 eq(ok,false);same(run,before)
end)
test('nested obtain commands keep the enclosing event flow current',function()
 local run=Run.new(Data,42);run.nodeFlow={event={stage='intro'}}
 assert(Run.transaction(run,function(staged)
  local event=staged.nodeFlow.event
  assert(Run.obtainCard(staged,'Regret'));event.stage='complete'
  return true
 end))
 eq(run.nodeFlow.event.stage,'complete')
end)

test('a successful permanent command preserves the reward reopening aliases',function()
 local run=Run.new(Data,42)
 run.phase='reward';run.nodeFlow={type='combat',complete=true}
 run.rewards={manualContinue=true};run.combat={phase='victory'}
 assert(Run.leaveCombatRewards(run))
 assert(Run.obtainCard(run,'Regret'))
 eq(run.pendingCombatRewards.flow,run.nodeFlow)
 assert(Run.reopenCombatRewards(run));eq(run.phase,'reward')
end)

test('nested rejections abort the outer transaction even if its caller ignores them',function()
 local run=Run.new(Data,42);local before=C.copy(run);local deck=run.deck
 local ok,reason=Run.transaction(run,function(staged)
  Run.transaction(staged,function(nested)nested.hp=1;return false,'nested_rejected' end)
  return true
 end)
 eq(ok,false);eq(reason,'nested_rejected');same(run,before);eq(run.deck,deck)
end)

test('permanent command preflight failures also abort their enclosing transaction',function()
 for _,command in ipairs({function(r)return Run.obtainRelic(r,'not_a_source_relic')end,
  function(r)return Run.commitCard(r,nil)end})do
  local run=Run.new(Data,42);local before=C.copy(run)
  local ok=Run.transaction(run,function(staged)staged.hp=1;command(staged);return true end)
  eq(ok,false);same(run,before)
 end
end)

test('the copy memo remains compatible with existing assert-expression callers',function()
 local copied=C.copy(assert({marker=true},'readable guard'));eq(copied.marker,true)
 local run=Run.new(Data,42);assert(Run.startRoomCombat(run,'normal'))
 assert(C.cardDefinition(run.combat,run.combat.hand[1]))
end)

test('obtain hooks receive the private card before it joins the permanent deck',function()
 local H=require('abyss_relic_hooks');local original=H.onObtainCard
 local run=Run.new(Data,42);local size=#run.deck;local static=C.copy(run.data.cards)
 H.onObtainCard=function(staged,card,definition)
  eq(#staged.deck,size);eq(card.cardId,'strike');eq(definition.id,'strike')
  card.upgraded=true;card.upgrades=1
  original(staged,card,definition)
 end
 local called,ok,uid=pcall(Run.obtainCard,run,'strike');H.onObtainCard=original
 assert(called and ok,tostring(uid));eq(run.deck[size+1].uid,uid)
 eq(run.deck[size+1].upgrades,1);same(run.data.cards,static)
end)
test('card rewards retain independent item owners without weakening obtain rollback',function()
 local H=require('abyss_relic_hooks');local original=H.onObtainCard
 local run=Run.new(Data,42)
 -- Isolate the reward command, not a natural victory or acquisition run.
 run.phase='reward';run.rewards={cards={'strike'},cardResolved=false,gold=12,goldClaimed=false,
  potion={id='fire_potion',resolved=false},stolenGold={type='STOLEN_GOLD',amount=9,claimed=false}}
 local rewards,potion,cards,stolen=run.rewards,run.rewards.potion,run.rewards.cards,run.rewards.stolenGold
 local before=C.copy(run)
 H.onObtainCard=function(staged,card,definition)
  original(staged,card,definition);staged.gold=1;error('obtain hook failure')
 end
 local called,ok=pcall(Run.claimCardReward,run,1);H.onObtainCard=original
 assert(called and not ok);same(run,before);eq(run.rewards,rewards);eq(run.rewards.potion,potion)
 assert(Run.claimCardReward(run,1));eq(run.rewards,rewards);eq(rewards.cardResolved,true)
 eq(rewards.potion,potion);eq(rewards.cards,cards);eq(rewards.stolenGold,stolen)
 eq(potion.resolved,false);eq(rewards.goldClaimed,false);eq(stolen.claimed,false)
 eq(#run.deck,#before.deck+1);eq(run.nextDeckUid,before.nextDeckUid+1)
 assert(not Run.claimCardReward(run,1));assert(Run.claimPotionReward(run));eq(potion.resolved,true)
 assert(not Run.claimPotionReward(run));assert(Run.claimGoldReward(run));eq(run.gold,before.gold+12)
end)

test('source maximum HP gain heals only its amount and event gold honors Ectoplasm',function()
 local run=Run.new(Data,42);run.hp=30;assert(Run.increaseMaxHp(run,5));eq(run.maxHp,85);eq(run.hp,35)
 run.relics[#run.relics+1]='ectoplasm';local old=run.gold;eq(Run.gainGold(run,175),0);eq(run.gold,old)
end)
print('PERMANENT_TRANSACTIONS '..count..' passed')
