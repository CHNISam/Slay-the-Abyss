-- TASK-15.17: fixed MonsterHelper spawnSmallSlimes source, not full RNG parity.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Run, Map, Nodes = require('abyss_run'), require('abyss_map'), require('abyss_nodes')
local C, R, Data = require('abyss_combat'), require('abyss_sts_random'), require('abyss_data')
local first,last=...
first,last=first or 1,last or 6
assert(first>=1 and last<=18 and first<=last,'invalid budget slice')
local count, failed, registered = 0, 0, 0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b,path)
    path=path or 'state';eq(type(a),type(b),path)
    if type(a)~='table' then eq(a,b,path);return end
    for k,v in pairs(a) do same(v,b[k],path..'.'..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,path..' missing '..tostring(k)) end
end
-- Freeze every existing table's contents and identity, not only root equality.
local function freeze(...)
    local refs={}
    local function visit(t)
        if type(t)~='table' or refs[t] then return end
        local fields={};refs[t]=fields
        for k,v in pairs(t) do fields[k]=v;visit(v) end
    end
    for _,v in ipairs({...}) do visit(v) end
    return function()
        for t,fields in pairs(refs) do
            for k,v in pairs(fields) do eq(t[k],v,'preserved field '..tostring(k)) end
            for k in pairs(t) do assert(fields[k]~=nil,'unexpected field '..tostring(k)) end
        end
    end
end
local function test(name,fn)
    registered=registered+1;if registered<first or registered>last then return end
    count=count+1;local ok,err=pcall(fn)
    if not ok then failed=failed+1 end
    print((ok and 'ok ' or 'not ok ')..registered..' - '..name..(ok and '' or ': '..tostring(err)))
end
local function ids(battle)
    local result={};for i,e in ipairs(battle.enemies) do result[i]=e.definitionId end;return result
end
local function pair(flag)
    return flag and {'spike_slime_s','acid_slime_m'} or {'acid_slime_s','spike_slime_m'}
end
local function observe(flag,fn)
    local original,calls=R.randomBoolean,0
    local first=true
    R.randomBoolean=function(state)
        local actual=original(state)
        if not first then return actual end -- source Acid S has its own ai Boolean
        first=false;calls=calls+1;if flag==nil then return actual end;return flag
    end
    local ok,why=pcall(fn,function() return calls end)
    R.randomBoolean=original;assert(ok,why)
end
local function expected(run,floor)
    local stream=Run.roomStreams(run,floor or run.floor).miscRng;local flag=R.randomBoolean(stream)
    return pair(flag),stream
end
local function fresh()
    local run,map=Run.new(Data,3),Map.generate(Data,3)
    return run,map,Map.available(map)[1].id
end

for _,flag in ipairs({false,true}) do
    test('direct Run selects source '..tostring(flag)..' slots and exactly one current misc Boolean',function()
        local run=Run.new(Data,42)
        for _=1,7 do R.randomInt(run.miscRng,999) end
        local wanted=R.cloneState(run.miscRng);R.randomBoolean(wanted)
        local oldMisc,oldEvent,oldData,oldDeck=run.miscRng,run.eventRng,run.data,run.deck
        local unchanged=freeze(oldMisc,oldEvent,oldData,oldDeck)
        observe(flag,function(calls)
            assert(Run.startCombat(run,'small_slimes'));same(ids(run.combat),pair(flag));eq(calls(),1)
            same(run.miscRng,wanted);eq(run.eventRng,oldEvent);eq(run.data,oldData);eq(run.deck,oldDeck)
            unchanged()
            local stable=freeze(run);local ok,reason=Run.startCombat(run,'small_slimes')
            eq(ok,false);eq(reason,'not_on_map');eq(calls(),1);stable()
        end)
    end)
end

test('untouched seed3 enters its first source Small Slimes queue item and keeps the floor stream',function()
    local run,map,id=fresh();local wanted,stream=expected(run)
    assert(Nodes.enter(run,map,id));eq(run.encounterId,'small_slimes');same(ids(run.combat),wanted)
    same(run.miscRng,stream);eq(run.miscRng.counter,1);eq(run.floor,1);eq(map.path[1],id)
    local stable=freeze(run,map);Nodes.view(run,map);Nodes.view(run,map)
    eq(Nodes.enter(run,map,id),false);eq(Run.startCombat(run,'small_slimes'),false);stable()
    local again,againMap=fresh();assert(Nodes.enter(again,againMap,id));same(run,again);same(map,againMap)
end)

