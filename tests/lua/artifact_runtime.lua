package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local function battle(deck) return C.new(Data,{enemies={"sentry","sentry","sentry"},deck=deck,seed=42}) end
local function uid(s,id) for _,card in ipairs(s.hand) do if card.cardId==id then return card.uid end end;error("missing card "..id) end

test("real Thunderclap consumes each Artifact; subsequent Bash applies Vulnerable",function()
    local s=battle({"thunderclap","bash"});assert(C.play(s,uid(s,"thunderclap"),1))
    for _,e in ipairs(s.enemies) do eq(e.statuses.artifact,0);eq(e.statuses.vulnerable or 0,0) end
    assert(C.play(s,uid(s,"bash"),2));eq(s.enemies[2].statuses.vulnerable,2)
end)
test("real Poison Potion is consumed when Artifact blocks its Power, then a second applies",function()
    local run=Run.new(Data,42);run.floor=6;run.potions={"poison_potion","poison_potion"}
    assert(Run.startCombat(run,"elite_sentries"));local e=run.combat.enemies[1]
    assert(Run.usePotion(run,1,1));eq(run.potions[1],nil);eq(run.potions[2],"poison_potion");eq(run.combat.enemies[1].statuses.artifact,0);eq(run.combat.enemies[1].statuses.poison or 0,0)
    assert(Run.usePotion(run,2,1));eq(run.potions[2],nil);eq(run.combat.enemies[1].statuses.poison,6)
end)
test("failed real Bash after Artifact consumption restores every actor reference and event",function()
    local s=battle({"bash"});local e,statuses=s.enemies[1],s.enemies[1].statuses;local hp,n,seed,energy=e.hp,#s.events,s.seed,s.energy
    s.catalog.cards.bash.effects[#s.catalog.cards.bash.effects+1]={op="gainStatus",status="missing",value=1}
    local events,hand,instance=s.events,s.hand,s.hand[1]
    eq(pcall(C.play,s,instance.uid,1),false);eq(s.enemies[1],e);eq(e.statuses,statuses);eq(statuses.artifact,1);eq(e.hp,hp)
    eq(s.events,events);eq(s.hand,hand);eq(s.hand[1],instance);eq(#s.events,n);eq(s.seed,seed);eq(s.energy,energy)
end)
test("real Flex with Artifact permanently keeps positive Strength and spends one stack",function()
    local s=battle({"flex"});C.addStatus(s.player,"artifact",1);assert(C.play(s,s.hand[1].uid,1))
    eq(s.player.statuses.strength,2);eq(s.player.temporaryStrength or 0,0);eq(s.player.statuses.artifact,0)
    assert(C.endTurn(s));eq(s.player.statuses.strength,2)
end)
test("an invalid potion effect refuses before consuming its bottle or any Artifact",function()
    local run=Run.new(Data,42);run.floor=6;run.potions={"poison_potion"};assert(Run.startCombat(run,"elite_sentries"))
    for _,p in ipairs(run.data.potions.potions) do if p.id=="poison_potion" then p.effects={{op="applyStatus",status="missing",value=1}} end end
    local e=run.combat.enemies[1];local n,seed=#run.combat.events,run.combat.seed
    local ok,reason=Run.usePotion(run,1,1);eq(ok,false);eq(reason,"unknown_status:missing")
    eq(run.potions[1],"poison_potion");eq(e.statuses.artifact,1);eq(#run.combat.events,n);eq(run.combat.seed,seed)
end)
test("repeated Potion views are read-only and a blocked Poison stack still consumes its bottle",function()
    local run=Run.new(Data,42);run.floor=6;run.potions={[2]="poison_potion"};assert(Run.startCombat(run,"elite_sentries"))
    local s=run.combat;local e=s.enemies[1];C.addStatus(e,"artifact",1);C.addStatus(e,"poison",4)
    local n,seed,uid=#s.events,s.seed,s.nextUid
    for _=1,5 do local view=Run.potionView(run);assert(view[2].canUse);eq(run.combat,s);eq(s.enemies[1],e)
        eq(e.statuses.artifact,2);eq(e.statuses.poison,4);eq(run.potions[2],"poison_potion");eq(#s.events,n);eq(s.seed,seed);eq(s.nextUid,uid)
    end
    assert(Run.usePotion(run,2,1));e=run.combat.enemies[1];eq(e.statuses.artifact,1);eq(e.statuses.poison,4);eq(run.potions[2],nil)
    local hp=e.hp;assert(Run.endTurn(run));eq(run.combat.enemies[1].hp,hp-4);eq(run.combat.enemies[1].statuses.artifact,1,"Poison tick is not ApplyPower")
end)
test("six non-Poison supported bottles never consume either actor's Artifact",function()
    for _,id in ipairs({"fire_potion","block_potion","energy_potion","strength_potion","dexterity_potion","regen_potion"}) do
        local run=Run.new(Data,42);run.floor=6;run.potions={id};assert(Run.startCombat(run,"elite_sentries"))
        local s=run.combat;C.addStatus(s.player,"artifact",2);C.addStatus(s.enemies[1],"artifact",1)
        local hp,energy=s.enemies[1].hp,s.energy
        if id=="fire_potion"then s.enemies[1].block=7 end
        if id=="strength_potion"then C.addStatus(s.player,"strength",-5)end
        if id=="dexterity_potion"then C.addStatus(s.player,"dexterity",-5)end
        assert(Run.usePotion(run,1,id=="fire_potion" and 1 or nil));s=run.combat
        eq(s.player.statuses.artifact,2,id);eq(s.enemies[1].statuses.artifact,2,id);eq(run.potions[1],nil)
        if id=="fire_potion"then eq(s.enemies[1].hp,hp-13)
        elseif id=="block_potion"then eq(s.player.block,12)
        elseif id=="energy_potion"then eq(s.energy,energy+2)
        elseif id=="strength_potion"then eq(s.player.statuses.strength,-3)
        elseif id=="dexterity_potion"then eq(s.player.statuses.dexterity,-3)
        else eq(s.player.statuses.regen,5)end
    end
end)
test("positive stat potion at cap still succeeds without consuming Artifact",function()
    for _,row in ipairs({{"strength_potion","strength"},{"dexterity_potion","dexterity"}})do
        local run=Run.new(Data,42);run.floor=6;run.potions={row[1]};assert(Run.startCombat(run,"elite_sentries"))
        C.addStatus(run.combat.player,"artifact",1);C.addStatus(run.combat.player,row[2],999)
        assert(Run.usePotion(run,1));eq(run.potions[1],nil);eq(run.combat.player.statuses[row[2]],999);eq(run.combat.player.statuses.artifact,1)
    end
end)
test("dead or invalid potion targets refuse without spending any Artifact or bottle",function()
    for _,row in ipairs({{nil},{0},{99},{1,true}})do
        local run=Run.new(Data,42);run.floor=6;run.potions={"poison_potion"};assert(Run.startCombat(run,"elite_sentries"))
        local s=run.combat;local e=s.enemies[1];if row[2]then e.hp=0 end;local n,seed=#s.events,s.seed
        local ok,reason=Run.usePotion(run,1,row[1]);eq(ok,false);eq(reason,"invalid_target")
        eq(run.combat,s);eq(s.enemies[1],e);eq(e.statuses.artifact,1);eq(run.potions[1],"poison_potion");eq(#s.events,n);eq(s.seed,seed)
    end
end)
test("Poison overflow is irrelevant when Artifact blocks before stackPower",function()
    local run=Run.new(Data,42);run.floor=6;run.potions={"poison_potion"};assert(Run.startCombat(run,"elite_sentries"))
    local s=run.combat;local e=s.enemies[1];C.addStatus(e,"poison",2147483647);local n,seed=#s.events,s.seed
    s.enemies[2].hp,s.enemies[3].hp=0,0 -- isolate view's only legal target
    for _=1,3 do assert(Run.potionView(run)[1].canUse);eq(e.statuses.artifact,1);eq(e.statuses.poison,2147483647);eq(#s.events,n);eq(s.seed,seed) end
    assert(Run.usePotion(run,1,1));eq(run.potions[1],nil);eq(run.combat.enemies[1].statuses.artifact,0);eq(run.combat.enemies[1].statuses.poison,2147483647)
end)
test("the same unsupported Poison overflow without Artifact still refuses atomically",function()
    local run=Run.new(Data,42);run.floor=6;run.potions={"poison_potion"};assert(Run.startCombat(run,"elite_sentries"))
    local s=run.combat;local e=s.enemies[1];e.statuses.artifact=0;C.addStatus(e,"poison",2147483647);local n,seed=#s.events,s.seed
    s.enemies[2].hp,s.enemies[3].hp=0,0 -- view advertises any usable target, not a selected target
    local view=Run.potionView(run);eq(view[1].canUse,false);eq(view[1].reason,"effect_overflow")
    local ok,reason=Run.usePotion(run,1,1);eq(ok,false);eq(reason,"effect_overflow");eq(run.potions[1],"poison_potion")
    eq(run.combat,s);eq(s.enemies[1],e);eq(e.statuses.poison,2147483647);eq(#s.events,n);eq(s.seed,seed)
end)
test("real Flex may gain Strength when Artifact prevents an overflowing LoseStrength stack",function()
    local s=battle({"flex"});s.player.temporaryStrength=2147483647;C.addStatus(s.player,"artifact",1)
    assert(C.play(s,s.hand[1].uid,1));eq(s.player.statuses.strength,2);eq(s.player.statuses.artifact,0);eq(s.player.temporaryStrength,2147483647)
end)
test("real Flex without Artifact preserves the old overflowing-debt refusal transaction",function()
    local s=battle({"flex"});s.player.temporaryStrength=2147483647
    local p,hand,events=s.player,s.hand,s.events;local instance=s.hand[1];local n,seed=#events,s.seed
    eq(pcall(C.play,s,instance.uid,1),false);eq(s.player,p);eq(s.hand,hand);eq(s.events,events);eq(s.hand[1],instance)
    eq(p.statuses.strength,nil);eq(p.temporaryStrength,2147483647);eq(#events,n);eq(s.seed,seed)
end)
assert(failed==0,tostring(failed).." failed of "..count)
