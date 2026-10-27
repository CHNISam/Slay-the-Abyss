local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
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
    function c:AddCursorEventListener(event, fn) NativeContract.listener(event,fn); assert(event == "click") self.click = fn end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetSizeDelta(x, y) NativeContract.sizeDelta(x,y); self.sizeDeltaX, self.sizeDeltaY = x, y end
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
            click(reason == "invalid_target" and "enemy" .. (target or 1) or "playArea")
        end
    end
    return ui, stage, click, play, root
end
local Events = require("abyss_events")
local count, failed = 0, 0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function same(a,b)
 eq(type(a),type(b)); if type(a)~="table" then eq(a,b); return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,"unexpected "..tostring(k)) end
end
local function test(name, fn)
 count=count+1; local ok,err=pcall(fn); if not ok then failed=failed+1 end
 print((ok and "ok" or "not ok").." card_feedback "..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function state(id,upgraded)
 return Combat.new(Data,{deck={{cardId=id,upgraded=upgraded}},enemies={"jaw_worm","jaw_worm"}})
end
local function find(s,kind)
 for _,e in ipairs(s.events) do if e.kind==kind then return e end end
 error("missing event "..kind)
end
local function drain(ui)
 for _=1,100 do if not ui.busy then return end ui:update(1) end
 error("queue never completed")
end
for _,id in ipairs({"bloodletting","hemokinesis","offering"}) do
test(id.." self payment frame bypasses block and thorns without attack modifiers",function()
 local s=state(id); s.player.block=20; Combat.addStatus(s.player,"thorns",9)
 Combat.addStatus(s.player,"weak",3); Combat.addStatus(s.player,"vulnerable",3)
 local hp=s.player.hp; local payment=s.catalog.cards[id].effects[1].value
 assert(Combat.play(s,s.hand[1].uid,1))
 local e=find(s,"hp_loss");eq(e.detail.amount,payment);eq(e.detail.target,"player");eq(e.detail.blocked,0)
 eq(e.frame.player.hp,hp-payment);eq(e.frame.player.block,20);eq(s.player.block,20)
 local frozen=e.frame.player.hp;s.player.hp=1;eq(e.frame.player.hp,frozen)
end)
end
test("temporary strength has gain and removal frames after complete mutations",function()
 local s=state("flex",true); assert(Combat.play(s,s.hand[1].uid))
 local e=find(s,"status");eq(e.detail.status,"strength");eq(e.detail.amount,4)
 eq(e.frame.player.statuses.strength,4);eq(e.frame.player.temporaryStrength,4)
 assert(Combat.endTurn(s));local removed
 for _,v in ipairs(s.events) do if v.kind=="status" and v.detail.target=="player" and v.detail.status=="strength" and v.detail.amount==-4 then removed=v end end
 assert(removed);eq(removed.frame.player.statuses.strength,0);eq(removed.frame.player.temporaryStrength,0)
 eq(e.frame.player.statuses.strength,4);eq(e.frame.player.temporaryStrength,4)
end)
for _,id in ipairs({"body_slam","anger"}) do
test(id.." flies to selected enemy and releases committed frames once",function()
 local ui,stage,click,play=setup();ui.run=Run.new(Data,42);assert(Run.startCombat(ui.run,"cultist_solo"))
 local s=state(id);s.player.block=7;ui.run.combat=s;ui:render()
 local hp=s.enemies[2].hp;local events=s.events;play(1,2);assert(ui.busy)
 eq(ui.feedback.flight.tx,Theme.layout.enemyRow.xTo);eq(ui.feedback.flight.ty,Theme.layout.enemyRow.y)
 assert(s.enemies[2].hp<hp);eq(s.enemies[1].hp,s.enemies[1].maxHp)
 if id=="anger" then eq(#s.discard,2);assert(s.discard[1].uid~=s.discard[2].uid) end
 local before=Combat.copy(s);ui:endTurn();same(s,before)
 drain(ui);eq(s.events,events);eq(#s.events,0)
end)
end
test("growth scalar in a captured frame stays detached while actual text grows",function()
 local ui,stage,click,play=setup();ui.run=Run.new(Data,42);assert(Run.startCombat(ui.run,"cultist_solo"))
 local s=state("rampage");ui.run.combat=s;ui:render();play(1,1);drain(ui)
 Combat.draw(s,1);ui:render();assert(stage:GetChild("card1"):GetChild("label").text:find("13",1,true))
 local frame=Events.frame(s);eq(frame.hand[1].damageBonus,5)
 play(1,1);drain(ui);Combat.draw(s,1);ui:render()
 eq(frame.hand[1].damageBonus,5);eq(s.hand[1].damageBonus,10)
 assert(stage:GetChild("card1"):GetChild("label").text:find("18",1,true))
end)
test("HP payment playback shows its own exact frame before later attack",function()
 local ui,stage,click,play=setup();ui.run=Run.new(Data,42);assert(Run.startCombat(ui.run,"cultist_solo"))
 local s=state("hemokinesis");s.player.block=20;ui.run.combat=s;ui:render()
 local hp,enemyHp=s.player.hp,s.enemies[1].hp;play(1,1)
 eq(ui.feedback.current.kind,"play");eq(ui.displayBattle.player.hp,hp)
 ui:update(Theme.motion.base);eq(ui.feedback.current.kind,"hp_loss")
 eq(ui.displayBattle.player.hp,hp-2);eq(ui.displayBattle.player.block,20)
 eq(ui.displayBattle.enemies[1].hp,enemyHp)
 eq(stage:GetChild("hero"):GetChild("floating").text,"2")
 ui:update(Theme.motion.base);eq(ui.feedback.current.kind,"damage")
 assert(ui.displayBattle.enemies[1].hp<enemyHp)
 drain(ui);eq(s.player.hp,hp-2);eq(#s.events,0)
end)
test("UI command exception restores state and unlocks without replaying frames",function()
 local ui,stage,click,play=setup();ui.run=Run.new(Data,42);assert(Run.startCombat(ui.run,"cultist_solo"))
 local s=state("rampage");ui.run.combat=s
 s.catalog.cards.rampage.effects[#s.catalog.cards.rampage.effects+1]={op="gainStatus",status="missing",value=1}
 ui:render();local before=Combat.copy(s);play(1,1)
 eq(ui.busy,false);eq(ui.feedback.busy,false);eq(ui.displayBattle,nil);same(s,before)
end)
test("late exception removes new event frames growth and copy without mutating old frames",function()
 local s=state("rampage"); local card=s.hand[1]
 s.catalog.cards.rampage.effects={{op="damage",value=8},{op="increaseDamageThisCombat",value=5},{op="addCardToDiscard",card="rampage"},{op="gainTemporaryStrength",value=2},{op="loseHp",value=3},{op="gainStatus",status="missing",value=1}}
 local before=Combat.copy(s);local events=s.events;local frame=s.events[1].frame
 eq(pcall(Combat.play,s,card.uid,1),false);same(s,before);eq(s.events,events);eq(s.events[1].frame,frame);eq(s.hand[1],card)
end)
assert(failed==0,failed.." card feedback tests failed")
print("LUA_CARD_FEEDBACK_PASS "..count)