test('normal Nodes reconstructs misc from raw seed plus destination floor',function()
    local run,map,id=fresh()
    for _=1,11 do R.randomInt(run.miscRng,999) end
    local wanted,stream=expected(run);local event=run.eventRng;local unchanged=freeze(event)
    assert(Nodes.enter(run,map,id));same(ids(run.combat),wanted);same(run.miscRng,stream)
    eq(run.miscRng.counter,1);same(run.eventRng,event);unchanged()
end)

local function unknown()
    -- Position the actual seed7 second-floor unknown frontier and consume its
    -- preceding Cultist queue item. This isolates entry, not prior victory.
    local run,map,id=Run.new(Data,7),Map.generate(Data,7),'f2_l4'
    assert(Map.choose(map,'f1_l4'))
    local source,nextQueue=require('abyss_encounter_queue').consume(run.encounters,'normal')
    eq(source,'Cultist');run.encounters=nextQueue
    return run,map,id
end
for _,flag in ipairs({false,true}) do
    test('unknown-to-combat '..tostring(flag)..' preserves room roll, symbol and the one committed misc draw',function()
        local run,map,id=unknown()
        local wantedEvent=R.cloneState(run.eventRng);local roll=R.randomFloat(wantedEvent)
        assert(roll<.1,'seed7 unknown route witness changed')
        local wantedMisc=Run.roomStreams(run,2).miscRng;R.randomBoolean(wantedMisc)
        local oldUnknown=C.copy(run.unknown)
        observe(flag,function(calls)
            assert(Nodes.enter(run,map,id));eq(run.nodeFlow.sourceType,'event');eq(run.nodeFlow.type,'combat')
            eq(run.encounterId,'small_slimes');same(ids(run.combat),pair(flag));eq(calls(),1)
            same(run.eventRng,wantedEvent);same(run.miscRng,wantedMisc)
            eq(run.unknown.chances.monster,oldUnknown.chances.monster)
            eq(run.unknown.chances.shop,R.float32(oldUnknown.chances.shop*2))
            eq(run.unknown.chances.treasure,R.float32(oldUnknown.chances.treasure*2))
            same(run.unknown.pools,oldUnknown.pools)
            for _,node in ipairs(map.nodes) do if node.id==id then eq(node.type,'event') end end
            local stable=freeze(run,map);eq(Nodes.enter(run,map,id),false);eq(calls(),1);stable()
        end)
    end)
end

test('normal seed7 plays the first battle then reaches a natural unknown small_slimes combat',function()
    local run,map=Run.new(Data,7),Map.generate(Data,7)
    assert(Nodes.enter(run,map,'f1_l4'))
    -- Original HP, starting deck, enemy values and legal commands throughout.
    for _=1,200 do
        if run.phase~='combat' then break end
        local target
        for index,enemy in ipairs(run.combat.enemies) do if enemy.hp>0 then target=index;break end end
        local chosen
        for _,card in ipairs(run.combat.hand) do
            if C.canPlay(run.combat,card.uid,target) then
                chosen=card;if C.cardDefinition(run.combat,card).type=='attack' then break end
            end
        end
        if chosen then assert(Run.play(run,chosen.uid,target)) else assert(Run.endTurn(run)) end
    end
    eq(run.phase,'reward')
    if run.rewards.potion and not run.rewards.potion.resolved then assert(Run.skipPotionReward(run)) end
    assert(Run.claimCardReward(run,0))
    if run.phase=='reward' then assert(Run.leaveCombatRewards(run)) end
    assert(Nodes.completeCombat(run,map))
    local wanted,stream=expected(run,2)
    assert(Nodes.enter(run,map,'f2_l4'))
    eq(run.nodeFlow.sourceType,'event');eq(run.nodeFlow.type,'combat');eq(run.encounterId,'small_slimes')
    same(ids(run.combat),wanted);same(run.miscRng,stream);eq(map.path[1],'f1_l4');eq(map.path[2],'f2_l4')
    eq(run.floor,2);assert(run.hp>0);eq(run.victories,1)
end)

