local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local testStartButton=dofile('tests/lua/support/game_ui_fixture.lua').startButton
local freshFixture=dofile('tests/lua/support/current_entry_fixture.lua')
local F = freshFixture()
local GameUI, Combat, Nodes, Data = F.GameUI, F.Combat, F.Nodes, F.Data
local Presentation, Layout, Viewport, Theme = F.Presentation, F.Layout, F.Viewport, F.Theme
local preview, control, fixture = F.preview, F.control, F.fixture
local statValue, resultText, mapControl, click, win = F.statValue, F.resultText, F.mapControl, F.click, F.win
local count,registered = 0,0
local group=ABYSS_CURRENT_ENTRY_GROUP
local selected
if group then
    assert(type(group)=='table' and #group>0)
    selected={}
    for _,index in ipairs(group)do
        assert(type(index)=='number' and index%1==0 and index>=1 and index<=16 and not selected[index])
        selected[index]=true
    end
end
local function test(name, fn)
    registered=registered+1
    if selected and not selected[registered]then return end
    F=freshFixture()
    GameUI,Combat,Nodes,Data=F.GameUI,F.Combat,F.Nodes,F.Data
    Presentation,Layout,Viewport,Theme=F.Presentation,F.Layout,F.Viewport,F.Theme
    preview,control,fixture=F.preview,F.control,F.fixture
    statValue,resultText,mapControl,click,win=F.statValue,F.resultText,F.mapControl,F.click,F.win
    local ok,why=xpcall(fn,debug.traceback)
    local cleaned,cleanupWhy=pcall(F.close)
    assert(ok,why);assert(cleaned,cleanupWhy)
    count=count+1;print("ok game UI "..count.." - "..name)
    if group then print("CURRENT_GAME_UI_CASE\t"..registered.."\t"..name)end
end
local function leavePotionRewards(ui, root)
    if ui.run.phase=='reward' and ui.run.rewards.manualContinue then
        if ui.run.rewards.goldClaimed == false then click(root,'battlePanel','goldReward') end
        click(root,'battlePanel','continue')
    end
end
local function completeRestartOpening(ui,root,previous)
    assert(ui.mode=='node' and ui.run.nodeFlow.event.id=='neow' and ui.run.nodeFlow~=previous.nodeFlow)
    assert(ui.run.neowHistorySource=='session-completed-run' and ui.map.floor==0)
    local hp,maxHp,gold,deck,relics,potions=ui.run.hp,ui.run.maxHp,ui.run.gold,#ui.run.deck,#ui.run.relics,#ui.run.potions
    assert(hp==ui.run.data.rules.player.maxHp and maxHp==hp)
    click(root,'nodePanel','eventView/option1')
    local event=ui.run.nodeFlow.event
    if previous.floor<16 then
        assert(#event.rewards==2 and event.rewards[2].type=='TEN_PERCENT_HP_BONUS')
        local bonus=event.hpBonus
        click(root,'nodePanel','eventView/option2')
        assert(ui.run.hp==hp+bonus and ui.run.maxHp==maxHp+bonus)
    else
        -- The unchanged next seed2 offers three potions as its second blessing.
        -- Decline all three through the source reward UI; never erase the node.
        assert(#event.rewards==4 and event.rewards[2].type=='THREE_SMALL_POTIONS')
        click(root,'nodePanel','eventView/option2')
        assert(ui.run.nodeFlow.event.stage=='neow_potions' and #ui.run.nodeFlow.event.potionOffers==3)
        for _,offer in ipairs(ui.run.nodeFlow.event.potionOffers)do assert(not offer.claimed)end
        click(root,'nodePanel','eventView/option4')
        assert(ui.run.hp==hp and ui.run.maxHp==maxHp)
    end
    assert(ui.run.gold==gold and #ui.run.deck==deck and #ui.run.relics==relics and #ui.run.potions==potions)
    click(root,'nodePanel','eventView/option1')
    assert(ui.mode=='map' and ui.run.nodeFlow.complete and ui.run.neowStatus=='complete')
end

test("menu shows only current version and keeps start/exit available without announcements", function()
    local ui, root = fixture()
    local menu = root:GetChild('menuPanel')
    local version = menu:GetChild('codeVersion')
    assert(version.visible and version.text == require('abyss_narrative').codeVersion)
    assert(version.text:match('^v%d+%.%d+%.%d+$') and not version.text:match('来源'))
    assert(not menu:GetChild('releaseNotes') and not root:GetChild('releaseNotesPanel'))
    assert(ui.releaseNotesUI == nil and ui.mode == 'menu')
    assert(ui:openExit() and ui.exitOpen)
    assert(ui:closeExit() and not ui.exitOpen and ui.mode == 'menu')
    assert(testStart(ui) and not version.visible and ui.mode == 'map')
end)

test("new encounter resets stale target before the first attack-card tap", function()
    local Run = require("abyss_run")
    local ui, root = fixture()
    assert(testStart(ui))
    local run = ui.run
    assert(Run.startCombat(run, "louse_pair"))
    ui:refresh()
    click(root, "battlePanel", "enemy2")
    assert(ui.battleUI.target == 2)
    ui:refresh()
    assert(ui.battleUI.target == 2, "same encounter refresh must preserve target")
    -- Isolate the encounter transition, not combat balance or a full map run.
    for _, enemy in ipairs(run.combat.enemies) do enemy.hp = 0 end
    assert(Run.finishCombat(run))
    ui:refresh()
    click(root, "battlePanel", "cardReward");click(root, "battlePanel", "skip")
    leavePotionRewards(ui, root)
    assert(run.phase == "map")
    assert(Run.startCombat(run, "cultist_solo"))
    ui:refresh() -- This is the same host refresh used after Nodes.enter.
    local battle = run.combat
    local slot
    for i, card in ipairs(battle.hand) do
        if Combat.cardDefinition(battle, card).type == "attack" then slot = i break end
    end
    assert(slot, "starter opening hand must include an attack")
    local instance, energy = battle.hand[slot], battle.energy
    assert(Combat.canPlay(battle, instance.uid, 1))
    click(root, "battlePanel", "card" .. slot)
    assert(ui.battleUI.selected == instance.uid, "first attack tap was rejected by stale encounter target")
    assert(ui.battleUI.target == 1 and battle.energy == energy)
    ui:refresh()
    assert(ui.battleUI.selected == instance.uid, "same encounter refresh must preserve card selection")
    local beforeHp = battle.enemies[1].hp
    click(root, "battlePanel", "enemy1")
    assert(battle.energy < energy and battle.enemies[1].hp < beforeHp)
end)

test("menu starts real map, enters actual encounter, consumes reward and unlocks next layer", function()
    local ui, root = fixture()
    assert(ui.mode == "menu" and not root:GetChild("mapPanel").visible)
    local intro = root:GetChild("menuPanel"):GetChild("tagline").text
    local guide = root:GetChild("menuPanel"):GetChild("summary").text
    -- The title screen names the chapter; the approved opening story is told by the cinematic.
    assert(intro == "岩脉残响")
    assert(guide == "" and not root:GetChild("menuPanel"):GetChild("summary").visible)
    assert(not (intro .. guide):find("十五", 1, true) and not (intro .. guide):find("十七", 1, true))
    preview("menu", guide)
    testStartButton(root)
    assert(ui.mode == "map" and ui.map.floor == 0 and #Nodes.available(ui.run, ui.map) == 2)
    local original = ui.run
    assert(testStart(ui) == false and ui.run == original)
    click(root, "mapPanel", "node1")
    assert(ui.mode == "battle" and ui.map.floor == 1 and not ui.mapUI.navigationEnabled)
    assert(not root:GetChild("mapPanel").visible and not root:GetChild("nodePanel").visible)
    local floor = ui.map.floor
    mapControl(root:GetChild("mapPanel"), "node4"):GetChild("hit").click()
    assert(ui.map.floor == floor)
    win(ui, root)
    assert(ui.mode == "battle" and ui.run.nodeFlow.complete == false)
    local chosen = ui.run.rewards.cards[1]
    click(root, "battlePanel", "cardReward")
    click(root, "battlePanel", "card1")
    leavePotionRewards(ui, root)
    assert(ui.mode == "map" and ui.run.nodeFlow.complete and #ui.run.deck == 11)
    assert(ui.run.deck[11].cardId == chosen and ui.mapUI.navigationEnabled)
    local before = #ui.run.deck
    root:GetChild("battlePanel"):GetChild("card1"):GetChild("hit").click()
    assert(#ui.run.deck == before)
    local nextNode = Nodes.available(ui.run, ui.map)[1]
    assert(ui.mapUI:choose(nextNode.id))
    assert(ui.map.floor == 2 and ui.run.floor == 2)
end)

test("defeat returns to menu and restart replaces the complete same-run state", function()
    local ui, root = fixture()
    testStartButton(root) click(root, "mapPanel", "node1")
    local previous = ui.run
    previous.combat.player.hp = 1
    -- A legal weak encounter can open with a buff/debuff instead of damage.
    -- Exercise the real turn/UI path until its attack defeats this 1-HP player.
    for _ = 1, 8 do
        if previous.phase ~= "combat" then break end
        click(root, "battlePanel", "endTurn")
    end
    assert(ui.mode == "defeat" and root:GetChild("menuPanel").visible)
    local ending = resultText(root, "subtitle")
    assert(ending == "封印仍在崩解，遗迹深处的回廊再一次归于黑暗。")
    preview("defeat", ending)
    testStartButton(root)
    assert(ui.mode == "node" and ui.run ~= previous and ui.map.floor == 0)
    assert(ui.run.gold == Data.rules.player.startingGold and #ui.run.deck == 10 and #ui.run.potions == 0)
    assert(#ui.run.relics == #Data.rules.player.startingRelics and ui.run.nodeFlow~=previous.nodeFlow)
    completeRestartOpening(ui,root,previous)
    assert(ui.mode == "map" and ui.run ~= previous and ui.map.floor == 0)
    assert(ui.run.gold == Data.rules.player.startingGold and #ui.run.deck == 10 and #ui.run.potions == 0)
    assert(#ui.run.relics == #Data.rules.player.startingRelics and ui.run.nodeFlow.complete)
end)

test("node panels compose through Boss16, independent treasure17 then restart", function()
    -- Keep the real rules, commands and UI. Four HP isolates routing from
    -- balance while keeping source Preserved Insect's floor(HP * .75) above
    -- zero when the route obtains it. One HP is an impossible elite fixture.
    local data = Combat.copy(Data)
    for _, enemy in ipairs(data.enemies.enemies) do enemy.hp, enemy.hpRange = 4, nil end -- explicit low-HP flow fixture
    local ui, root = fixture(data)
    testStartButton(root)
    local route=dofile('tests/lua/support/map_routes.lua').best(ui.map,function(node)return node.type=='event' and 1 or 0 end)
    local seen,seenEvents = {},{}
    for floor = 1, data.rules.map.floors do
        local node
        for _,available in ipairs(Nodes.available(ui.run,ui.map))do if available.id==route[floor]then node=available;break end end
        assert(node and node.floor == floor)
        local slot
        for i, id in pairs(ui.mapUI.slots) do if id == node.id then slot = i break end end
        assert(slot, "next layer missing from focused map page")
        click(root, "mapPanel", "node" .. slot)
        if not ui.run.nodeFlow or ui.run.nodeFlow.id~=node.id then
            local _,why=Nodes.enter(ui.run,ui.map,node.id)
            error('entry failed on floor '..floor..' mode '..ui.mode..' reason '..tostring(why))
        end
        node.type=ui.run.nodeFlow.type -- ? retains its map symbol but routes by actual room.
        if ui.run.nodeFlow.event then seenEvents[ui.run.nodeFlow.event.id]=true end
        print('UNKNOWN_ROOM_ROUTE '..floor..' '..node.id..' '..node.type..' '..(ui.run.nodeFlow.event and ui.run.nodeFlow.event.id or '-'))
        seen[node.type] = true
        if node.type == "boss" then
            local notice = root:GetChild("battlePanel"):GetChild("notice")
            assert(notice.text == "石门缓缓开启。昔日的封印守卫仍在履行职责，只是漆黑的力量已令它分不清敌友。")
            preview("boss", notice.text)
            notice.text = "操作提示优先"
            ui:refresh()
            assert(notice.text == "操作提示优先", "entry copy must not overwrite interaction notices")
        end
        if ui.mode == "battle" then
            win(ui, root)
            click(root, "battlePanel", "cardReward");click(root, "battlePanel", "skip")
            leavePotionRewards(ui, root)
        elseif node.type == "shop" then
            if ui.nodeUI.actions["shopView/card1"].enabled then
                local before = ui.run.gold
                click(root, "nodePanel", "shopView/card1")
                assert(ui.run.gold < before)
            end
            click(root, "nodePanel", "confirm")
            -- The merchant's farewell holds the shop panel until the player continues.
            assert(ui.mode == "node" and ui.run.phase == "map" and not ui.mapUI.navigationEnabled)
            assert(root:GetChild("nodePanel"):GetChild("merchant").visible)
            click(root, "nodePanel", "confirm")
        else
            assert(ui.mode == "node")
            if node.type == "event" then
                local leaveSlot
                for i = 1, 3 do
                    local option = root:GetChild("nodePanel"):GetChild("eventView"):GetChild("option" .. i)
                    if option.visible and option:GetChild("title").text == "［离开］" then leaveSlot = i end
                end
                assert(leaveSlot); click(root, "nodePanel", "eventView/option" .. leaveSlot)
            elseif node.type == "treasure" then
                assert(ui.run.nodeFlow.chest and not ui.run.nodeFlow.chest.opened)
                click(root, "nodePanel", "treasureView/chest")
                assert(ui.run.nodeFlow.chest.opened)
                ui.nodeUI:update(2)
                -- Source chests expose independent items. Keep this same real
                -- route and every combat; never reroll an unavailable identity.
                while ui.run.phase == 'node' and #ui.run.nodeFlow.reward.items > 0 do
                    local choice
                    for index,item in ipairs(ui.run.nodeFlow.reward.items)do
                        if item.kind~='relic' or item.available==true then choice=index;break end
                    end
                    if not choice then
                        for _,item in ipairs(ui.run.nodeFlow.reward.items)do assert(item.kind=='relic' and item.available==false)end
                        local beforeGold,beforeRelics=ui.run.gold,#ui.run.relics
                        click(root,'nodePanel','back')
                        assert(ui.run.gold==beforeGold and #ui.run.relics==beforeRelics,
                            'leaving an unavailable source identity cannot grant a substitute')
                        break
                    end
                    assert(ui.nodeUI.actions['treasureView/rewardItem'..choice].enabled)
                    local pending=#ui.run.nodeFlow.reward.items
                    click(root,'nodePanel','treasureView/rewardItem'..choice)
                    assert(#ui.run.nodeFlow.reward.items<pending,'each claim consumes only a real pending item')
                end
            elseif ui.nodeUI.actions["campView/rest"].enabled then click(root, "nodePanel", "campView/rest")
            else
                click(root, "nodePanel", "campView/forge"); click(root, "nodePanel", "pickerView/forgeGrid/card1")
                click(root, "nodePanel", "confirm")
            end
            if node.type == "camp" or node.type == "event" then
                if node.type=="camp" then ui.nodeUI:update(2) end
                -- The result stays on the node panel until the player continues.
                assert(ui.mode == "node" and ui.run.phase == "map" and not ui.mapUI.navigationEnabled)
                click(root, "nodePanel", "confirm")
            end
        end
        assert(ui.map.floor == floor and ui.run.nodeFlow.complete)
        assert(ui.mode == (floor == data.rules.map.floors and "victory" or "map"))
    end
    -- Optional shop/event/elite rooms are no longer artificially forced on every route.
    for _, kind in ipairs({"combat", "treasure", "camp", "boss"}) do assert(seen[kind], "missing mandatory panel " .. kind) end
    local eventCount=0;for _ in pairs(seenEvents) do eventCount=eventCount+1 end
    assert(eventCount>=2,'same real map route must reach multiple different events')
    assert(root:GetChild("menuPanel"):GetChild("title").text == "深渊已被封印")
    assert(statValue(root, "floor") == data.rules.map.floors .. " / " .. data.rules.map.floors)
    assert(resultText(root, "subtitle") == "随着守卫倒下，岩元素的光芒重新沿着石纹蔓延。裂隙逐渐闭合，遗迹恢复了往日的寂静。荧收起剑，继续自己的旅途。")
    preview("victory", resultText(root, "subtitle"))
    local previous=ui.run
    testStartButton(root)
    assert(ui.mode=='node' and ui.map.floor==0 and #ui.run.deck==10)
    completeRestartOpening(ui,root,previous)
    assert(ui.mode == "map" and ui.map.floor == 0 and #ui.run.deck == 10)
end)

test("same-run result records active time and victories, freezes on results and resets on restart", function()
    local ui, root = fixture()
    ui:update(100)
    assert(testStart(ui))
    assert(ui.run.elapsedSeconds == 0 and ui.run.victories == 0)
    ui:update(60.5) ui:update(1.75)
    assert(ui.run.elapsedSeconds == 62.25)
    for _, dt in ipairs({-1, math.huge, -math.huge, 0/0, "1", false}) do
        local ok, reason = ui:update(dt)
        assert(not ok and reason == "invalid_delta" and ui.run.elapsedSeconds == 62.25)
    end
    assert(not ui:update(nil))
    assert(ui.mapUI:choose(Nodes.available(ui.run, ui.map)[1].id))
    local battle = ui.run.combat
    for _, enemy in ipairs(battle.enemies) do enemy.hp = 0 end
    assert(require("abyss_run").finishCombat(ui.run))
    assert(ui.run.victories == 1)
    assert(not require("abyss_run").finishCombat(ui.run) and ui.run.victories == 1)
    assert(require("abyss_run").claimCardReward(ui.run, 0))
    ui:refresh() ui:update(1)
    assert(ui.run.elapsedSeconds == 63.25)
    ui.run.phase = "defeat" ui:refresh()
    assert(statValue(root, "time") == "01:03" and statValue(root, "victories") == "1")
    ui:update(100)
    assert(ui.run.elapsedSeconds == 63.25)
    assert(testStart(ui) and ui.run.elapsedSeconds == 0 and ui.run.victories == 0)
    ui:update(3)
    ui.run.phase = "victory"
    ui.run.nodeFlow = {complete=true, result="boss_treasure_complete"}
    ui:refresh() ui:update(100)
    assert(ui.run.elapsedSeconds == 3)
    assert(statValue(root, "time") == "00:03")
end)

test("result settlement sends each outcome once and cannot restart while official settlement is pending", function()
    local outcomes = {}
    local ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory end)
    assert(not ui:settle() and #outcomes == 0)
    assert(not root:GetChild("menuPanel"):GetChild("settle").visible)
    assert(testStart(ui)) assert(not ui:settle())
    ui.run.phase = "defeat" ui:refresh()
    assert(testStart(ui) and not ui.settlementRequested)
    ui.run.phase = "defeat" ui:refresh()
    assert(root:GetChild("menuPanel"):GetChild("start").x < 0)
    assert(root:GetChild("menuPanel"):GetChild("settle").visible)
    assert(click(root, "menuPanel", "settle"))
    assert(#outcomes == 1 and outcomes[1] == false and ui.settlementRequested)
    assert(root:GetChild("menuPanel"):GetChild("settle"):GetChild("disabled").visible)
    assert(not ui:settle() and #outcomes == 1)
    assert(not testStart(ui) and not root:GetChild("menuPanel"):GetChild("start").visible)
    ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory end)
    assert(testStart(ui))
    ui.run.phase = "victory"
    ui.run.nodeFlow = {complete=true, result="boss_treasure_complete"}
    ui:refresh() assert(ui.mode == "victory")
    assert(click(root, "menuPanel", "settle"))
    assert(#outcomes == 2 and outcomes[2] == true)
    assert(not ui:settle() and #outcomes == 2)
end)

test("settlement callback failure is visible and retryable without claiming official completion", function()
    local attempts, ui = 0, nil
    local root
    ui, root = fixture(nil, function()
        attempts = attempts + 1
        assert(not ui:settle(), "reentrant settlement must be rejected")
        if attempts == 1 then error("injected send failure") end
        if attempts == 2 then return false end
    end)
    testStart(ui) ui.run.phase = "defeat" ui:refresh()
    for _ = 1, 2 do
        assert(not click(root, "menuPanel", "settle"))
        assert(not ui.settlementRequested and not ui.settlementBusy)
        assert(resultText(root, "status"):find("结算请求失败", 1, true))
        preview("settlementError", resultText(root, "status"))
    end
    assert(click(root, "menuPanel", "settle") and attempts == 3)
    assert(root:GetChild("menuPanel"):GetChild("settle"):GetChild("label").text == "已发送结算请求")
    assert(ui.mode == "defeat", "sending a signal is not official settlement confirmation")
    local unavailable = fixture()
    testStart(unavailable) unavailable.run.phase = "defeat" unavailable:refresh()
    local ok, reason = unavailable:settle()
    assert(not ok and reason == "settlement_unavailable" and not unavailable.settlementRequested)
    assert(resultText(root, "status") ~= nil)
    local line = unavailable.root:GetChild("menuPanel"):GetChild("result"):GetChild("status").text
    assert(line:find("暂不可用", 1, true) and not unavailable.root:GetChild("menuPanel"):GetChild("settle"):GetChild("normal").visible)
end)

test("menu keeps the introduction and start without route or control instructions", function()
    local ui, root = fixture()
    local menu = root:GetChild("menuPanel")
    assert(ui.mode == "menu" and menu:GetChild("tagline").visible and not menu:GetChild("result").visible)
    assert(menu:GetChild("summary").text == "" and not menu:GetChild("summary").visible)
    for _, name in ipairs({"title", "tagline", "summary"}) do
        assert(not menu:GetChild(name).text:find("十五层", 1, true), name .. " keeps the stale floor count")
    end
    assert(ui.battleUI.instructions ~= "", "battle control guidance remains available")
    assert(menu:GetChild("start"):GetChild("label").text == "启程" and not menu:GetChild("settle").visible)
end)

test("result page shows only the recorded run stats in the approved four cells", function()
    local ui, root = fixture(nil, function() end)
    assert(testStart(ui))
    ui.run.victories, ui.run.elapsedSeconds, ui.run.gold, ui.run.hp = 7, 3725.9, 211, 33
    ui.run.phase = "defeat" ui:refresh()
    local menu = root:GetChild("menuPanel")
    assert(menu:GetChild("result").visible and not menu:GetChild("summary").visible and not menu:GetChild("tagline").visible)
    assert(menu:GetChild("title").text == "旅途在此中断")
    assert(resultText(root, "subtitle") == "封印仍在崩解，遗迹深处的回廊再一次归于黑暗。")
    assert(statValue(root, "floor") == ui.map.floor .. " / " .. Data.rules.map.floors)
    assert(statValue(root, "victories") == "7" and statValue(root, "time") == "62:05")
    assert(statValue(root, "deck") == tostring(#ui.run.deck))
    local labels = {}
    for _, key in ipairs({"floor", "victories", "time", "deck"}) do
        labels[#labels + 1] = menu:GetChild("result"):GetChild("stat_" .. key):GetChild("label").text
    end
    assert(table.concat(labels, "|") == "抵达层数|战斗胜场|用时|卡组张数")
    -- Defeat always reports 0 HP; untracked prototype figures (enemies slain, gold earned) never appear.
    assert(resultText(root, "detail") == "生命 0 / " .. ui.run.maxHp .. " · 金币 211 · 遗物 " .. #ui.run.relics .. " 件")
    for _, name in ipairs({"subtitle", "detail", "status"}) do
        assert(not resultText(root, name):find("击败敌人", 1, true) and not resultText(root, name):find("获得金币", 1, true))
    end
    assert(menu:GetChild("start"):GetChild("label").text == "重新启程")
    assert(resultText(root, "status"):find("不会提交", 1, true))
    ui.run.phase = "victory" ui.run.nodeFlow = {complete=true, result="boss_treasure_complete"} ui:refresh()
    assert(menu:GetChild("title").text == "深渊已被封印" and resultText(root, "detail"):find("生命 33 / ", 1, true))
    assert(resultText(root, "subtitle") == "随着守卫倒下，岩元素的光芒重新沿着石纹蔓延。裂隙逐渐闭合，遗迹恢复了往日的寂静。荧收起剑，继续自己的旅途。")
end)

test("repeated settlement clicks, clicks during reveal and restart attempts submit exactly once", function()
    local outcomes = {}
    local ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory return true end)
    local menu = root:GetChild("menuPanel")
    assert(testStart(ui)) ui.run.phase = "defeat" ui:refresh()
    assert(ui.motion.t == 0, "reveal has just begun")
    local hit = menu:GetChild("settle"):GetChild("hit")
    assert(menu:GetChild("settle").visible and menu:GetChild("start").visible, "reveal never hides result actions")
    assert(hit.click() == true)
    for _ = 1, 5 do assert(hit.click() == false) end
    ui:update(0.05) assert(hit.click() == false)
    assert(menu:GetChild("start"):GetChild("hit").click() == false and ui.mode == "defeat")
    assert(#outcomes == 1 and outcomes[1] == false)
    assert(menu:GetChild("settle"):GetChild("disabled").visible and not menu:GetChild("settle"):GetChild("normal").visible)
    assert(resultText(root, "status"):find("已发送", 1, true))
    ui:refresh() ui:update(1) ui:refresh()
    assert(#outcomes == 1, "refresh and animation frames never resend")
    -- A fresh host (platform Retry reloads the stage) may settle its own result once.
    ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory return true end)
    hit = root:GetChild("menuPanel"):GetChild("settle"):GetChild("hit")
    assert(testStart(ui)) ui.run.phase = "victory" ui.run.nodeFlow = {complete=true, result="boss_treasure_complete"} ui:refresh()
    assert(hit.click() == true and hit.click() == false)
    assert(#outcomes == 2 and outcomes[2] == true)
end)

test("result reveal settles exactly on approved frames and feedback motion never hides controls", function()
    local L, T = Theme.layout.nativeMenu, Theme.motion
    local fail = true
    local ui, root = fixture(nil, function() return not fail end)
    local menu = root:GetChild("menuPanel")
    local result, emblem, settle = menu:GetChild("result"), menu:GetChild("emblem"), menu:GetChild("settle")
    assert(testStart(ui)) ui.run.phase = "defeat" ui:refresh()
    assert(math.abs(emblem.scale[1] - L.reveal.emblemFrom) < 1e-9)
    assert(menu:GetChild("title").y < L.title[2])
    local card = result:GetChild("stat_deck")
    assert(card.scale[1] < 1 and card.visible)
    ui:update(T.slow / 2)
    assert(card.scale[1] < 1 and result:GetChild("stat_floor").scale[1] > card.scale[1], "cards reveal in order")
    ui:update(1)
    assert(emblem.scale[1] == 1 and menu:GetChild("title").y == L.title[2] and result:GetChild("subtitle").y == L.subtitle[2])
    for i, key in ipairs({"floor", "victories", "time", "deck"}) do
        local stat = result:GetChild("stat_" .. key)
        assert(stat.scale[1] == 1 and stat.x == L.stats.origin[1] + (i - 1) * L.stats.step and stat.y == L.stats.origin[2])
    end
    assert(menu:GetChild("start").x == L.resultRestart[1] and settle.x == L.settle[1])
    assert(not ui:settle())
    assert(settle.x == L.settle[1] and ui.motion.shake == 0)
    ui:update(T.shake / 3)
    assert(settle.x ~= L.settle[1] and settle.visible, "failure shakes the button in place")
    ui:update(1)
    assert(settle.x == L.settle[1] and settle:GetChild("normal").visible)
    fail = false
    assert(ui:settle())
    ui:update(T.base / 2)
    assert(settle.x > 0 and settle.x < L.settle[1], "requested button slides toward centre")
    ui:update(1)
    assert(settle.x == 0 and settle.visible and not menu:GetChild("start").visible)
    local glow = emblem:GetChild("glow")
    ui:update(L.reveal.breathe / 4)
    assert(glow.scale[1] > 1 and glow.scale[1] <= 1 + L.reveal.breatheScale + 1e-9)
end)

test("viewport scales each device uniformly and covers wider canvas outside the stage", function()
    local root = control({ children = Layout })
    for _, device in ipairs({{1280,720,1}, {1600,900,1.25}, {1920,1080,1.5}, {2340,1080,1.5}}) do
        local stage, scale = Viewport.apply(root, device[1], device[2])
        assert(scale == device[3] and stage.scale[1] == scale and stage.scale[2] == scale)
        assert(root:GetChild("canvasBackdrop").sizeDeltaX == 0)
        assert(root:GetChild("canvasBackdrop").sizeDeltaY == 0)
    end
    assert(not pcall(Viewport.apply, root, 0, 720))
end)

test("host defers defeat routing until the final feedback banner and releases result input once", function()
    local ui, root = fixture()
    assert(testStart(ui)) assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    ui.run.combat.player.hp = 1 ui.battleUI:render()
    for _ = 1, 8 do
        ui.battleUI:endTurn()
        if ui.run.phase == "defeat" then break end
        -- Drain nonlethal turn feedback, but retain the lethal banner below.
        for _ = 1, 400 do
            if not ui.battleUI.busy then break end
            ui:update(0.05)
        end
        assert(not ui.battleUI.busy)
    end
    assert(ui.run.phase == "defeat" and ui.battleUI.busy)
    ui:refresh()
    assert(ui.mode == "battle" and not root:GetChild("menuPanel").visible)
    local sawDefeat = false
    for _ = 1, 200 do
        if not ui.battleUI.busy then break end
        if ui.battleUI.feedback.current.kind == "defeat" then
            sawDefeat = true assert(ui.mode == "battle" and root:GetChild("battlePanel").visible)
        end
        ui:update(0.05)
    end
    assert(sawDefeat and ui.mode == "defeat" and root:GetChild("menuPanel").visible)
    assert(not ui.battleUI.busy)
end)

test("native lifecycle loads every composed control and registers its listeners only once", function()
    local canvas = control({ children = Layout })
    local root = canvas:GetChild("stage")
    local oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor = script, Enum, OnStart, OnUpdate, game, Color
    script = { object = canvas, EnableUpdate = function(self, value) self.updating = value end }
    Enum = { CursorEventType = { CursorClick = "click" }, ImageSource = { StaticReference = "static" } }
    Color = setmetatable({ FromRGB = function() end }, {
        __call = function(_,r,g,b,a) return {r=r,g=g,b=b,a=a} end,
    })
    local width, height = 1600, 900
    game = { GetUICanvasSize = function() return width, height end, IsTestPlay=function()return true end }
    Enum.Device={Mobile='mobile',Controller='controller',MobileController='mobile-controller'}
    game.GetDevice=function()return 'desktop'end
    game.GetCursorUIPos=function()return 0,0 end
    dofile('tests/lua/support/native_monster_engine.lua')(game)
    dofile("src/lua/abyss_ui.lua")
    F.nativeWorld(OnDestroy,script)
    OnStart()
    OnStart()
    assert(root.scale[1] == 1.25)
    assert(script.updating)
    click(root, "menuPanel", "start")
    assert(root:GetChild("characterPanel").visible and not root:GetChild("prologuePanel").visible)
    click(root, "characterPanel", "traveler")
    assert(root:GetChild("characterPanel").visible and not root:GetChild("mapPanel").visible)
    click(root, "characterPanel", "confirm")
    assert(not root:GetChild("characterPanel").visible)
    for _ = 1, 8 do OnUpdate(0.25) end
    assert(not root:GetChild("mapPanel").visible and not root:GetChild("prologuePanel").visible)
    assert(root:GetChild('nodePanel').visible and root:GetChild('nodePanel'):GetChild('eventView').visible)
    for _ = 1, 8 do OnUpdate(0.25) end
    assert(not root:GetChild('prologuePanel').visible and root:GetChild('nodePanel').visible)
    assert(not root:GetChild("menuPanel").visible)
    width, height = 2340, 1080
    OnUpdate(0.25)
    assert(root.scale[1] == 1.5 and canvas:GetChild("canvasBackdrop").sizeDeltaX == 0)
    assert(root:GetChild("mapPanel").localScaleX == nil or root:GetChild("mapPanel").localScaleX == 1)
    script, Enum, OnStart, OnUpdate, game, Color = oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor
end)
test("startup failure is visible without log subscription and hides the dead start button", function()
    local canvas = control({ children = Layout })
    local oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor = script, Enum, OnStart, OnUpdate, game, Color
    local actualGameUI=require('abyss_game_ui')
    local originalNew = actualGameUI.new
    actualGameUI.new = function() error("INJECTED_STARTUP_FAILURE") end
    script = {object=canvas, EnableUpdate=function(self,value) self.updating=value end}
    Enum = {CursorEventType={CursorClick="click"},ImageSource={StaticReference="static"}}
    game = {GetUICanvasSize=function() return 1280,720 end,IsTestPlay=function() return true end}
    dofile("src/lua/abyss_ui.lua")
    F.nativeWorld(OnDestroy,script)
    OnStart()
    local stage = canvas:GetChild("stage")
    local menu = stage:GetChild("menuPanel")
    assert(menu.visible and menu:GetChild("summary").text:match("INJECTED_STARTUP_FAILURE"))
    assert(not menu:GetChild("start").visible and script.updating == false)
    assert(not menu:GetChild('codeVersion').visible)
    assert(not stage:GetChild("mapPanel").visible and not stage:GetChild("battlePanel").visible)
    OnStart() OnUpdate(0.1)
    actualGameUI.new = originalNew
    -- A stale/mismatched imported tree must still show the startup diagnostic,
    -- even though a required shared panel is absent.
    local stale = control({ children = Layout })
    local staleStage = stale:GetChild('stage')
    staleStage.children.exitPanel = nil
    script = {object=stale, EnableUpdate=function(self,value) self.updating=value end}
    Enum.Device={Mobile='mobile',Controller='controller',MobileController='mobile-controller'}
    game.GetDevice=function()return 'desktop'end
    game.GetCursorUIPos=function()return 0,0 end
    dofile('tests/lua/support/native_monster_engine.lua')(game)
    dofile('src/lua/abyss_ui.lua')
    F.nativeWorld(OnDestroy,script)
    OnStart()
    local staleMenu = staleStage:GetChild('menuPanel')
    assert(staleMenu.visible and staleMenu:GetChild('summary').visible)
    assert(staleMenu:GetChild('summary').text:match('missing game panel exitPanel'))
    assert(not staleMenu:GetChild('start').visible and script.updating == false)
    script, Enum, OnStart, OnUpdate, game, Color = oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor
end)

assert(registered==16,'original current entry case inventory changed')
if group then
    assert(count==#group,'current entry group did not execute completely')
    print("LUA_GAME_UI_GROUP_PASS "..count)
else assert(count==16);print("LUA_GAME_UI_PASS "..count)end
