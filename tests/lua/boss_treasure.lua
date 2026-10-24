-- Reward-boundary fixture only: navigation is staged, then a real Boss combat's
-- terminal state is supplied. This is not evidence of a normal 17-floor clear.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run, Nodes, Map = require('abyss_run'), require('abyss_nodes'), require('abyss_map')
local Combat, data = require('abyss_combat'), require('abyss_data')
local count = 0
local function equal(a,b) if a ~= b then error(tostring(a)..' ~= '..tostring(b),2) end end
local function same(a,b)
    equal(type(a),type(b)); if type(a)~='table' then equal(a,b); return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,'unexpected key '..tostring(k)) end
end
local function test(name,fn) fn();count=count+1;print('ok boss treasure '..count..' - '..name) end
local function beforeChest(seed)
    local run,map=Run.new(data,seed or 42),Map.generate(data,seed or 42)
    while Map.available(map)[1].floor<16 do assert(Map.choose(map,Map.available(map)[1].id)) end
    assert(Nodes.enter(run,map,Map.available(map)[1].id))
    equal(run.phase,'combat');equal(run.floor,16)
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(run)); equal(run.phase,'reward')
    assert(Run.claimCardReward(run,0)); assert(Nodes.completeCombat(run,map))
    equal(run.phase,'map');equal(run.nodeFlow.result,'boss_victory')
    return run,map
end
local function chest(seed)
    local run,map=beforeChest(seed)
    local node=Nodes.available(run,map)[1];equal(node.roomKind,'boss_treasure');equal(node.floor,17)
    assert(Nodes.enter(run,map,node.id));return run,map
end
test('Boss card reward precedes a distinct three-choice Boss chest',function()
    local run,map=chest()
    equal(run.floor,17);equal(run.phase,'node');equal(run.nodeFlow.roomKind,'boss_treasure')
    equal(#run.nodeFlow.reward.relics,3);equal(run.nodeFlow.reward.relicId,nil);equal(run.nodeFlow.reward.gold,nil)
    equal(#Nodes.available(run,map),0)
    local seen={}
    for _,id in ipairs(run.nodeFlow.reward.relics) do assert(not seen[id]);seen[id]=true end
    assert(seen.black_blood and seen.slavers_collar and seen.sozu)
    local view=Nodes.view(run,map); view.node.reward.relics[1]='anchor'
    assert(run.nodeFlow.reward.relics[1]~='anchor')
end)
test('every choice and explicit skip settles once without extra gold or cards',function()
    for choice=0,3 do
        local run,map=chest();local before=Combat.copy(run)
        for _,invalid in ipairs({-1,4,0.5,'1',false,{},math.huge,0/0}) do
            equal(Nodes.claimBossTreasure(run,invalid),false);same(run,before)
        end
        equal(Nodes.claimBossTreasure(run,nil),false);same(run,before)
        equal(Nodes.claimTreasure(run),false);same(run,before)
        local selected=run.nodeFlow.reward.relics[choice]
        assert(Nodes.claimBossTreasure(run,choice))
        equal(run.phase,'victory');equal(run.nodeFlow.result,'boss_treasure_complete')
        equal(run.gold,before.gold);same(run.deck,before.deck);equal(run.seed,before.seed)
        equal(run.hp,before.hp);equal(run.victories,before.victories)
        if selected=='black_blood' then same(run.relics,{'black_blood'})
        elseif selected then same(run.relics,{'burning_blood',selected})
        else same(run.relics,before.relics) end
        local settled=Combat.copy(run)
        equal(Nodes.claimBossTreasure(run,choice),false);equal(Nodes.claimTreasure(run),false)
        equal(Nodes.completeCombat(run,map),false);same(run,settled)
        equal(#Nodes.available(run,map),0)
    end
end)
test('eligibility excludes owned relics and Black Blood without its starter',function()
    local run,map=beforeChest();run.relics={'sozu'}
    assert(Nodes.enter(run,map,Nodes.available(run,map)[1].id))
    same(run.nodeFlow.reward.relics,{'slavers_collar'})
    assert(Nodes.claimBossTreasure(run,1));same(run.relics,{'sozu','slavers_collar'})
end)
test('Black Blood replacement rechecks eligibility before committing',function()
    local run=chest();local index
    for i,id in ipairs(run.nodeFlow.reward.relics) do if id=='black_blood' then index=i end end
    run.relics={};local before=Combat.copy(run)
    equal(Nodes.claimBossTreasure(run,index),false);same(run,before)
end)
test('ordinary relic rooms never offer Boss relics',function()
    for _,kind in ipairs({'treasure','shop'}) do
        local run,map=Run.new(data,42),Map.generate(data,42)
        while true do
            local available=Map.available(map);local target
            for _,node in ipairs(available) do if node.type==kind and not node.roomKind then target=node end end
            if target then
                assert(Nodes.enter(run,map,target.id))
                local ids=kind=='shop' and run.nodeFlow.relics or {{id=run.nodeFlow.reward.relicId}}
                for _,offer in ipairs(ids) do assert(offer.id~='black_blood' and offer.id~='sozu' and offer.id~='slavers_collar') end
                break
            end
            assert(#available>0,'fixture missing room');assert(Map.choose(map,available[1].id))
        end
    end
end)
test('fresh Run clears relics, pending chest and all run counters',function()
    local old=chest();assert(Nodes.claimBossTreasure(old,1))
    local fresh=Run.new(data,42)
    same(fresh.relics,{'burning_blood'});equal(fresh.nodeFlow,nil);equal(fresh.phase,'map')
    equal(fresh.victories,0);equal(fresh.elapsedSeconds,0);equal(fresh.eventRng.counter,0)
end)
print('LUA_BOSS_TREASURE_PASS '..count)
