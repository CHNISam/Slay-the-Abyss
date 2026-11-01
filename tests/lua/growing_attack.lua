local sliceFirst,sliceLast,seedFirst,seedLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 3
seedFirst,seedLast=seedFirst or 1,seedLast or 128
local sliceRegistered,sliceExecuted=0,0
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Effects = require("abyss_effects")
local Run = require("abyss_run")
local data = require("abyss_data")
local count, failed = 0, 0
local function equal(a, b) assert(a == b or (type(a) == "number" and type(b) == "number" and a ~= a and b ~= b), tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn)
 sliceRegistered=sliceRegistered+1
 if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end
 sliceExecuted=sliceExecuted+1

    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " growing_attack " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
-- Preserve every value and original reference, including existing card contents.
local function unchangedAfter(root)
    local saved = {}
    local function visit(t)
        if type(t) ~= "table" or saved[t] then return end
        local values = {}; saved[t] = values
        for k, v in pairs(t) do values[k] = v; visit(k); visit(v) end
    end
    visit(root)
    return function()
        for original, values in pairs(saved) do
            for k, v in pairs(values) do equal(original[k], v) end
            for k, v in pairs(original) do equal(v, values[k]) end
        end
    end
end
local function battle(upgraded, companion)
    local s = Combat.new(data, {seed=42, deck={{cardId="rampage", upgraded=upgraded}},
        enemies=companion and {"cultist","cultist"} or nil})
    return s, s.hand[1]
end
local function base(s,c) return Combat.cardDefinition(s,c).effects[1].value end
for _, upgraded in ipairs({false,true}) do
    test((upgraded and "upgraded" or "normal") .. " grows only after attack and retains growth on real redraw", function()
        local s,c = battle(upgraded)
        local catalog = unchangedAfter(s.catalog)
        local increment = upgraded and 8 or 5
        for play = 1,3 do
            local expected = 8 + (play-1)*increment
            equal(base(s,c),expected)
            local hp = s.enemies[1].hp
            assert(Combat.play(s,c.uid,1)); equal(hp-s.enemies[1].hp,expected)
            equal(c.damageBonus,play*increment); equal(base(s,c),8+play*increment)
            equal(s.discard[1],c); equal(s.nextUid,2)
            if play < 3 then assert(Combat.endTurn(s)); equal(s.hand[1],c) end
        end
        catalog()
    end)
    test((upgraded and "upgraded" or "normal") .. " growth precedes strength weak vulnerable and final floor", function()
        local s,c = battle(upgraded)
        assert(Combat.play(s,c.uid,1)); Combat.draw(s,1)
        Combat.addStatus(s.player,"strength",3); Combat.addStatus(s.player,"weak",1)
        Combat.addStatus(s.enemies[1],"vulnerable",1)
        local hp = s.enemies[1].hp
        assert(Combat.play(s,c.uid,1))
        equal(hp-s.enemies[1].hp,upgraded and 21 or 18)
    end)
end
test("same id instances do not share growth or mutate catalog", function()
    local s = Combat.new(data,{deck={"rampage","rampage"}})
    local a,b=s.hand[1],s.hand[2]; local catalog=unchangedAfter(s.catalog)
    assert(Combat.play(s,a.uid,1)); equal(base(s,a),13); equal(base(s,b),8)
    assert(Combat.play(s,b.uid,1)); equal(base(s,b),13); equal(base(s,a),13)
    Combat.draw(s,2); assert(Combat.play(s,a.uid,1)); equal(base(s,a),18); equal(base(s,b),13); catalog()
end)
test("returned definition is detached from instance and catalog", function()
    local s,c=battle(); assert(Combat.play(s,c.uid,1))
    local d=Combat.cardDefinition(s,c); d.effects[1].value=999
    equal(base(s,c),13); equal(s.catalog.cards.rampage.effects[1].value,8)
end)
for _, target in ipairs({false,0,-1,2,1.5,"1",{},math.huge,0/0}) do
    test("invalid target "..tostring(target).." cannot grow",function()
        local s,c=battle(); local check=unchangedAfter(s)
        if target==false then target=nil end
        local ok,reason=Combat.play(s,c.uid,target)
        equal(ok,false); equal(reason,"invalid_target"); check()
    end)
