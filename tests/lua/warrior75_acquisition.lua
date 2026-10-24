package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,R,Run,Pool,Shop=require('abyss_combat'),require('abyss_sts_random'),require('abyss_run'),require('abyss_card_pool'),require('abyss_shop')
local data=require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local N=0;local function test(n,f)f();N=N+1;print('ok acquisition '..N..' - '..n)end
test('all 72 nonbasic IDs occupy the original rarity pools exactly once',function()
    local seen,n={},0
    for rarity,ids in pairs(data.cards.sourcePools.reward) do
        eq(#ids,rarity=='common' and 20 or rarity=='uncommon' and 36 or 16)
        for _,id in ipairs(ids) do assert(not seen[id]);seen[id]=true;n=n+1 end
    end
    eq(n,72)
    for _,c in ipairs(data.cards.cards) do
        if c.type~='status' and c.type~='curse' then eq(not not seen[c.id],c.rarity~='basic') end
    end
end)
test('initial and negative-offset rarity boundaries are exact for all rooms',function()
    eq(Pool.rarity(0,5,'normal'),'uncommon');eq(Pool.rarity(34,5,'normal'),'uncommon');eq(Pool.rarity(35,5,'normal'),'common')
    eq(Pool.rarity(4,5,'elite'),'rare');eq(Pool.rarity(5,5,'elite'),'uncommon');eq(Pool.rarity(45,5,'elite'),'common')
    eq(Pool.rarity(3,5,'shop'),'rare');eq(Pool.rarity(4,5,'shop'),'uncommon');eq(Pool.rarity(41,5,'shop'),'common')
    eq(Pool.rarity(0,-40,'normal'),'rare');eq(Pool.rarity(42,-40,'normal'),'rare');eq(Pool.rarity(43,-40,'normal'),'uncommon')
    eq(Pool.rarity(99,5,'boss'),'rare')
end)
test('duplicate identity retries do not reroll rarity or update offset again',function()
    local run=Run.new(data,1);run.encounterTier='normal'
    local originalInt,originalBool=R.randomInt,R.randomBooleanChance
    local draws={99,0,99,0,1,99,2};local at,bounds,floatCount=0,{},0
    R.randomInt=function(_,bound)at=at+1;bounds[at]=bound;return assert(draws[at])end
    R.randomBooleanChance=function(_,chance)eq(chance,0);floatCount=floatCount+1;return false end
    local called,choices,rng,offset=pcall(Pool.prepareRewards,run)
    R.randomInt,R.randomBooleanChance=originalInt,originalBool
    assert(called,choices);eq(offset,2);eq(at,7);eq(floatCount,3)
    eq(table.concat(bounds,','),'99,19,99,19,19,99,19');assert(choices[1]~=choices[2] and choices[2]~=choices[3])
    eq(run.cardRarityOffset,5);eq(run.cardRng.counter,0)
end)
test('Boss still consumes a rarity int per slot but never upgrade floats',function()
    local run=Run.new(data,1);run.encounterTier='boss'
    local originalInt,originalBool=R.randomInt,R.randomBooleanChance
    local seq={99,0,99,1,99,2};local at=0
    R.randomInt=function(_,bound)at=at+1;eq(bound,at%2==1 and 99 or 15);return seq[at]end
    R.randomBooleanChance=function()error('rare must short-circuit upgrade float')end
    local called,choices,rng,offset=pcall(Pool.prepareRewards,run)
    R.randomInt,R.randomBooleanChance=originalInt,originalBool
    assert(called,choices);eq(offset,5);eq(at,6)
end)
test('shop consumes the same shared cardRng history as subsequent rewards',function()
    local run=Run.new(data,123);run.encounterTier='normal'
    local initial=R.snapshot(run.cardRng)
    local stock=Shop.prepare(run);eq(run.cardRng.counter,0);assert(stock.shopRng.card.counter>=12)
    run.shopRng=stock.shopRng;run.cardRng=stock.shopRng.card
    local _,after=Pool.prepareRewards(run);assert(after.counter>run.cardRng.counter)
    local untouched=Run.new(data,123);untouched.encounterTier='normal';local a=Pool.prepareRewards(untouched);local b=Pool.prepareRewards(run)
    assert(table.concat(a,',')~=table.concat(b,','),'shop must change the following reward stream')
end)
test('reward preparation is pure until owner commits and deterministic per full state',function()
    local run=Run.new(data,42);run.encounterTier='normal'
    local a,ra,oa=Pool.prepareRewards(run);local b,rb,ob=Pool.prepareRewards(run)
    eq(table.concat(a,','),table.concat(b,','));eq(ra.counter,rb.counter);eq(oa,ob);eq(run.cardRng.counter,0)
end)
test('each colored card has a real typed shop channel with no basic/status leakage',function()
    local found={}
    for _,rarity in pairs(data.cards.sourcePools.shop) do
        for _,ids in pairs(rarity) do for _,id in ipairs(ids) do found[id]=true end end
    end
    local n=0;for _ in pairs(found) do n=n+1 end;eq(n,72)
    for _,id in ipairs(data.cards.starter_deck.cards) do eq(found[id],nil) end
end)
print('Warrior acquisition '..N..' source-contract groups passed; natural platform evidence pending.')
