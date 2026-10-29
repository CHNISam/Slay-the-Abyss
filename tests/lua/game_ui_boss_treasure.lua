local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Map, Run = require("abyss_map"), require("abyss_run")
local Source=dofile('tests/helpers/boss_source_fixture.lua')
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
    assert(testStart(ui))
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
local function enterTreasure(settle, prepare, sourceOffer)
    local ui, root = beforeBoss(settle)
    assert(Run.claimCardReward(ui.run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(ui.run); ui:refresh()
    assert(ui.mode=="map" and ui.run.nodeFlow.result=="boss_victory")
    -- Gesture/claim components explicitly stage the complete 22-ID source
    -- queue; this is not natural probability evidence. Real offers are below.
    if not sourceOffer then Source.supportedChoices(ui.run)end
    if prepare then prepare(ui.run) end
    assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
    assert(ui.map.floor==17 and ui.mode=="node" and ui.run.nodeFlow.roomKind=="boss_treasure")
    assert(ui.nodeUI:press("treasureView/chest"))
    ui.nodeUI:update(2) -- wait for the real opening/reveal timeline
    return ui, root
end

test("Boss card reward and unopened treasure cannot submit victory",function()
    local calls=0
    local ui,root=beforeBoss(function() calls=calls+1 end)
    assert(ui.mode=="battle" and ui.run.phase=="reward" and not ui:settle())
    assert(Run.claimCardReward(ui.run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(ui.run); ui:refresh()
    assert(ui.mode=="map" and not ui:settle() and calls==0)
    assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
    assert(ui.mode=="node" and not ui:settle())
    assert(not get(root,"nodePanel/treasureView/take").visible)
    assert(get(root,"nodePanel/title").text=="第 17 层 · 首领宝箱")
end)

test("all Boss relic rows show real descriptions and claim only the clicked relic",function()
    local ui,root=enterTreasure()
    local choices=ui.run.nodeFlow.reward.relics
    assert(#choices==3)
    for i=1,#choices do
        local definition
        for _,entry in ipairs(ui.run.data.relics.relics) do if entry.id==choices[i] then definition=entry end end
        assert(get(root,"nodePanel/treasureView/rewardItem"..i.."/name").text=="领取 · 遗物 · "..definition.name)
        assert(get(root,"nodePanel/treasureView/rewardItem"..i.."/description").text:find(definition.description,1,true))
        assert(get(root,"nodePanel/treasureView/bossDescription").text:find('选择一件遗物',1,true))
        assert(get(root,"nodePanel/treasureView/rewardItem"..i).visible)
    end
    assert(not ui.nodeUI:press("treasureView/next"))
    local chosen=choices[2]
    assert(ui.nodeUI:press("treasureView/rewardItem2"))
    assert(ui.run.phase=="victory" and ui.mode=="victory")
    local owned=0; for _,id in ipairs(ui.run.relics) do if id==chosen then owned=owned+1 end end
    assert(owned==1 and not ui.nodeUI:press("treasureView/take"))
    assert(F.statValue(root,"floor")=="17 / 17")
end)

test("exit cancellation preserves the candidate but expires a held claim gesture",function()
    local ui,root=enterTreasure()
    local hit=get(root,"nodePanel/treasureView/rewardItem2/hit")
    fire(hit,"down",11); fire(hit,"up",11)
    local old=F.Combat.copy(ui.run)
    assert(ui:openExit())
    assert(not ui.nodeUI:press("back"))
    assert(ui:closeExit())
    assert(ui.nodeUI.treasureChoice==1 and ui.run.phase=="node")
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
    assert(testStart(ui) and ui.run~=previous and ui.mode=="node")
    assert(ui.map.floor==0 and ui.run.nodeFlow~=previous.nodeFlow and ui.run.combat==nil and ui.run.rewards==nil)
    assert(ui.run.nodeFlow.roomKind=='neow' and ui.run.nodeFlow.event.stage=='neow_intro' and not ui.run.nodeFlow.complete)
    assert(ui.run.victories==0 and ui.run.elapsedSeconds==0)
    assert(#ui.run.deck==10 and ui.run.gold==F.Data.rules.player.startingGold)
    assert(#ui.run.relics==#F.Data.rules.player.startingRelics and Run.potionCount(ui.run)==0)
    assert(ui.nodeUI.result==nil and ui.nodeUI.treasureChoice==1)
    -- Source history comes from the victory above. The unchanged next seed2
    -- offers three potions in slot2; declining its three independent rewards
    -- is a normal source choice and preserves every old reset/economy check.
    assert(ui.run.neowHistorySource=='session-completed-run' and previous.floor>=16)
    assert(ui.nodeUI:press('eventView/option1'))
    assert(#ui.run.nodeFlow.event.rewards==4 and ui.run.nodeFlow.event.rewards[2].type=='THREE_SMALL_POTIONS')
    assert(ui.nodeUI:press('eventView/option2'))
    assert(ui.run.nodeFlow.event.stage=='neow_potions' and #ui.run.nodeFlow.event.potionOffers==3)
    for _,offer in ipairs(ui.run.nodeFlow.event.potionOffers)do assert(not offer.claimed)end
    assert(ui.nodeUI:press('eventView/option4'))
    assert(ui.nodeUI:press('eventView/option1') and ui.mode=='map' and ui.mapUI.navigationEnabled)
    assert(ui.map.floor==0 and ui.run.nodeFlow.complete and ui.run.neowStatus=='complete' and ui.run.combat==nil and ui.run.rewards==nil)
    assert(ui.run.victories==0 and ui.run.elapsedSeconds==0)
    assert(#ui.run.deck==10 and ui.run.gold==F.Data.rules.player.startingGold)
    assert(#ui.run.relics==#F.Data.rules.player.startingRelics and Run.potionCount(ui.run)==0)
    assert(ui.nodeUI.result==nil and ui.nodeUI.treasureChoice==1)
end)

test("exhausted source pool shows actual Circlet fallback without fabricated gold",function()
    local ui,root=enterTreasure(nil,function(run)
        run.relics={"black_blood","slavers_collar","sozu"};run.relicPool.queues.boss={}
    end,true)
    assert(#ui.run.nodeFlow.reward.relics==3)
    for _,id in ipairs(ui.run.nodeFlow.reward.relics)do assert(id=='circlet')end
    assert(ui.run.nodeFlow.reward.gold==nil)
    assert(get(root,"nodePanel/treasureView/rewardItem1").visible)
    assert(get(root,"nodePanel/treasureView/rewardItem1").visible and not get(root,"nodePanel/treasureView/rewardItem1/disabled").visible)
    assert(get(root,"nodePanel/treasureView/page").text=='宝箱奖励 · 3 项')
    local gold=ui.run.gold
    assert(ui.nodeUI:press("treasureView/rewardItem1") and ui.mode=="victory" and ui.run.gold==gold)
    assert(ui.run.relics[#ui.run.relics]=='circlet' and ui.run.relicCounters.circlet==1)
    assert(not ui.nodeUI:press("treasureView/take"))
end)

test('real seed1 source offer keeps unavailable identities visible and rejects every claim atomically',function()
    local ui,root=enterTreasure(nil,nil,true)
    local expected={'Snecko Eye','Calling Bell','Cursed Key'} -- existing independent host-JDK vector.
    local displayNames={'异蛇之眼','召唤铃铛','诅咒钥匙'}
    for i,id in ipairs(expected)do
        assert(ui.run.nodeFlow.reward.items[i].sourceId==id)
        assert(get(root,'nodePanel/treasureView/rewardItem'..i..'/name').text=='遗物 · '..displayNames[i])
        assert(get(root,'nodePanel/treasureView/rewardItem'..i..'/description').text:find('暂不可领取',1,true))
        assert(get(root,'nodePanel/treasureView/rewardItem'..i..'/disabled').visible)
        local before=F.Combat.copy(ui.run)
        assert(not ui.nodeUI:press('treasureView/rewardItem'..i))
        assert(ui.run.phase=='node' and ui.run.gold==before.gold and #ui.run.relics==#before.relics)
        assert(ui.run.nodeFlow.reward.items[i].sourceId==id)

    end
    assert(ui.nodeUI:press('back') and ui.mode=='victory')
end)

test("earned Boss victory retries a failed request and submits its result once",function()
    local calls=0
    local ui=enterTreasure(function(victory) assert(victory); calls=calls+1; return calls>1 end)
    assert(ui.nodeUI:press("back"))
    assert(not ui:settle() and calls==1 and not ui.settlementRequested)
    assert(ui:settle() and calls==2 and ui.settlementRequested)
    assert(not ui:settle() and not testStart(ui) and calls==2)
end)
print("LUA_GAME_UI_BOSS_TREASURE "..count.."/"..count)
