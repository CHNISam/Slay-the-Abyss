package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,R,Data=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random'),require('abyss_data')
local StatusPowers=require('abyss_warrior_status_cards')
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function same(a,b)
 assert(type(a)==type(b),'type changed')
 if type(a)~='table' then assert(a==b,'value changed');return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'field added') end
end
local function frozen(root)
 local saved={}
 local function visit(t)
  if type(t)~='table' or saved[t] then return end
  saved[t]={};for k,v in pairs(t) do saved[t][k]=v;visit(v) end
 end
 visit(root)
 return function()
  for t,fields in pairs(saved) do
   for k,v in pairs(fields) do assert(t[k]==v,'reference/value changed '..tostring(k)) end
   for k in pairs(t) do assert(fields[k]~=nil,'field added '..tostring(k)) end
  end
 end
end
local function battle(id,top,extra)
 local run=Run.new(Data,42);assert(Run.obtainPotion(run,id));assert(Run.startCombat(run,'cultist_solo'))
 local s=run.combat;s.hand={};s.draw={};s.discard={}
 if extra then s.draw[#s.draw+1]={cardId=extra,uid=2000} end
 for i=1,(id=='swift_potion' and 2 or 4) do s.draw[#s.draw+1]={cardId='defend',uid=2000+i} end
 s.draw[#s.draw+1]={cardId=top,uid=2100}
 return run,s
end
for _,id in ipairs({'swift_potion','snecko_oil'}) do
 test(id..' keeps Evolve draws behind initial potion actions and leaves player commands usable',function()
  local run,s=battle(id,'dazed','defend');StatusPowers.applyPower(s,'evolve',1)
  local rng=R.cloneState(s.cardRandomRng);local expected={}
  if id=='snecko_oil' then for i=1,4 do expected[i]=R.randomInt(rng,3) end end
  assert(Run.usePotion(run,1));assert(#s.hand==(id=='swift_potion' and 4 or 6))
  assert(not s.cardActions and not s.queuedCards and not s.drainingCardActions and not s.pendingChoice)
  if id=='snecko_oil' then
   for i=2,5 do assert(C.cardDefinition(s,s.hand[i]).cost==expected[i-1]) end
   assert(s.hand[6].uid==2000 and s.hand[6].costOverride==nil and C.cardDefinition(s,s.hand[6]).cost==1,
       'Evolve extra draw must occur after this RandomizeHandCost action')
   same(R.snapshot(s.cardRandomRng),R.snapshot(rng))
  end
  assert(Run.endTurn(run),'resolved draw must not leave card_choice_pending')
 end)
 test(id..' drains FireBreathing after Burn and keeps nonlethal combat usable',function()
  local run,s=battle(id,'burn');StatusPowers.applyPower(s,'fire_breathing',6)
  local hp=s.enemies[1].hp;assert(Run.usePotion(run,1));assert(s.enemies[1].hp==hp-6)
  assert(not s.cardActions and not s.queuedCards and run.phase=='combat');assert(Run.endTurn(run))
 end)
 test(id..' finishes initial costs before triggered victory and resolves rewards without a queue lock',function()
  local run,s=battle(id,'burn');StatusPowers.applyPower(s,'fire_breathing',999)
  local rng=R.cloneState(s.cardRandomRng)
  if id=='snecko_oil' then for i=1,4 do R.randomInt(rng,3) end end
  assert(Run.usePotion(run,1))
  assert(run.phase=='reward' and #run.rewards.cards==3 and run.potions[1]==nil)
  assert(not s.cardActions and not s.queuedCards and not s.pendingChoice);same(R.snapshot(s.cardRandomRng),R.snapshot(rng))
  assert(Run.claimCardReward(run,0));dofile('tests/lua/support/finish_combat_rewards.lua')(run)
  assert(run.phase=='map');assert(Run.startCombat(run,'cultist_solo'));assert(Run.endTurn(run))
 end)
 test(id..' triggered draw failure rolls back every live value and reference',function()
  local run,s=battle(id,'dazed','invalid_draw_fixture');StatusPowers.applyPower(s,'evolve',1)
  local before=C.copy(run);local check=frozen(run)
  local ok,why=Run.usePotion(run,1);assert(not ok and why=='potion_effect_failed')
  same(run,before);check();assert(run.potions[1]==id and not s.cardActions)
 end)
 test(id..' triggered victory reward failure cannot commit potion draw or reward RNG',function()
  local run,s=battle(id,'burn');StatusPowers.applyPower(s,'fire_breathing',999)
  run.cardRng={invalid_reward_fixture=true}
  s.cardRng=run.cardRng -- the current combat owns the continuous reward stream
  local before=C.copy(run);local check=frozen(run)
  local ok,why=Run.usePotion(run,1);assert(not ok and why=='potion_effect_failed')
  same(run,before);check();assert(run.phase=='combat' and run.potions[1]==id)
 end)
end
test('Snecko full hand skips draw/shuffle but still randomizes every eligible existing card',function()
 local run,s=battle('snecko_oil','burn','defend');s.hand={}
 for i=1,10 do s.hand[i]={cardId='defend',uid=3000+i} end
 local piles=C.copy({s.draw,s.discard,s.shuffleRng});local rng=R.cloneState(s.cardRandomRng);local expected={}
 for i=1,10 do expected[i]=R.randomInt(rng,3) end
 assert(Run.usePotion(run,1));same({s.draw,s.discard,s.shuffleRng},piles)
 for i,card in ipairs(s.hand) do assert(C.cardDefinition(s,card).cost==expected[i]) end
 same(R.snapshot(s.cardRandomRng),R.snapshot(rng));assert(not s.cardActions)
end)
test('Snecko random-cost failure rolls back initial draw and leaves trigger tail unpublished',function()
 local run,s=battle('snecko_oil','dazed','defend');StatusPowers.applyPower(s,'evolve',1)
 s.cardRandomRng={invalid_cost_fixture=true}
 local before=C.copy(run);local check=frozen(run)
 local ok,why=Run.usePotion(run,1);assert(not ok and why=='potion_effect_failed')
 same(run,before);check();assert(run.potions[1]=='snecko_oil')
end)
test('Snecko queues all initial actions before the post-use heal and draw-trigger tails',function()
 local run,s=battle('snecko_oil','burn');s.player.hp=20;run.hp=20
 StatusPowers.applyPower(s,'fire_breathing',999)
 local queued=0;local start=#s.events
 assert(Run.usePotion(run,1,nil,function(candidate)
  queued=queued+1
  assert(#candidate.hand==0 and candidate.player.hp==20,'post-use hook runs after queueing, before draining')
  require('abyss_card_actions').enqueue(candidate,{op='heal',value=5})
 end))
 assert(queued==1 and run.phase=='reward')
 local heal,damage
 for i=start+1,#s.events do
  local e=s.events[i]
  if e.kind=='heal' and e.detail.amount==5 then heal=i end
  if e.kind=='damage' and e.detail.target~=s.player.id then damage=damage or i end
 end
 assert(heal and damage and heal<damage,'Toy heal must precede FireBreathing appended by the initial draw')
end)
test('post-use heal resolves after Snecko costs but before Evolve additional draw',function()
 local run,s=battle('snecko_oil','dazed','defend');s.player.hp=20;run.hp=20
 StatusPowers.applyPower(s,'evolve',1)
 local start=#s.events
 assert(Run.usePotion(run,1,nil,function(candidate)
  require('abyss_card_actions').enqueue(candidate,{op='heal',value=5})
 end))
 local frame
 for i=start+1,#s.events do local e=s.events[i];if e.kind=='heal' and e.detail.amount==5 then frame=e.frame end end
 assert(frame and #frame.hand==5 and #s.hand==6 and frame.player.hp==25 and run.hp==25)
 assert(s.hand[6].uid==2000 and s.hand[6].costOverride==nil)
end)
test('post-use hook failure leaves queued potion actions and bottle uncommitted',function()
 local run,s=battle('snecko_oil','dazed','defend');StatusPowers.applyPower(s,'evolve',1)
 local before=C.copy(run);local check=frozen(run)
 local ok,why=Run.usePotion(run,1,nil,function(candidate)
  require('abyss_card_actions').enqueue(candidate,{op='heal',value=5})
  error('post_use_failure_fixture')
 end)
 assert(not ok and why=='potion_effect_failed');same(run,before);check()
end)
print('LUA_POTION_DRAW_QUEUE '..passed..' passed '..failed..' failed')
assert(failed==0)