test('invalid, unavailable and mismatched node requests preserve all existing table references',function()
    local run,map,id=fresh();local stable=freeze(run,map)
    eq(Nodes.enter(run,map,'missing'),false);stable()
    eq(Nodes.enter(run,map,'f2_l2'),false);stable()
    assert(Nodes.enter(run,map,id))
    -- A completed flow from another map is an explicit host ownership fixture.
    run.phase='map';run.nodeFlow.complete=true;run.nodeFlow.mapSeed=-1
    stable=freeze(run,map);local ok,reason=Nodes.enter(run,map,'f2_l2')
    eq(ok,false);eq(reason,'map_mismatch');stable()
end)

for _,entry in ipairs({'direct','normal','unknown'}) do
    for _,failure in ipairs({'return','throw'}) do
        test(entry..' construction '..failure..' preserves every existing reference and retry matches fresh success',function()
            local setup=entry=='unknown' and unknown or fresh
            local run,map,id=setup();local pristine,pristineMap=setup()
            local stable=freeze(run,map);local original=C.new;local constructed=0
            C.new=function(...)
                local battle,reason=original(...);assert(battle,reason);constructed=constructed+1
                if failure=='throw' then error('injected failure after real construction') end
                return nil,'injected_construction_failure'
            end
            local called,ok,reason=pcall(function()
                if entry=='direct' then return Run.startCombat(run,'small_slimes') end
                return Nodes.enter(run,map,id)
            end)
            C.new=original;eq(constructed,1)
            if entry=='direct' and failure=='throw' then eq(called,false)
            else eq(called,true);eq(ok,false);assert(type(reason)=='string') end
            stable()
            if entry=='direct' then
                assert(Run.startCombat(run,'small_slimes'));assert(Run.startCombat(pristine,'small_slimes'))
            else assert(Nodes.enter(run,map,id));assert(Nodes.enter(pristine,pristineMap,id)) end
            same(run,pristine);same(map,pristineMap);eq(run.miscRng.counter,1)
        end)
    end
end

test('post-draw relic rejection does not commit the staged group or misc state',function()
    local I=require('abyss_inventory');local original=I.applyOpening
    local run,map,id=fresh();local stable=freeze(run,map);local calls=0
    I.applyOpening=function(...)
        calls=calls+1;local ok,reason=original(...);assert(ok,reason)
        if calls==2 then return false,'injected_tail_failure' end
        return ok,reason
    end
    local called,ok,reason=pcall(Nodes.enter,run,map,id);I.applyOpening=original
    eq(called,true);eq(ok,false);eq(reason,'injected_tail_failure');eq(calls,2);stable()
    assert(Nodes.enter(run,map,id));eq(run.miscRng.counter,1)
end)

test('invalid IDs, floors and relic configuration reject before drawing',function()
    for _,mode in ipairs({'id','floor','relic'}) do
        local run=Run.new(Data,1);local id='small_slimes'
        if mode=='id' then id='missing' elseif mode=='floor' then run.floor=15 else run.relics={'missing'} end
        local stable=freeze(run);observe(nil,function(calls)
            eq(Run.startCombat(run,id),false);eq(calls(),0);stable()
        end)
    end
end)

test('explicit low-level enemy arrays do not acquire implicit encounter selection',function()
    local battle=C.new(Data,{seed=42,enemies={'acid_slime_s','spike_slime_s'}})
    same(ids(battle),{'acid_slime_s','spike_slime_s'})
end)

