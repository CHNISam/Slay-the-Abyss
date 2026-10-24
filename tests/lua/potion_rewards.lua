package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,Run,C,P=require('abyss_sts_random'),require('abyss_run'),require('abyss_combat'),require('abyss_potion_rewards')
local Data=require('abyss_data')
local count=0
local function same(a,b)
    assert(type(a)==type(b))
    if type(a)~='table' then assert(a==b);return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil) end
end
local function test(name,fn) fn();count=count+1;print('ok potion rewards '..count..' - '..name) end
local function won(seed,tier)
    local run=Run.new(Data,seed or 42)
    assert(Run.startCombat(run,'cultist_solo'))
    -- Explicit completed-battle fixture tests reward ownership only. Normal-data
    -- traversal and real card combat are scripts/m2-resource-evidence.mjs.
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    run.encounterTier=tier or 'normal'
    assert(Run.finishCombat(run));return run
end
local function rejected(run,fn,why)
    local before=C.copy(run)
    local ok,reason=fn();assert(ok==false);if why then assert(reason==why,reason) end
    same(run,before)
end
test('all 100 source rarity boundaries retain 65 common 25 uncommon 10 rare',function()
    local buckets={common=0,uncommon=0,rare=0}
    for roll=0,99 do local rarity=P.rarity(roll);buckets[rarity]=buckets[rarity]+1 end
    same(buckets,{common=65,uncommon=25,rare=10})
end)
test('normal elite and Act-one Boss use the same drop roll and modifier',function()
    for _,tier in ipairs({'normal','elite','boss'}) do
        local run=won(42,tier)
        assert(run.rewards.potion and run.rewards.potion.rarity=='common')
        assert(run.potionChanceModifier==-10 and run.shopRng.potion.counter==3)
        assert(run.rewards.potion.id~='poison_potion')
    end
    local missed=won(36);assert(not missed.rewards.potion)
    assert(missed.potionChanceModifier==10 and missed.shopRng.potion.counter==1)
end)
test('claim fills leftmost physical vacancy once without consuming another random draw',function()
    local run=won(42)
    assert(Run.obtainPotion(run,'block_potion'));assert(Run.obtainPotion(run,'energy_potion'))
    run.potions[1]=nil -- explicit sparse-belt ownership fixture
    local rng=R.snapshot(run.shopRng.potion)
    local ok,slot=Run.claimPotionReward(run);assert(ok and slot==1)
    assert(run.potions[1]==run.rewards.potion.id and run.potions[2]=='energy_potion')
    same(R.snapshot(run.shopRng.potion),rng)
    rejected(run,function() return Run.claimPotionReward(run) end,'no_pending_potion_reward')
    assert(Run.claimCardReward(run,0));assert(run.phase=='map')
end)
test('invalid card cannot collect bottle; selecting valid card collects obtainable bottle',function()
    local run=won(42);local id=run.rewards.potion.id
    rejected(run,function() return Run.claimCardReward(run,999) end,'invalid_reward_choice')
    assert(Run.claimCardReward(run,1));assert(run.potions[1]==id and #run.deck==11)
    rejected(run,function() return Run.claimCardReward(run,1) end,'no_pending_reward')
end)
test('full belt rejects atomically and explicit abandonment allows card selection',function()
    local run=won(42)
    for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(run,id)) end
    rejected(run,function() return Run.claimPotionReward(run) end,'potion_slots_full')
    rejected(run,function() return Run.claimCardReward(run,1) end,'potion_slots_full')
    assert(not run.rewards.potion.resolved and #run.deck==10)
    assert(Run.skipPotionReward(run))
    rejected(run,function() return Run.skipPotionReward(run) end,'no_pending_potion_reward')
    assert(Run.claimCardReward(run,1));same(run.potions,{'block_potion','energy_potion','fire_potion'})
end)
test('empty rarity remains unavailable and does not become a common replacement',function()
    local run
    for seed=1,100 do local candidate=won(seed)
        if candidate.rewards.potion and candidate.rewards.potion.rarity=='rare' then run=candidate;break end
    end
    assert(run and run.rewards.potion.unavailable and not run.rewards.potion.id)
    rejected(run,function() return Run.claimPotionReward(run) end,'potion_content_unavailable')
    assert(Run.skipPotionReward(run));assert(Run.claimCardReward(run,0));assert(Run.potionCount(run)==0)
end)
test('existing shared potion stream continues and new run resets counters',function()
    local run=won(42);assert(Run.claimCardReward(run,0))
    local before=run.shopRng.potion.counter
    assert(Run.startCombat(run,'cultist_solo'))
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(run));assert(run.shopRng.potion.counter>before)
    local fresh=Run.new(Data,42);assert(fresh.shopRng==nil and fresh.potionChanceModifier==nil)
    assert(Run.potionCount(fresh)==0)
end)
print('LUA_POTION_REWARDS_PASS '..count)
