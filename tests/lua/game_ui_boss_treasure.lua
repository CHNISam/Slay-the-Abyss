local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Map, Run = require("abyss_map"), require("abyss_run")
local cursor = {CursorEnter="enter", CursorExit="exit", CursorDown="down", CursorUp="up", CursorEndDrag="endDrag"}
local count = 0
local function test(name, fn) fn(); count=count+1; print("ok Boss treasure UI "..count.." - "..name) end
local function get(root, path)
    for part in path:gmatch("[^/]+") do root = assert(root:GetChild(part), path) end
    return root
end
local function fire(hit, kind, id) return assert(hit.listeners[kind], "missing "..kind)({touchId=id}) end
local function tap(hit, id) fire(hit,"down",id); fire(hit,"up",id); return fire(hit,"click",id) end
local function beforeBoss(settle)
    local ui, root = F.fixture(nil, settle, nil, cursor)
    assert(ui:start())
    -- Routing fixture: advance map navigation to the real Boss encounter. This
    -- neither changes enemy definitions nor claims a complete normal playthrough.
    for _ = 1, F.Data.rules.map.bossFloor - 1 do assert(Map.choose(ui.map, Map.available(ui.map)[1].id)) end
    assert(F.Nodes.enter(ui.run, ui.map, Map.available(ui.map)[1].id))
    ui:refresh()
    -- Isolate the victory/reward signal from combat balance and animation.
    for _, enemy in ipairs(ui.run.combat.enemies) do enemy.hp = 0 end
    assert(Run.finishCombat(ui.run))
    ui:refresh()
    return ui, root
end
local function enterTreasure(settle, prepare)
    local ui, root = beforeBoss(settle)
    assert(Run.claimCardReward(ui.run,0)); ui:refresh()
    assert(ui.mode=="map" and ui.run.nodeFlow.result=="boss_victory")
    if prepare then prepare(ui.run) end
    assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
    assert(ui.map.floor==17 and ui.mode=="node" and ui.run.nodeFlow.roomKind=="boss_treasure")
    assert(ui.nodeUI:press("treasureView/chest"))
    return ui, root
end

test("Boss card reward and unopened treasure cannot submit victory",function()
    local calls=0
    local ui,root=beforeBoss(function() calls=calls+1 end)
    assert(ui.mode=="battle" and ui.run.phase=="reward" and not ui:settle())
    assert(Run.claimCardReward(ui.run,0)); ui:refresh()
    assert(ui.mode=="map" and not ui:settle() and calls==0)
    assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
    assert(ui.mode=="node" and not ui:settle())
    assert(not get(root,"nodePanel/treasureView/take").visible)
    assert(get(root,"nodePanel/title").text=="第 17 层 · 首领宝箱")
end)

test("candidate paging shows real descriptions and claims only the selected relic",function()
    local ui,root=enterTreasure()
    local choices=ui.run.nodeFlow.reward.relics
    assert(#choices==3)
    for i=1,#choices do
        local definition
        for _,entry in ipairs(ui.run.data.relics.relics) do if entry.id==choices[i] then definition=entry end end
        assert(get(root,"nodePanel/treasureView/reward/name").text=="遗物 · "..definition.name)
        assert(get(root,"nodePanel/treasureView/bossDescription").text==definition.description)
        if i<#choices then assert(ui.nodeUI:press("treasureView/next")) end
    end
    assert(not ui.nodeUI:press("treasureView/next"))
    assert(ui.nodeUI:press("treasureView/previous"))
    local chosen=choices[2]
    assert(ui.nodeUI:press("treasureView/take"))
    assert(ui.run.phase=="victory" and ui.mode=="victory")
    local owned=0; for _,id in ipairs(ui.run.relics) do if id==chosen then owned=owned+1 end end
    assert(owned==1 and not ui.nodeUI:press("treasureView/take"))
    assert(F.statValue(root,"floor")=="17 / 17")
end)

test("exit cancellation preserves the candidate but expires a held claim gesture",function()
    local ui,root=enterTreasure()
    assert(ui.nodeUI:press("treasureView/next"))
    local hit=get(root,"nodePanel/treasureView/take/hit")
    fire(hit,"down",11); fire(hit,"up",11)
    local old=F.Combat.copy(ui.run)
    assert(ui:openExit())
    assert(not ui.nodeUI:press("back"))
    assert(ui:closeExit())
    assert(ui.nodeUI.treasureChoice==2 and ui.run.phase=="node")
    assert(not fire(hit,"click",11) and ui.run.phase=="node")
    assert(#ui.run.relics==#old.relics and ui.run.seed==old.seed)
    assert(tap(hit,12) and ui.mode=="victory")
    assert(not fire(hit,"click",12))
end)

test("explicit skip reaches victory and restart replaces all previous run state",function()
    local ui,root=enterTreasure()
    local previous,amount=ui.run,#ui.run.relics
    assert(ui.nodeUI:press("back"))
    assert(ui.mode=="victory" and #ui.run.relics==amount)
    assert(ui:start() and ui.run~=previous and ui.mode=="map")
    assert(ui.map.floor==0 and ui.run.nodeFlow==nil and ui.run.combat==nil and ui.run.rewards==nil)
    assert(ui.run.victories==0 and ui.run.elapsedSeconds==0)
    assert(#ui.run.deck==10 and ui.run.gold==F.Data.rules.player.startingGold)
    assert(#ui.run.relics==#F.Data.rules.player.startingRelics and Run.potionCount(ui.run)==0)
    assert(ui.nodeUI.result==nil and ui.nodeUI.treasureChoice==1)
end)

test("exhausted legal relic pool shows no fabricated gold and still allows an explicit skip",function()
    local ui,root=enterTreasure(nil,function(run) run.relics={"black_blood","slavers_collar","sozu"} end)
    assert(#ui.run.nodeFlow.reward.relics==0)
    assert(not get(root,"nodePanel/treasureView/reward").visible)
    assert(not get(root,"nodePanel/treasureView/take").visible)
    assert(get(root,"nodePanel/treasureView/page").text=="没有可领取的首领遗物")
    assert(not ui.nodeUI:press("treasureView/take"))
    local gold=ui.run.gold
    assert(ui.nodeUI:press("back") and ui.mode=="victory" and ui.run.gold==gold)
end)

test("earned Boss victory retries a failed request and submits its result once",function()
    local calls=0
    local ui=enterTreasure(function(victory) assert(victory); calls=calls+1; return calls>1 end)
    assert(ui.nodeUI:press("back"))
    assert(not ui:settle() and calls==1 and not ui.settlementRequested)
    assert(ui:settle() and calls==2 and ui.settlementRequested)
    assert(not ui:settle() and not ui:start() and calls==2)
end)
print("LUA_GAME_UI_BOSS_TREASURE "..count.."/"..count)