local unchangedGroups={
    cultist_solo={'cultist'},jaw_solo={'jaw_worm'},louse_pair={'red_louse','red_louse'},
    louse_trio={'red_louse','red_louse','green_louse'},medium_slimes={'acid_slime_m','spike_slime_m'},
    large_acid={'acid_slime_l'},large_spike={'spike_slime_l'},looter_solo={'looter'},
    blue_slaver_solo={'blue_slaver'},red_slaver_solo={'red_slaver'},fungi_pair={'fungi_beast','fungi_beast'},
    wildlife={'jaw_worm','green_louse'},elite_nob={'gremlin_nob'},elite_lagavulin={'lagavulin'},
    elite_sentries={'sentry','sentry','sentry'},boss_guardian={'guardian'}
}
test('other 16 static encounter groups retain their member order and consume no misc selection draw',function()
    local seen=0
    for _,e in ipairs(Data.enemies.encounters) do if e.id~='small_slimes' and e.id~='gremlin_gang' then
        seen=seen+1;local run=Run.new(Data,42);run.floor=e.minFloor
        local deckOwner,deckBefore,unchangedDeck=run.deck,C.copy(run.deck),freeze(run.deck)
        local misc=run.miscRng;local stable=freeze(misc)
        assert(Run.startCombat(run,e.id));same(ids(run.combat),assert(unchangedGroups[e.id]))
        if e.louseCount then
            local wanted=R.cloneState(misc);for _=1,e.louseCount do R.randomBoolean(wanted) end
            same(run.miscRng,wanted)
        else eq(run.miscRng,misc) end
        stable()
        local reference=C.new(run.data,{seed=run.seed,hp=run.hp,maxHp=run.maxHp,gold=run.gold,
            cardRandomSeed=string.format('%.0f',tonumber(run.eventSeed)+run.floor),shuffleSeed=string.format('%.0f',tonumber(run.eventSeed)+run.floor),enemies=unchangedGroups[e.id],deck=run.deck,
            masterDeck=run.deck,miscRng=run.miscRng,cardRng=run.cardRng,
            beforeFirstTurn=function(state)
                state.potionRng=run.shopRng and R.cloneState(run.shopRng.potion) or R.fromSeed(run.runSeed)
                state.potionCharacter=require('abyss_potion_random').character(run)
                state.potionInventory=C.copy(run.potions);state.potionCapacity=Run.potionCapacity(run)
                return true
            end})
        assert(reference.potionInventory~=run.potions,'standalone reference must own a private potion inventory')
        eq(run.deck,deckOwner);same(run.deck,deckBefore);unchangedDeck()
        assert(reference.masterDeck~=run.deck and run.combat.masterDeck~=run.deck,'master deck snapshots must be private')
        same(reference.masterDeck,deckBefore);same(run.combat.masterDeck,deckBefore)
        local permanent={};for _,card in ipairs(deckBefore)do assert(not permanent[card.uid]);permanent[card.uid]=card end
        for _,battle in ipairs({run.combat,reference})do
            local held,owned=0,{}
            for _,pile in ipairs({battle.hand,battle.draw,battle.discard,battle.exhaust})do for _,card in ipairs(pile)do
                local owner=assert(permanent[card.deckUid],'missing permanent UID owner')
                assert(not owned[card.deckUid],'duplicated permanent card owner');owned[card.deckUid]=true
                eq(card.cardId,owner.cardId);eq(card.upgraded,owner.upgraded);held=held+1
            end end
            eq(held,#deckBefore)
        end
        same(Data.rules.player.startingRelics,{'burning_blood'})
        reference.relics={'burning_blood'};reference.relicCounters={};reference.relicCombat={attackPlayed=false}
        -- Pin the new first-turn hook owners independently of the actual Run.
        reference.rareRelicCombat={firstPocketTurn=true,gamblingActivated=false,topCanDraw=true,topDisabled=false}
        reference.shopRelicCombat={pellets={}}
        local generation=run.combatGeneration
        assert(type(generation)=='number'and generation%1==0 and generation>=1 and generation<=2147483647,'invalid Run combat generation')
        eq(run.combat.combatGeneration,generation,'Run/battle generation ownership')
        eq(reference.combatGeneration,nil,'standalone Core generation')
        local expectedBattle=C.copy(reference);expectedBattle.combatGeneration=generation
        same(run.combat,expectedBattle)
    end end
    eq(seen,16)
end)
assert(registered==18,'all original cases must remain registered')
assert(count==last-first+1,'each selected case must execute')
assert(failed==0,tostring(failed)..' failed of '..count)
print('SMALL_SLIMES_PASS '..count)
