-- Explicit campaign boundary fixtures, not a natural route or later-act content
-- certification. Build the modifier through its real reward owner.
local Run=require('abyss_run')
local Nodes=require('abyss_nodes')
local Map=require('abyss_map')
local Data=require('abyss_data')
local Combat=require('abyss_combat')
local Queue=require('abyss_encounter_queue')
local PotionRewards=require('abyss_potion_rewards')
local Random=require('abyss_sts_random')
local Acts=require('abyss_acts')
local count=0
local function same(a,b,path)
    path=path or 'state';assert(type(a)==type(b),path)
    if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok potion chapter boundary '..count..' - '..name)end
local function terminal(act)
    local run=Run.new(Data,'13',{experimental=true,campaign=true})
    for _=1,3 do
        local offer,rng,modifier=PotionRewards.prepare(run,2)
        assert(offer and not offer.unavailable,'seed must offer three supported potions')
        PotionRewards.commit(run,rng,modifier)
    end
    assert(run.potionChanceModifier==-30)
    local map=Map.generate(Data,run.runSeed,act)
    while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id))end
    run.act,run.phase,run.floor=act,'node',Acts.get(act).last
    if act~=1 then run.encounters=Queue.new(run.runSeed,act)end
    run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='treasure',roomKind='boss_treasure',
        mapSeed=map.seed,mapSignature=map.sourceSignature,complete=false,reward={relics={}}}
    assert(Nodes.claimBossTreasure(run,0))
    return run,map
end

test('both boss chest transitions reset the actual owner without rewinding the potion stream',function()
    for act=1,2 do
        local run,map=terminal(act)
        local potionStream=Random.snapshot(run.shopRng.potion)
        assert(Nodes.advanceAct(run,map))
        assert(run.act==act+1 and run.potionChanceModifier==0,
            'chapter transition failed to reset actual potion reward modifier')
        assert(run.blizzardPotionMod==nil,'transition created an unused potion owner')
        same(Random.snapshot(run.shopRng.potion),potionStream)
        local expected=Combat.copy(run);expected.potionChanceModifier=0
        local offer,rng,modifier=PotionRewards.prepare(run,2)
        local expectedOffer,expectedRng,expectedModifier=PotionRewards.prepare(expected,2)
        same(offer,expectedOffer);same(Random.snapshot(rng),Random.snapshot(expectedRng))
        assert(modifier==expectedModifier,'next potion reward used the previous chapter modifier')
    end
end)

test('a failed replacement map leaves modifier and every run/map owner unchanged',function()
    local run,map=terminal(1)
    local before=Combat.copy({run=run,map=map})
    local modifierOwner,potionOwner=run.shopRng,run.shopRng.potion
    local generate=Map.generate
    Map.generate=function()error('forced replacement-map failure')end
    local called,ok,reason=pcall(Nodes.advanceAct,run,map)
    Map.generate=generate
    assert(called and not ok and reason=='transaction_failed')
    same({run=run,map=map},before)
    assert(run.shopRng==modifierOwner and run.shopRng.potion==potionOwner)
    assert(run.potionChanceModifier==-30 and run.blizzardPotionMod==nil)
    assert(Nodes.advanceAct(run,map));assert(run.potionChanceModifier==0)
end)
print('CROSS_ACT_POTION_RESET_PASS '..count)
