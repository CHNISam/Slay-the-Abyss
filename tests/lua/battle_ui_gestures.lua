local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local F,Run,setup = H.F,H.Run,H.setup
local first,last=...
first,last=first or 1,last or 6
assert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=11 and first<=last,'invalid gesture partition')
local registered,executed=0,0
local passed, failed = 0, 0
local function test(name, fn)
    registered=registered+1
    if registered<first or registered>last then return end
    executed=executed+1;print('BATTLE_GESTURE_CASE '..registered)
    local ok, why = pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(why)) end
end

test("control: resize cancelled touch remains inert with no interleaving input",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    event("card1","down",7); host:resize(1600,900)
    event("card1","up",7); event("card1","click",7)
    assert(ui.selected==nil and battle.energy==3 and #battle.hand==2)
    tap("card1",8); tap("playArea",8)
    assert(battle.energy==2 and battle.player.block==5)
end)

test("resize: unrelated target Down cannot revive cancelled card click",function()
    local host,ui,panel,event=setup()
    event("card1","down",7); host:resize(1600,900)
    event("enemy1","down",8)
    event("card1","up",7); event("card1","click",7)
    assert(ui.selected==nil,"cancelled touch 7 selected UID "..tostring(ui.selected))
end)

test("resize: cancelled old click cannot confirm a fresh touch selection",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    event("card1","down",7); host:resize(1600,900)
    tap("card1",8)
    assert(ui.selected==battle.hand[1].uid and battle.energy==3)
    event("card1","up",7); event("card1","click",7)
    assert(battle.energy==3 and #battle.hand==2 and battle.player.block==0,
        "cancelled touch spent energy: "..battle.energy..", hand: "..#battle.hand..", block: "..battle.player.block)
end)

test("resize and real turn: old touch cannot confirm different hand-slot UID",function()
    local host,ui,panel,event,tap,drain=setup({"defend","defend","defend","defend","defend","defend","defend","defend"})
    local battle=host.run.combat
    local oldUid=battle.hand[1].uid
    event("card1","down",7); host:resize(1600,900)
    tap("endTurn",8); drain()
    assert(battle.turn==2 and battle.hand[1].uid~=oldUid,"turn fixture must replace the original slot UID")
    local newUid=battle.hand[1].uid
    tap("card1",8)
    assert(ui.selected==newUid and battle.energy==3)
    event("card1","up",7); event("card1","click",7)
    assert(battle.energy==3 and battle.player.block==0,
        "old UID "..oldUid.." touch executed replacement UID "..newUid.."; energy="..battle.energy)
end)

test("deck: closing overlay cannot revive old held card click",function()
    local host,ui,panel,event,tap,drain,openCloseDeck=setup()
    event("card1","down",7); openCloseDeck()
    event("card1","up",7); event("card1","click",7)
    assert(ui.selected==nil,"overlay-cancelled touch selected UID "..tostring(ui.selected))
end)

test("deck: cancelled old click cannot confirm fresh touch selection",function()
    local host,ui,panel,event,tap,drain,openCloseDeck=setup()
    local battle=host.run.combat
    event("card1","down",7); openCloseDeck(); tap("card1",8)
    assert(ui.selected==battle.hand[1].uid and battle.energy==3)
    event("card1","up",7); event("card1","click",7)
    assert(battle.energy==3 and #battle.hand==2 and battle.player.block==0,
        "overlay-cancelled touch spent energy: "..battle.energy..", block="..battle.player.block)
end)

test("target death: held attack never redirects to surviving enemy",function()
    local host,ui,panel,event,tap=setup({"strike"},{"cultist","jaw_worm"})
    local battle=host.run.combat
    -- Independent physical targets require an explicit source formation when
    -- constructing raw actor IDs outside MonsterHelper.
    battle.enemies[1].sourcePosition={x=-600,y=0}
    battle.enemies[2].sourcePosition={x=-100,y=0};ui:render()
    local target=monsterControl(panel,"enemy1")
    local oldX,oldY=target.x,target.y
    local hp=battle.enemies[2].hp
    event("card1","down",7); event("card1","drag",7,target.x,target.y)
    F.Combat.damage(battle,battle.player,battle.enemies[1],battle.enemies[1].hp,false)
    ui:render()
    event("dragLayer","up",7,oldX,oldY); event("card1","endDrag",7,oldX,oldY)
    assert(battle.energy==3 and #battle.hand==1 and battle.enemies[2].hp==hp)
    dofile('tests/lua/support/monster_death_fixture.lua')(host,ui,battle.enemies[1].id)
    local survivor=monsterControl(panel,"enemy1")
    assert(survivor.visible and survivor:GetChild("name").text==battle.enemies[2].name)
    event("card1","down",8); event("card1","drag",8,survivor.x,survivor.y)
    event("dragLayer","up",8,survivor.x,survivor.y)
    assert(battle.energy==2 and #battle.hand==0 and battle.enemies[2].hp==hp-6)
end)

test("moving resize cancellation remains inert for Up and EndDrag after other pointer Down",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    event("card1","down",7); event("card1","drag",7,0,0)
    assert(panel:GetChild("dragLayer").visible)
    host:resize(1920,1080)
    event("enemy1","down",8)
    event("card1","up",7,0,0); event("card1","endDrag",7,0,0)
    assert(battle.energy==3 and #battle.hand==2 and ui.gesture==nil)
    assert(not panel:GetChild("dragLayer").visible)
    tap("card1",8); tap("playArea",8)
    assert(battle.energy==2 and battle.player.block==5)
end)

test("moving deck interruption leaves both release and late Click inert",function()
    local host,ui,panel,event,tap,drain,openCloseDeck=setup()
    local battle=host.run.combat
    event("card1","down",7); event("card1","drag",7,0,0); openCloseDeck()
    event("card1","up",7,0,0); event("card1","endDrag",7,0,0)
    assert(battle.energy==3 and #battle.hand==2 and ui.gesture==nil)
    assert(not panel:GetChild("dragLayer").visible)
    event("card1","click",7)
    assert(ui.selected==nil,"late Click revived the cancelled moving drag")
end)

test("repeated resize permits same-touch-ID fresh taps after old release is consumed",function()
    local host,ui,panel,event,tap=setup()
    local battle=host.run.combat
    event("card1","down",7); host:resize(1600,900); host:resize(1560,720)
    event("card1","up",7); event("card1","click",7)
    assert(ui.selected==nil and battle.energy==3)
    tap("card1",7); tap("playArea",8)
    assert(battle.energy==2 and #battle.hand==1 and battle.player.block==5)
end)

test("host restart: old run held pointer cannot confirm a new run card",function()
    local host,ui,panel,event,tap,drain,openCloseDeck,root=setup({"defend","defend"},{"jaw_worm"})
    -- Additional explicit fixture: one-HP old combat so one real enemy turn reaches defeat.
    host.run.combat=F.Combat.new(F.Data,{hp=1,deck={"defend","defend"},enemies={"jaw_worm"}})
    host:refresh()
    local oldRun,oldBattle=host.run,host.run.combat
    local oldUid=oldBattle.hand[1].uid
    event("card1","down",7); host:resize(1600,900)
    tap("endTurn",8); drain()
    assert(host.mode=="defeat" and oldRun.phase=="defeat")
    local restart = root:GetChild("menuPanel"):GetChild("start"):GetChild("hit")
    restart.listeners.down({touchId=8}); restart.listeners.up({touchId=8})
    assert(restart.click({touchId=8}))
    assert(host.characterOpen and host.run==oldRun)
    assert(F.confirmStart(host))
    assert(host.run~=oldRun and host.mode=="node" and host.run.neowHistorySource=="session-completed-run")
    -- A real defeat supplies mini-Neow history to this host's next run.
    -- Take the HP blessing through generated buttons, preserving the starter deck.
    assert(F.click(root,"nodePanel","eventView/option1"))
    assert(#host.run.nodeFlow.event.rewards==2 and host.run.nodeFlow.event.neowBossCount==0)
    assert(F.click(root,"nodePanel","eventView/option2"))
    assert(F.click(root,"nodePanel","eventView/option1"))
    assert(host.mode=="map" and host.run.neowStatus=="complete")
    -- Real host restart and real map navigation; new battle retains its unmodified starter deck.
    assert(host.mapUI:choose(F.Nodes.available(host.run,host.map)[1].id))
    local battle=host.run.combat
    local slot
    for i,c in ipairs(battle.hand) do if c.cardId=="defend" then slot=i; break end end
    assert(slot,"new starter hand must contain a Defend")
    -- Old pointer belonged to card1. Only a same-slot Defend is relevant for this fixture.
    assert(slot==1,"fixed seed must expose new Defend at original held slot; got "..tostring(slot))
    local newUid=battle.hand[slot].uid
    tap("card1",8)
    assert(ui.selected==newUid and battle.energy==3)
    event("card1","up",7); event("card1","click",7)
    assert(battle.energy==3 and battle.player.block==0,
        "old run UID "..oldUid.." touch confirmed new run UID "..newUid.."; energy="..battle.energy)
end)

-- These cases catch missing click consumption and missing pointer identity checks,
-- rather than relying on a global lock that any other control can clear.
print("LUA_BATTLE_GESTURES "..passed.." passed; "..failed.." failed")
assert(registered==11 and executed==last-first+1,'gesture partition coverage changed')
if failed>0 then error("Interrupted gesture ownership failures: "..failed) end
