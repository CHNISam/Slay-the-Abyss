package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")

-- Compose the controller with the actual generated native tree, not a permissive mock.
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "",
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true,
        x = definition.position and definition.position[1] or 0, y = definition.position and definition.position[2] or 0 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn) assert(event == "click") self.click = fn end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetSizeDelta(x, y) self.sizeDeltaX, self.sizeDeltaY = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(source, id) assert(source == "static" and type(id) == "number") self.imageId = id end
    function c:SetAsLastSibling() self.raised = true end
    return c
end
local function setup(options)
    local function find(entries, name)
        for _, entry in ipairs(entries) do
            if entry.name == name then return entry end
            local found = find(entry.children or {}, name)
            if found then return found end
        end
    end
    local stage = control(assert(find(require("abyss_ui_layout"), "battlePanel")))
    local root = stage
    options = {embedded=true}
    local ui = UI.new(root, Data, Presentation, "click", {imageSource="static", color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end}, options)
    local function click(name)
        local box = stage:GetChild(name)
        if box.click then if box.interactable then box.click() end else box:GetChild("hit").click() end
    end
    local function play(slot, target)
        click("card" .. slot)
        local instance = ui.run.phase == "combat" and ui.run.combat.hand[slot]
        if instance and ui.selected == instance.uid then
            local _, reason = Combat.canPlay(ui.run.combat, instance.uid, nil)
            click(reason == "invalid_target" and "enemy" .. (target or 1) or "card" .. slot)
        end
    end
    return ui, stage, click, play, root
end
local count, failed = 0, 0
local function eq(a,b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " growing_card_text " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function fixture(upgraded, deck)
    local ui, stage, click, play = setup()
    ui.run = Run.new(Data, 42)
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat = Combat.new(Data, {deck=deck or {{cardId="rampage", upgraded=upgraded}}})
    ui:render()
    return ui, stage, play
end
local function label(stage, slot)
    local value = stage:GetChild("card" .. (slot or 1)):GetChild("label").text
    assert(not value:find("{",1,true) and not value:find("}",1,true), "unresolved template in label")
    return value
end
local function expected(value, upgraded)
    return "对目标造成 " .. value .. " 点伤害；随后本牌在本场战斗中的伤害增加 " .. (upgraded and "8" or "5") .. " 点。"
end
for _, upgraded in ipairs({false,true}) do
    test((upgraded and "upgraded" or "normal") .. " actual click play and redraw updates only damage", function()
        local ui,stage,play=fixture(upgraded)
        local s=ui.run.combat
        eq(label(stage),expected("8",upgraded))
        play(1); Combat.draw(s,1); ui:render()
        eq(label(stage),expected(upgraded and "16" or "13",upgraded))
        Combat.addStatus(s.player,"strength",3); Combat.addStatus(s.player,"weak",1)
        Combat.addStatus(s.enemies[1],"vulnerable",1); ui:render()
        eq(label(stage),expected(upgraded and "16" or "13",upgraded))
        play(1); Combat.draw(s,1); ui:render()
        eq(label(stage),expected(upgraded and "24" or "18",upgraded))
    end)
    test((upgraded and "upgraded" or "normal") .. " new combat resets text", function()
        local ui,stage,play=fixture(upgraded); local s=ui.run.combat
        play(1); Combat.draw(s,1)
        ui.run.combat=Combat.new(Data,{deck={s.hand[1]}}); ui:render()
        eq(label(stage),expected("8",upgraded))
    end)
    test((upgraded and "upgraded" or "normal") .. " failed rule rolls back growth and label", function()
        local ui,stage,play=fixture(upgraded); local s=ui.run.combat
        play(1); Combat.draw(s,1); ui:render()
        local before=label(stage); local card=s.hand[1]; local bonus=card.damageBonus
        -- Real validated rule path fails after growth, rather than a mocked display failure.
        local effects=upgraded and s.catalog.cards.rampage.upgrade.effects or s.catalog.cards.rampage.effects
        effects[#effects+1]={op="gainStatus",status="missing",value=1}
        eq(pcall(Combat.play,s,card.uid,1),false)
        eq(s.hand[1],card); eq(card.damageBonus,bonus)
        ui:render(); eq(label(stage),before)
    end)
end
test("same id instances retain independent upgraded and normal labels", function()
    local ui,stage,play=fixture(false,{{cardId="rampage"},{cardId="rampage",upgraded=true}})
    local s=ui.run.combat; local first=s.hand[1]
    local upgraded=first.upgraded
    play(1); Combat.draw(s,1); ui:render()
    for i,c in ipairs(s.hand) do
        eq(label(stage,i),expected(c==first and (upgraded and "16" or "13") or "8",c.upgraded))
    end
end)
test("integer floats and damage beyond signed 32 bits render without decimals or wrapping", function()
    for _,case in ipairs({{false,5.0,"13"},{true,8.0,"16"},{false,2147483645.0,"2147483653"}}) do
        local ui,stage=fixture(case[1]); ui.run.combat.hand[1].damageBonus=case[2]; ui:render()
        eq(label(stage),expected(case[3],case[1]))
    end
end)
test("reward remains static even after grown battle", function()
    local ui,stage,play=fixture(true); local s=ui.run.combat
    play(1); Combat.draw(s,1)
    ui.run.phase="reward"; ui.run.rewards={cards={"rampage"},gold=0}; ui:render()
    eq(label(stage),expected("8",false)); eq(label(stage),Presentation.rampage.text)
end)
test("all other 36 card labels are byte for byte static in base and upgrade", function()
    local seen=0
    for _,def in ipairs(Data.cards.cards) do
        if def.id~="rampage" then
            seen=seen+1
            for _,upgraded in ipairs({false,true}) do
                local ui,stage=fixture(upgraded,{{cardId=def.id,upgraded=upgraded}})
                eq(label(stage),upgraded and Presentation[def.id].upgradeText or Presentation[def.id].text)
            end
        end
    end
    eq(seen,36)
end)
test("legacy display without optional fields still renders old static text", function()
    local normal,upgraded=Presentation.rampage.combatText,Presentation.rampage.upgradeCombatText
    Presentation.rampage.combatText=nil; Presentation.rampage.upgradeCombatText=nil
    local ok,reason=pcall(function()
        for _,upgrade in ipairs({false,true}) do
            local ui,stage=fixture(upgrade); ui.run.combat.hand[1].damageBonus=5; ui:render()
            eq(label(stage),upgrade and Presentation.rampage.upgradeText or Presentation.rampage.text)
        end
    end)
    Presentation.rampage.combatText=normal; Presentation.rampage.upgradeCombatText=upgraded
    assert(ok,reason)
end)
print("growing_card_text: " .. (count-failed) .. "/" .. count .. " passed")
assert(failed==0, failed .. " growing_card_text failures")
