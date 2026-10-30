-- Real generated controls + Run/Combat. Reject stale source, not valid same-touch reuse.
local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local Surfaces=require('abyss_monster_surfaces')
local function actorBox(panel,battle,index)
    local box,slot,entry=Surfaces.get(panel):find(assert(battle.enemies[index]).id)
    assert(box,'actor surface missing')
    return box,slot,entry
end
local function sourceSetup(...)
    local host,ui,panel,event,tap,drain,openClose,root=H.setup(...)
    -- Deliberately synthetic encounter constructor offsets, not MonsterHelper
    -- formation or count-dependent production spacing. Distinguish two targets.
    local actors=host.run.combat.enemies
    if #actors==2 then
        actors[1].sourcePosition={x=-240,y=0}
        actors[2].sourcePosition={x=80,y=0}
        host:refresh()
    end
    return host,ui,panel,event,tap,drain,openClose,root
end
local passed, failed = 0, 0
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(why)) end
end
local function setup(deck)
    local host,ui,panel,event,tap,drain,openClose = sourceSetup(deck or {"strike","strike"},{"cultist","jaw_worm"})
    require('abyss_actor').applyPower(host.run.combat,host.run.combat.enemies[2],'vulnerable',2,host.run.combat.enemies[2])
    host:refresh()
    return host,ui,panel,event,tap,drain,openClose
