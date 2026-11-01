package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Stances=require("abyss_stances")
local Combat=require("abyss_combat")
local Data=require("abyss_data")
local count=0
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(label,fn) fn(); count=count+1; print("ok watcher_stances "..count.." - "..label) end
local function battle()
    return Combat.new(Data,{seed=42,enemies={"cultist"},deck={"strike","defend"}})
end
test("normal outgoing and incoming Wrath are distinct from fixed damage",function()
    local s=battle(); local e=s.enemies[1]
    Stances.change(s,"Wrath")
    equal(Stances.damageMultiplier(s,s.player,e,false),2)
    equal(Stances.damageMultiplier(s,e,s.player,false),2)
    equal(Stances.damageMultiplier(s,s.player,s.player,false),4)
    equal(Stances.damageMultiplier(s,s.player,e,true),1)
    equal(Stances.damageMultiplier(s,e,s.player,true),1)
end)
test("Divinity triples outgoing NORMAL without increasing incoming",function()
    local s=battle(); local e=s.enemies[1]
    Stances.change(s,"Divinity")
    equal(Stances.damageMultiplier(s,s.player,e),3)
    equal(Stances.damageMultiplier(s,e,s.player),1)
end)
test("Calm queues gain on exit, same stance does not duplicate",function()
    local s=battle(); local before=s.energy
    Stances.change(s,"Calm"); equal(Stances.flush(s),0)
    equal(Stances.change(s,"Calm"),false)
    Stances.change(s,"Wrath"); equal(s.energy,before)
    equal(Stances.flush(s),2); equal(s.energy,before+2)
    equal(Stances.flush(s),0)
end)
test("Calm to Divinity preserves separate ordered gains and event frames",function()
    local s=battle(); local before=s.energy
    Stances.change(s,"Calm")
    Stances.change(s,"Divinity",{violetLotus=true})
    equal(s.stanceQueue[1].reason,"violet_lotus")
    equal(s.stanceQueue[2].reason,"calm_exit")
    equal(s.stanceQueue[3].reason,"divinity_enter")
    local start=#s.events
    equal(Stances.flush(s),6); equal(s.energy,before+6)
    equal(s.events[start+1].frame.energy,before+1)
    equal(s.events[start+2].frame.energy,before+3)
    equal(s.events[start+3].frame.energy,before+6)
end)
test("Calm to Divinity without relic gains five",function()
    local s=battle(); Stances.change(s,"Calm"); Stances.change(s,"Divinity")
    equal(Stances.flush(s),5)
end)
test("CannotChange rejects all transition side effects",function()
    local s=battle(); Stances.change(s,"Calm"); local n=#s.events
    equal(Stances.change(s,"Divinity",{cannotChange=true,violetLotus=true}),false)
    equal(s.player.stance,"Calm"); equal(#s.events,n); equal(Stances.flush(s),0)
end)
test("Divinity persists until explicit next own turn hook",function()
    local s=battle(); Stances.change(s,"Divinity"); Stances.flush(s)
    local energy=s.energy
    equal(Stances.change(s,"Divinity"),false); equal(Stances.flush(s),0)
    equal(s.player.stance,"Divinity")
    equal(Stances.startTurn(s),true); equal(s.player.stance,"Neutral")
    equal(s.energy,energy); equal(Stances.startTurn(s),false)
end)
test("start turn respects CannotChange",function()
    local s=battle(); Stances.change(s,"Divinity"); Stances.flush(s)
    equal(Stances.startTurn(s,{cannotChange=true}),false); equal(s.player.stance,"Divinity")
end)
test("queued energy feeds real Combat.play cost gate",function()
    local s=battle(); s.energy=0
    Stances.change(s,"Calm"); Stances.change(s,"Neutral"); Stances.flush(s)
    equal(s.energy,2)
    local uid
    for _,c in ipairs(s.hand) do if c.cardId=="strike" then uid=c.uid end end
    assert(uid,"real strike missing from hand")
    assert(Combat.play(s,uid,1)); equal(s.energy,1)
end)
test("real fixed damage entry ignores stance and ordinary Strength",function()
    local s=battle(); local e=s.enemies[1]; e.hp=100; e.block=0
    Stances.change(s,"Divinity"); s.player.statuses.strength=50
    equal(Combat.damage(s,s.player,e,7,true),7)
    equal(e.hp,93)
end)
test("reset clears stance and unfinished energy without rewarding exit",function()
    local s=battle(); local before=s.energy
    Stances.change(s,"Calm"); Stances.change(s,"Divinity")
    Stances.reset(s); equal(s.player.stance,"Neutral"); equal(s.stanceQueue,nil)
    equal(s.energy,before)
end)
test("dead or terminal combat cancels queued energy",function()
    for _,phase in ipairs({"victory","defeat"}) do
        local s=battle(); Stances.change(s,"Divinity"); local before=s.energy
        s.phase=phase; equal(Stances.flush(s),0); equal(s.energy,before)
        equal(Stances.change(s,"Calm"),false)
    end
    local s=battle(); Stances.change(s,"Divinity"); local before=s.energy
    s.player.hp=0; equal(Stances.flush(s),0); equal(s.energy,before)
end)
test("invalid destinations and options reject before mutation",function()
    local s=battle(); local before=s.energy; local n=#s.events
    for _,id in ipairs({"wrath","Unknown",true,2}) do assert(not pcall(Stances.change,s,id)) end
    assert(not pcall(Stances.change,s,"Calm",{violetLotus=1}))
    assert(not pcall(Stances.change,s,"Calm",{callback=function() end}))
    equal(s.energy,before); equal(#s.events,n); equal(s.player.stance,nil)
end)
test("overflow validates total before stance or partial energy mutation",function()
    local s=battle(); s.energy=2147483647
    assert(not pcall(Stances.change,s,"Divinity")); equal(s.player.stance,nil)
    s.energy=0; Stances.change(s,"Calm"); Stances.change(s,"Divinity")
    s.energy=2147483644
    assert(not pcall(Stances.flush,s)); equal(s.energy,2147483644)
    equal(#s.stanceQueue,2)
end)
test("corrupted queue and damage type fail closed",function()
    local s=battle(); s.stanceQueue={{reason="divinity_enter",amount=4}}
    assert(not pcall(Stances.flush,s))
    assert(not pcall(Stances.damageMultiplier,s,s.player,s.enemies[1],"fixed"))
end)
print("WATCHER_STANCES_PASS "..count)