end
for _, mode in ipairs({"energy","phase","uid","dead target"}) do
    test("illegal "..mode.." leaves instance unchanged",function()
        local s,c=battle(); local uid=c.uid
        if mode=="energy" then s.energy=0 elseif mode=="phase" then s.phase="enemy"
        elseif mode=="uid" then uid=999 else s.enemies[1].hp=0 end
        local check=unchangedAfter(s); equal(Combat.play(s,uid,1),false); check()
    end)
end
for _, hp in ipairs({1,40}) do
    test("thorns death stops growth with enemy starting HP "..hp,function()
        local s,c=battle(); s.player.hp=3; s.enemies[1].hp=hp
        Combat.addStatus(s.enemies[1],"thorns",3)
        assert(Combat.play(s,c.uid,1)); equal(s.phase,"defeat"); equal(c.damageBonus,nil); equal(base(s,c),8)
    end)
end
test("fully blocked hit still retaliates then grows if source survives",function()
    local s,c=battle(); s.enemies[1].block=20; Combat.addStatus(s.enemies[1],"thorns",3)
    local hp,ehp=s.player.hp,s.enemies[1].hp
    assert(Combat.play(s,c.uid,1)); equal(s.player.hp,hp-3); equal(s.enemies[1].hp,ehp)
    equal(s.enemies[1].block,12); equal(base(s,c),13)
end)
test("final lethal target clears queued growth before victory",function()
    local s,c=battle(); s.enemies[1].hp=1
    assert(Combat.play(s,c.uid,1)); equal(s.phase,"victory"); equal(base(s,c),8)
    equal(s.events[#s.events].kind,"victory")
end)
for _, prior in ipairs({false,5}) do
    test("failure after growth restores original instance fields refs UID RNG; prior="..tostring(prior),function()
        local s=Combat.new(data,{seed=42,deck={"rampage","strike","defend"}})
        local c
        for i=#s.hand,1,-1 do
            if s.hand[i].cardId=="rampage" then c=s.hand[i] else s.discard[#s.discard+1]=table.remove(s.hand,i) end
        end
        if prior then c.damageBonus=prior end
        table.insert(s.catalog.cards.rampage.effects,{op="draw",value=2})
        table.insert(s.catalog.cards.rampage.effects,{op="gainStatus",status="missing",value=1})
        local check=unchangedAfter(s); assert(Combat.canPlay(s,c.uid,1))
        local ok,reason=pcall(Combat.play,s,c.uid,1)
        equal(ok,false); assert(tostring(reason):find("unknown status",1,true)); check()
        table.remove(s.catalog.cards.rampage.effects); local seed=s.seed
        assert(Combat.play(s,c.uid,1)); equal(c.damageBonus,(prior or 0)+5); assert(seed~=s.seed)
    end)
end
test("direct growth rejects missing played-card context",function()
    local s=battle(); local check=unchangedAfter(s)
    local ok,reason=pcall(Combat.applyEffects,s,{{op="increaseDamageThisCombat",value=5}},s.player)
    equal(ok,false); assert(tostring(reason):find("played card",1,true)); check()
end)
for _, v in ipairs({-1,1.5,math.huge,0/0,"5",false}) do
    test("invalid growth amount "..tostring(v).." rolls back preceding hit",function()
        local s,c=battle(); s.catalog.cards.rampage.effects[2].value=v
        local check=unchangedAfter(s); equal(pcall(Combat.play,s,c.uid,1),false); check()
    end)
end
test("growth and effective damage cross signed 32-bit boundary without wrap",function()
    local s,c=battle(false,true); c.damageBonus=2147483645
    equal(base(s,c),2147483653.0)
    assert(Combat.play(s,c.uid,1)); equal(c.damageBonus,2147483650.0); equal(base(s,c),2147483658.0)
    equal(s.enemies[1].hp,0)
end)
test("nonadvancing growth rejects preceding lethal hit while companion survives",function()
    local s,c=battle(false,true); c.damageBonus=9007199254740992.0
    s.catalog.cards.rampage.effects[2].value=1
    local check=unchangedAfter(s); equal(pcall(Combat.play,s,c.uid,1),false); check()
end)
test("new combat reconstructs fresh instances without imported growth",function()
    local s,c=battle(true); assert(Combat.play(s,c.uid,1))
    local check=unchangedAfter(c); local nextBattle=Combat.new(data,{deck={c}})
    equal(base(nextBattle,nextBattle.hand[1]),8); equal(nextBattle.hand[1].damageBonus,nil)
    equal(nextBattle.hand[1].upgraded,true); assert(nextBattle.hand[1]~=c); check()
end)
local function finishBattle(run)
    for _ = 1, 100 do
        if run.phase ~= "combat" then return end
        for _ = 1, 30 do
            if run.phase ~= "combat" then break end
            local chosen
            for _, c in ipairs(run.combat.hand) do
                if Combat.canPlay(run.combat,c.uid,1) then
                    if not chosen or Combat.cardDefinition(run.combat,c).type == "attack" then chosen = c end
                end
            end
            if not chosen then break end
            assert(Run.play(run,chosen.uid,1))
        end
        if run.phase == "combat" then assert(Run.endTurn(run)) end
    end
    error("battle never finished")
end
test("real reward to next battle to following battle keeps permanent deck and resets growth",function()
    local run,choice
    for seed=1,128 do
        if seed>=seedFirst and seed<=seedLast then
        local candidate=Run.new(data,seed); assert(Run.startCombat(candidate,"cultist_solo")); finishBattle(candidate)
        for i,id in ipairs(Run.rewardOptions(candidate)) do if id=="rampage" then run,choice=candidate,i; break end end
        if run then assert(seed==49,'source reward boundary changed');break end
        end
    end
    if not run and seedLast<49 then print('PR238_SEARCH_PREFIX '..seedFirst..' '..seedLast);return end
    assert(run,"rampage not offered"); local oldSize=#run.deck
    assert(Run.claimCardReward(run,choice)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); equal(#run.deck,oldSize+1)
    local checkDeck,nextUid=unchangedAfter(run.deck),run.nextDeckUid
    assert(Run.startCombat(run,"cultist_solo"))
    local played=false
    for _=1,10 do
        for _,c in ipairs(run.combat.hand) do
            if c.cardId=="rampage" then
                local hp=run.combat.enemies[1].hp
                assert(Run.play(run,c.uid,1)); equal(hp-run.combat.enemies[1].hp,8); equal(base(run.combat,c),13)
                played=true; break
            end
        end
        if played then break end
        assert(Run.endTurn(run))
    end
    assert(played); checkDeck(); equal(run.nextDeckUid,nextUid)
    finishBattle(run); equal(run.phase,"reward"); checkDeck()
    assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); assert(Run.startCombat(run,"cultist_solo"))
    local found=false
    for _,pile in ipairs({run.combat.hand,run.combat.draw}) do
        for _,c in ipairs(pile) do if c.cardId=="rampage" then equal(base(run.combat,c),8); equal(c.damageBonus,nil); found=true end end
    end
    assert(found); checkDeck(); equal(run.nextDeckUid,nextUid)
end)
assert(failed==0,failed.."/"..count.." growing attack tests failed")
print("growing attack tests passed: "..count)

assert(sliceRegistered==36,'all original cases must register')
assert(sliceExecuted==sliceLast-sliceFirst+1,'all selected cases must execute')
print('PR238_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)