end
local function text(panel,slot) return panel:GetChild("card"..slot):GetChild("label").text end
local function reticle(panel) return panel:GetChild("dragLayer"):GetChild("reticle") end
local function freeze(value)
    local saved,queue={}, {value}
    while #queue>0 do
        local current=table.remove(queue)
        if not saved[current] then
            local entries={};saved[current]=entries
            for key,item in pairs(current) do
                entries[key]=item
                if type(item)=="table" then queue[#queue+1]=item end
            end
        end
    end
    return function()
        for current,entries in pairs(saved) do
            for key,item in pairs(entries) do assert(current[key]==item,"stale Drag mutated core graph") end
            for key,item in pairs(current) do assert(entries[key]==item,"stale Drag added core state") end
        end
    end
end
local function aimedSecond()
    local host,ui,panel,event,tap,drain,openClose=setup()
    event("card1","down",7); openClose()
    local enemy=actorBox(panel,host.run.combat,1)
    event("card2","down",7); event("card2","drag",7,enemy.x,enemy.y)
    assert(ui.gesture and ui.gesture.slot==2 and reticle(panel).x==enemy.x)
    assert(not text(panel,2):find("↑",1,true))
    return host,ui,panel,event,tap,drain
end
test("cancelled card1 Drag cannot change card2 preview or reticle with reused touch",function()
    local host,ui,panel,event=aimedSecond()
    local before1,before2=text(panel,1),text(panel,2)
    local x,y=ui.gesture.x,ui.gesture.y
    local rx,ry=reticle(panel).x,reticle(panel).y
    local target=ui.gesture.drawnTarget
    local first=actorBox(panel,host.run.combat,1)
    assert(target==1 and rx==first.x and ry==first.y,"current reticle must belong to the real selected enemy")
    local unchanged=freeze(host.run.combat)
    local enemy=actorBox(panel,host.run.combat,2)
    event("card1","drag",7,enemy.x,enemy.y)
    assert(text(panel,2)==before2,"stale Drag polluted preview: "..before2.." -> "..text(panel,2))
    assert(text(panel,1)==before1 and ui.gesture.x==x and ui.gesture.y==y)
    assert(ui.gesture.drawnTarget==target and reticle(panel).x==rx and reticle(panel).y==ry,"stale Drag moved reticle")
    unchanged()
    assert(host.run.combat.energy==3 and #host.run.combat.hand==2)
end)
test("foreign card Drag cannot start a stationary current gesture",function()
    local host,ui,panel,event=setup()
    event("card2","down",7)
    local enemy=actorBox(panel,host.run.combat,2)
    event("card1","drag",7,enemy.x,enemy.y)
    assert(not ui.gesture.moving and ui.selected==nil,"foreign source armed a stationary card")
    assert(not panel:GetChild("dragLayer").visible and host.run.combat.energy==3)
end)
test("release recomputes legitimate target and consumes only once",function()
    local host,ui,panel,event=aimedSecond()
    local b=host.run.combat
    local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
    local first,second=actorBox(panel,host.run.combat,1),actorBox(panel,host.run.combat,2)
    event("card1","drag",7,second.x,second.y)
    event("card1","up",7,second.x,second.y)
    assert(ui.gesture and b.energy==3,"foreign Up consumed current drag")
    event("card2","up",7,first.x,first.y)
    event("card2","endDrag",7,first.x,first.y); event("card2","click",7)
    assert(b.enemies[1].hp==hp1-6 and b.enemies[2].hp==hp2 and b.energy==2 and #b.hand==1)
end)
test("coordinate-less release still cancels after stale source traffic",function()
    local host,ui,panel,event=aimedSecond()
    local b=host.run.combat
    local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
    local enemy=actorBox(panel,host.run.combat,2)
    event("card1","drag",7,enemy.x,enemy.y)
    panel:GetChild("card2"):GetChild("hit").listeners.up({touchId=7})
    assert(ui.gesture==nil and b.energy==3 and #b.hand==2)
    assert(b.enemies[1].hp==hp1 and b.enemies[2].hp==hp2 and not reticle(panel).parent.visible)
end)
test("own card and drag layer keep normal target-sensitive preview isolated by UID",function()
    local host,ui,panel,event=setup({"strike","bash","defend"})
    local b=host.run.combat
    -- Choose a concrete UID, not the shuffled input deck position.
    local slot
    for i,c in ipairs(b.hand) do if c.cardId=="strike" then slot=i end end
    local unchanged={}
    for i=1,#b.hand do unchanged[i]=text(panel,i) end
    event("card"..slot,"down",7)
    local enemy=actorBox(panel,host.run.combat,2)
    event("card"..slot,"drag",7,enemy.x,enemy.y)
    assert(text(panel,slot):find("9↑",1,true),"own card preview did not apply Vulnerable")
    for i=1,#b.hand do if i~=slot then assert(text(panel,i)==unchanged[i],"target leaked into other card") end end
    local first=actorBox(panel,host.run.combat,1)
    event("dragLayer","drag",7,first.x,first.y)
    assert(text(panel,slot)==unchanged[slot] and ui.gesture.uid==b.hand[slot].uid
        and ui.gesture.drawnTarget==1,"overlay drag must immediately restore the same UID's target preview")
    -- Numerical previews switch immediately; the source reticle eases from
    -- its previous target over aimRetarget (also covered by drag_response).
    assert(reticle(panel).x==enemy.x,"retarget must start at its previously drawn endpoint")
    host:update(H.F.Theme.layout.cardDrag.aimRetarget or 0.12)
    assert(text(panel,slot)==unchanged[slot] and reticle(panel).x==first.x)
    local hp=b.enemies[2].hp
    -- Up changes target without a preceding final Drag.
    event("dragLayer","up",7,enemy.x,enemy.y)
    assert(b.enemies[2].hp==hp-9 and b.energy==2 and #b.hand==2)
end)
test("hand reorder rejects stale UID before moving or rendering another card",function()
    local host,ui,panel,event,tap=setup({"strike","bash"})
    local b=host.run.combat
    event("card1","down",7)
    local old=ui.gesture; local x,y=old.x,old.y
    b.hand[1],b.hand[2]=b.hand[2],b.hand[1]
    local enemy=actorBox(panel,host.run.combat,2)
    event("card1","drag",7,enemy.x,enemy.y)
    assert(old.x==x and old.y==y and not old.moving,"stale slot UID mutated before render cancellation")
    event("card1","up",7,enemy.x,enemy.y)
    assert(ui.gesture==nil and b.energy==3)
    host:refresh()
    event("card1","down",7); event("card1","drag",7,enemy.x,enemy.y)
    assert(ui.gesture.uid==b.hand[1].uid and ui.gesture.moving,"fresh sorted card is not usable")
end)
test("old battle and turn are rejected before gesture coordinates mutate",function()
    for _,kind in ipairs({"battle","turn"}) do
        local host,ui,panel,event=setup()
        event("card1","down",7)
        local g=ui.gesture; local x,y=g.x,g.y
        local enemy=actorBox(panel,host.run.combat,2) -- captured original actor surface
        if kind=="turn" then g.battle.turn=g.battle.turn+1
        else host.run.combat=H.F.Combat.new(H.F.Data,{deck={"strike","strike"},enemies={"cultist","jaw_worm"}}) end
        event("card1","drag",7,enemy.x,enemy.y)
        assert(g.x==x and g.y==y and not g.moving,kind.." stale generation mutated")
        event("card1","up",7,enemy.x,enemy.y)
        assert(ui.gesture==nil and host.run.combat.energy==3)
    end
end)
test("wrong touch cannot move current drag and cancellation permits a fresh same-card drag",function()
    local host,ui,panel,event,tap,drain,openClose=setup()
    event("card1","down",7)
    local g=ui.gesture; local x,y=g.x,g.y; local enemy=actorBox(panel,host.run.combat,2)
    event("card1","drag",8,enemy.x,enemy.y)
    assert(g.x==x and g.y==y and not g.moving)
    openClose(); event("card1","down",7); event("card1","drag",7,enemy.x,enemy.y)
    assert(ui.gesture~=g and ui.gesture.moving and text(panel,1):find("9↑",1,true))
end)
test("current gesture requires its exact still-held token, not an equal-field copy",function()
    -- Fault injection isolates the internal generation invariant, not host packet identity.
    for _,kind in ipairs({"lost","replaced"}) do
        local host,ui,panel,event=setup()
        event("card1","down",7)
        local g=ui.gesture; local x,y=g.x,g.y
        local replacement
        if kind=="replaced" then replacement={}; for key,value in pairs(g) do replacement[key]=value end end
        g.input.held=replacement
        local enemy=actorBox(panel,host.run.combat,2)
        event("card1","drag",7,enemy.x,enemy.y)
        assert(g.x==x and g.y==y and not g.moving,kind.." token was trusted")
    end
end)
test("pure Click host remains compatible",function()
    local host,ui,panel,event=setup({"defend"})
    event("card1","click",nil); event("playArea","click",nil)
    assert(host.run.combat.energy==2 and host.run.combat.player.block==5 and #host.run.combat.hand==0)
end)
print("LUA_BATTLE_DRAG_SOURCE "..passed.." passed; "..failed.." failed")
if failed>0 then error("Card drag source failures: "..failed) end
