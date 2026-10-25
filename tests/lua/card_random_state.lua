-- Source state-core contracts. This does not certify complete reward identities.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Cards = require('abyss_card_random')
local R, Run, Shop, C = require('abyss_sts_random'), require('abyss_run'), require('abyss_shop'), require('abyss_combat')
local Data = require('abyss_data')
local Nodes,Map=require('abyss_nodes'),require('abyss_map')
local passed = 0
local function same(a,b)
    assert(type(a)==type(b),'type mismatch')
    if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a)do same(v,b[k])end
    for k in pairs(b)do assert(a[k]~=nil,'extra field '..tostring(k))end
end
local function test(name,fn) fn();passed=passed+1;print('PASS '..name)end
test('raw signed64 new owner starts independent of per-floor streams',function()
    for _,seed in ipairs({'0','-1','9223372036854775807','-9223372036854775808'})do
        local owner=Cards.new(seed)
        assert(owner.cardRarityOffset==5)
        same(R.snapshot(owner.cardRng),R.snapshot(R.fromSeed(seed)))
        local run=Run.new(Data,seed)
        same(Cards.snapshot(run),Cards.snapshot(owner))
        local before=Cards.snapshot(run);Run.roomStreams(run,12);same(Cards.snapshot(run),before)
    end
end)
test('snapshot and clone have no mutable aliases',function()
    local owner=Cards.new('42');Cards.rewardRarity(owner,'normal')
    local snap=Cards.snapshot(owner);local clone=Cards.clone(owner)
    same(Cards.snapshot(clone),snap);assert(clone.cardRng~=owner.cardRng)
    Cards.rewardRarity(clone,'normal');same(Cards.snapshot(owner),snap)
    local restored=Cards.restore(snap);Cards.upgrade(restored,'common',0)
    same(Cards.snapshot(owner),snap)
    for _,invalid in ipairs({{version=2,cardRng=snap.cardRng,cardRarityOffset=5},
        {version=1,cardRng=snap.cardRng,cardRarityOffset=-41},
        {version=1,cardRng=snap.cardRng,cardRarityOffset=6},
        {version=1,cardRng=snap.cardRng,cardRarityOffset=1.5},
        {version=1,cardRng=snap.cardRng,cardRarityOffset=5,extra=true}})do
        assert(not pcall(Cards.restore,invalid))
    end
end)
test('base room thresholds and offset changes follow source order',function()
    local original=R.randomInt
    local ok,err=pcall(function()
        local owner=Cards.new('42')
        R.randomInt=function(_,bound)assert(bound==99);return 0 end
        assert(Cards.rewardRarity(owner,'normal')=='uncommon' and owner.cardRarityOffset==5)
        assert(Cards.rewardRarity(owner,'elite')=='rare' and owner.cardRarityOffset==5)
        R.randomInt=function()return 99 end
        for _=1,60 do assert(Cards.rewardRarity(owner,'normal')=='common')end
        assert(owner.cardRarityOffset==-40)
        R.randomInt=function()return 42 end
        assert(Cards.rewardRarity(owner,'normal')=='rare' and owner.cardRarityOffset==5)
        local offset=owner.cardRarityOffset
        assert(Cards.rollRarity(owner,'shop')=='common' and owner.cardRarityOffset==offset)
    end)
    R.randomInt=original;assert(ok,err)
end)
test('boss consumes rarity and A0 nonrare upgrade still consumes float',function()
    local owner=Cards.new('42');owner.cardRarityOffset=-40
    assert(Cards.rewardRarity(owner,'boss')=='rare')
    assert(owner.cardRng.counter==1 and owner.cardRarityOffset==5)
    assert(not Cards.upgrade(owner,'rare',0));assert(owner.cardRng.counter==1)
    assert(not Cards.upgrade(owner,'common',0));assert(owner.cardRng.counter==2)
    assert(not Cards.upgrade(owner,'uncommon',0));assert(owner.cardRng.counter==3)
end)
test('invalid contexts or owner refuse before consuming',function()
    local owner=Cards.new('42');local before=Cards.snapshot(owner)
    assert(not pcall(Cards.rollRarity,owner,'invalid'))
    assert(not pcall(Cards.rewardRarity,owner,'shop'))
    assert(not pcall(Cards.upgrade,owner,'basic',0))
    same(Cards.snapshot(owner),before)
end)
test('shop preparation stages unique card owner without changing live state',function()
    local run=Run.new(Data,'42');local before=Cards.snapshot(run)
    local stock=Shop.prepare(run)
    same(Cards.snapshot(run),before)
    assert(stock.cardRandom and stock.cardRandom.cardRng.counter>0)
    assert(stock.shopRng.card==nil and run.shopRng==nil)
    assert(stock.cardRandom.cardRng~=run.cardRng)
end)
local function shopEntry(run,map)
    local routes=dofile('tests/lua/support/map_routes.lua')
    local path=routes.to(map,function(node)return node.type=='shop'end)
    -- Navigation-only prefix, matching the existing shop transaction fixtures.
    for i=1,#path-1 do assert(Map.choose(map,path[i]))end
    return path[#path]
end
test('successful shop entry publishes one owner and no cached card RNG',function()
    local run,map=Run.new(Data,'42'),Map.generate(Data,'42')
    local target=shopEntry(run,map);local initial=run.cardRng
    assert(Nodes.enter(run,map,target))
    assert(run.cardRng~=initial and run.cardRng.counter>0)
    assert(run.shopRng.card==nil and run.nodeFlow.shopRng.card==nil and run.nodeFlow.cardRandom==nil)
    local before=Cards.snapshot(run)
    local potion=require('abyss_potion_rewards')
    local offer,rng,modifier=potion.prepare(run,2)
    potion.commit(run,rng,modifier)
    same(Cards.snapshot(run),before)
    local nextStock=Shop.prepare(run)
    assert(nextStock.cardRandom.cardRng.counter>before.cardRng.counter)
    assert(nextStock.shopRng.card==nil)
end)
test('malformed authoritative stream rejects shop entry before any mutation',function()
    local run,map=Run.new(Data,'42'),Map.generate(Data,'42')
    local target=shopEntry(run,map);run.cardRng={}
    local before=C.copy({run=run,map=map});local reference=run.cardRng
    local called,ok,reason=pcall(Nodes.enter,run,map,target)
    assert(called and not ok and reason=='node_content_unavailable')
    same({run=run,map=map},before);assert(run.cardRng==reference)
end)
print('CARD_RANDOM_STATE '..passed..' passed')
