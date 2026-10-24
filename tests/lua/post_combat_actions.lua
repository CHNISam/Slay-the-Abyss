package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Effects = require("abyss_effects")
local data = require("abyss_data")
local count, failed = 0, 0
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn)
    count=count+1
    local ok,why=pcall(fn)
    if not ok then failed=failed+1 end
    print((ok and "ok" or "not ok").." post_combat_actions "..count.." - "..name..(ok and "" or ": "..tostring(why)))
end
local function same(a,b)
    equal(type(a),type(b))
    if type(a)~="table" then equal(a,b); return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,"unexpected key "..tostring(k)) end
end
local function prepare(s,id,pile)
    local card
    for i=#s.hand,1,-1 do
        if not card and s.hand[i].cardId==id then card=s.hand[i]
        else s[pile or "draw"][#s[pile or "draw"]+1]=table.remove(s.hand,i) end
    end
    assert(card,"missing selected card")
    return card
end
local function battle(id,upgraded,companion,pile)
    local s=Combat.new(data,{seed=42,deck={{cardId=id,upgraded=upgraded},"strike","defend","defend"},
        enemies=companion and {"cultist","cultist"} or {"cultist"}})
    return s,prepare(s,id,pile)
end
local function reshuffles(s,first)
    local n=0
    for i=first or 1,#s.events do if s.events[i].kind=="reshuffle" then n=n+1 end end
    return n
end
for _,id in ipairs({"pommel_strike","dropkick","anger","rampage"}) do
    for _,upgraded in ipairs({false,true}) do
        for _,companion in ipairs({false,true}) do
            test(id..(upgraded and "+" or "")..(companion and " keeps tails with living companion" or " clears tails on final kill"),function()
                local s,c=battle(id,upgraded,companion)
                s.enemies[1].hp=1
                if id=="dropkick" then Combat.addStatus(s.enemies[1],"vulnerable",1) end
                local seed,nextUid,draw=s.seed,s.nextUid,#s.draw
                assert(Combat.play(s,c.uid,1))
                equal(s.phase,companion and "player" or "victory"); equal(s.enemies[1].hp,0)
                equal(s.seed,seed); equal(#s.exhaust,0)
                local n=id=="pommel_strike" and (upgraded and 2 or 1) or id=="dropkick" and 1 or 0
                equal(#s.hand,companion and n or 0); equal(#s.draw,draw-(companion and n or 0))
                equal(s.energy,id=="anger" and 3 or id=="dropkick" and companion and 3 or 2)
                equal(#s.discard,id=="anger" and companion and 2 or 1); equal(s.discard[#s.discard],c)
                equal(s.nextUid,nextUid+(id=="anger" and companion and 1 or 0))
                equal(c.damageBonus,id=="rampage" and companion and (upgraded and 8 or 5) or nil)
                if companion then equal(s.enemies[2].hp,s.enemies[2].maxHp) end
            end)
        end
    end
end
for _,id in ipairs({"pommel_strike","dropkick"}) do
    for _,companion in ipairs({false,true}) do
        test(id.." discard-only draw preserves/calls shuffle at correct death boundary "..tostring(companion),function()
            local s,c=battle(id,false,companion,"discard")
            s.enemies[1].hp=1
            if id=="dropkick" then Combat.addStatus(s.enemies[1],"vulnerable",1) end
            local seed,first,discard=s.seed,#s.events+1,s.discard
            assert(Combat.play(s,c.uid,1))
            equal(reshuffles(s,first),companion and 1 or 0)
            if companion then assert(s.seed~=seed); equal(#s.hand,1); equal(#s.draw,2)
            else equal(s.seed,seed); equal(s.discard,discard); equal(#s.discard,4); equal(#s.hand,0); equal(#s.draw,0) end
        end)
    end
end
for _,companion in ipairs({false,true}) do
    test("thorns player death preserves existing stop with companion "..tostring(companion),function()
        local s,c=battle("dropkick",false,companion,"discard")
        s.enemies[1].hp=1; s.player.hp=3
        Combat.addStatus(s.enemies[1],"vulnerable",1); Combat.addStatus(s.enemies[1],"thorns",3)
        local seed=s.seed
        assert(Combat.play(s,c.uid,1)); equal(s.phase,"defeat"); equal(s.energy,2)
        equal(#s.hand,0); equal(#s.discard,4); equal(s.seed,seed); equal(reshuffles(s),0)
    end)
end
test("damage clear filters actions individually rather than blanket stopping retained block and HP loss",function()
    local s,c=battle("strike",false,false,"discard")
    s.enemies[1].hp=1
    s.catalog.cards.strike.effects={{op="damage",value=6},{op="energy",value=2},{op="block",value=7},
        {op="doubleBlock"},{op="gainStatus",status="strength",value=2},{op="gainTemporaryStrength",value=2},
        {op="noDrawThisTurn"},{op="makeTempCardInDiscard",card="dazed",value=2},{op="loseHp",value=1},{op="draw",value=1}}
    local seed,nextUid=s.seed,s.nextUid
    assert(Combat.play(s,c.uid,1)); equal(s.phase,"victory"); equal(s.player.block,7); equal(s.player.hp,79)
    equal(s.energy,2); equal(s.player.statuses.strength,nil); equal(s.player.temporaryStrength,nil)
    equal(s.player.noDraw,false); equal(s.nextUid,nextUid); equal(#s.discard,4); equal(#s.hand,0); equal(s.seed,seed)
end)
test("surviving companion preserves block doubleBlock power and energy tails",function()
    local s,c=battle("strike",false,true)
    s.enemies[1].hp=1
    s.catalog.cards.strike.effects={{op="damage",value=6},{op="energy",value=2},{op="block",value=7},
        {op="doubleBlock"},{op="gainStatus",status="strength",value=2},{op="draw",value=1}}
    assert(Combat.play(s,c.uid,1)); equal(s.phase,"player"); equal(s.player.block,14)
    equal(s.player.statuses.strength,2); equal(s.energy,4); equal(#s.hand,1)
end)
for _,upgraded in ipairs({false,true}) do
    test("final Rampage kill retains earlier growth without adding another increment "..tostring(upgraded),function()
        local s,c=battle("rampage",upgraded); c.damageBonus=5; s.enemies[1].hp=1
        assert(Combat.play(s,c.uid,1)); equal(s.phase,"victory"); equal(c.damageBonus,5)
        equal(Combat.cardDefinition(s,c).effects[1].value,13); equal(s.discard[1],c)
    end)
end
test("effects committed before final damage are not cancelled retroactively",function()
    local s,c=battle("strike",false,false,"discard"); s.enemies[1].hp=1
    s.catalog.cards.strike.effects={{op="energy",value=2},{op="gainStatus",status="strength",value=2},
        {op="block",value=7},{op="damage",value=6},{op="energy",value=3},{op="draw",value=1}}
    local seed=s.seed
    assert(Combat.play(s,c.uid,1)); equal(s.energy,4); equal(s.player.block,7); equal(s.player.statuses.strength,2)
    equal(#s.hand,0); equal(s.seed,seed)
end)
for _,op in ipairs({"damageAll","damageEqualToBlock"}) do
    test(op.." also clears only after final damage",function()
        local s,c=battle("strike",false,op=="damageAll","discard")
        for _,e in ipairs(s.enemies) do e.hp=1 end
        s.player.block=5
        s.catalog.cards.strike.effects={{op=op,value=6},{op="draw",value=1},{op="block",value=7}}
        local seed=s.seed
        assert(Combat.play(s,c.uid,1)); equal(s.phase,"victory"); equal(#s.hand,0); equal(s.seed,seed); equal(s.player.block,12)
    end)
end
test("nonlethal and blocked hits still resolve every supported tail",function()
    local s,c=battle("dropkick",true,false,"discard"); s.enemies[1].block=20
    Combat.addStatus(s.enemies[1],"vulnerable",1)
    local seed=s.seed
    assert(Combat.play(s,c.uid,1)); equal(s.phase,"player"); equal(s.enemies[1].hp,s.enemies[1].maxHp)
    equal(s.energy,3); equal(#s.hand,1); assert(seed~=s.seed)
end)
test("retained post-lethal block failure restores transaction references and values",function()
    local s,c=battle("strike",false,false,"discard"); s.enemies[1].hp=1
    s.catalog.cards.strike.effects={{op="damage",value=6},{op="draw",value=1},{op="block",value=7}}
    local before=Combat.copy(s); local hand,draw,discard,events,enemy=s.hand,s.draw,s.discard,s.events,s.enemies[1]
    local old=Combat.block
    Combat.block=function(state,actor,value) old(state,actor,value); error("retained block failure") end
    local ok,why=pcall(Combat.play,s,c.uid,1); Combat.block=old
    equal(ok,false); assert(tostring(why):find("retained block failure",1,true)); same(s,before)
    equal(s.hand,hand); equal(s.draw,draw); equal(s.discard,discard); equal(s.events,events); equal(s.enemies[1],enemy); equal(s.hand[1],c)
    assert(Combat.play(s,c.uid,1)); equal(s.phase,"victory"); equal(s.player.block,7); equal(#s.hand,0)
end)
test("unknown operations remain rejected rather than silently swallowed by the clear",function()
    local s,c=battle("strike"); s.enemies[1].hp=1
    local ok,why=pcall(Combat.applyEffects,s,{{op="damage",value=6},{op="not_an_action"}},s.player,s.enemies[1],c)
    equal(ok,false); assert(tostring(why):find("unsupported effect",1,true))
end)
test("heal remains unsupported rather than introducing an unverified new card operation",function()
    equal(Effects.supported({{op="heal",value=4}}),false)
end)
for _,id in ipairs({"pommel_strike","dropkick"}) do
    test("Run "..id.." final kill cannot consume shuffle RNG before rewards",function()
        local run=Run.new(data,42)
        run.deck={{uid=1,cardId=id,upgraded=false},{uid=2,cardId="strike",upgraded=false},
            {uid=3,cardId="defend",upgraded=false},{uid=4,cardId="defend",upgraded=false}}
        run.nextDeckUid=5
        assert(Run.startCombat(run,"cultist_solo")); local s=run.combat
        local c=prepare(s,id,"discard"); s.enemies[1].hp=1
        if id=="dropkick" then Combat.addStatus(s.enemies[1],"vulnerable",1) end
        local seed,deck=s.seed,Combat.copy(run.deck)
        local rewardSeed=seed
        -- Independent expectation: exactly three existing reward selections, no shuffle draws.
        for _=1,3 do rewardSeed=(rewardSeed*25173+13849)%65536 end
        assert(Run.play(run,c.uid,1)); equal(run.phase,"reward"); equal(s.seed,seed); equal(run.seed,rewardSeed)
        equal(#Run.rewardOptions(run),3); equal(run.victories,1); equal(reshuffles(s),0); same(run.deck,deck)
        assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); equal(run.phase,"map"); equal(run.combat,nil); same(run.deck,deck)
    end)
end
assert(failed==0,failed.." / "..count.." post combat action groups failed")
print("post_combat_actions: "..count.." passed")
