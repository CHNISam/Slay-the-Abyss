local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local F = dofile('tests/lua/support/game_ui_fixture.lua')
-- Use the full generated native import tree; missing controls fail loudly.
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "",
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true,
        x = definition.position and definition.position[1] or 0, y = definition.position and definition.position[2] or 0 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn) NativeContract.listener(event,fn);
        self.listeners = self.listeners or {}
        self.listeners[event] = fn
        if event == "click" then self.click = fn end
    end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetSizeDelta(x, y) NativeContract.sizeDelta(x,y); self.sizeDeltaX, self.sizeDeltaY = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(...)
        assert(select("#", ...) == 2, "SetImage expects exactly source and id")
        local source, id = ...
        assert(source == "static" and type(id) == "number") self.imageId = id
    end
    function c:SetAsLastSibling() self.raised = true end
    return c
end

local function setup()
    local root = control({name="root",size={1280,720},children=Layout})
    local panel = root:GetChild("stage"):GetChild("battlePanel")
    local ui = UI.new(panel,Data,Presentation,"click",F.withMonsterActors({
        imageSource="static",color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
        cursorEvents={CursorDown="down",CursorDrag="drag",CursorUp="up",CursorEndDrag="endDrag"}
    }),{embedded=true})
    ui.run = Run.new(Data,1)
    assert(Run.startCombat(ui.run,"cultist_solo"))
    ui.run.combat = Combat.new(Data,{deck={"defend","defend"},enemies={"cultist"}})
    ui:resize(1280,720) ui:render()
    local function event(name,kind,x,y,touch)
        local box = assert(F.actorControl(panel,name))
        local hit = box.listeners and box or box:GetChild("hit")
        local callback = assert(hit.listeners[kind],"missing native listener: "..name.."/"..kind)
        callback({touchId=touch or 7,GetUIPos=function() return 640+x,360+y end})
    end
    local function tap(name,touch)
        local box = assert(F.actorControl(panel,name))
        event(name,"down",box.x,box.y,touch)
        event(name,"up",box.x,box.y,touch)
        event(name,"click",box.x,box.y,touch)
    end
    return ui,panel,event,tap
end
local count = 0
local function test(name,fn) fn(); count=count+1; print("ok drag boundary "..count.." - "..name) end
local function drain(ui)
    for _=1,400 do if not ui.busy then return end ui:update(0.05) end
    assert(not ui.busy,"feedback must finish")
end

test("stationary release from an old battle cannot click the replacement hand",function()
    local ui,panel,event,tap = setup()
    local old = ui.run.combat
    local x,y = panel:GetChild("card1").x,panel:GetChild("card1").y
    event("card1","down",x,y)
    local current = Combat.new(Data,{deck={"defend","defend"},enemies={"cultist"}})
    ui.run.combat = current -- No render between replacement and queued release.
    event("card1","up",x,y)
    event("card1","click",x,y)
    assert(ui.selected == nil,"stale stationary release selected a replacement card")
    assert(#current.hand == 2 and current.energy == 3 and current.player.block == 0)
    assert(#old.hand == 2 and old.energy == 3)
    tap("card1") tap("playArea")
    assert(#current.hand == 1 and current.energy == 2 and current.player.block == 5)
end)

test("stationary cancellation guards turn, run, phase, inactive and busy changes without a render",function()
    for _,kind in ipairs({"turn","run","phase","inactive","busy"}) do
        local ui,panel,event,tap = setup()
        local battle = ui.run.combat
        local x,y = panel:GetChild("card1").x,panel:GetChild("card1").y
        event("card1","down",x,y)
        if kind == "turn" then battle.turn = battle.turn+1
        elseif kind == "run" then
            local replacement = Run.new(Data,9)
            assert(Run.startCombat(replacement,"cultist_solo"))
            replacement.combat = battle
            ui.run = replacement
        elseif kind == "phase" then battle.phase = "enemy"
        elseif kind == "inactive" then ui.active = false
        elseif kind == "busy" then ui.busy = true end
        event("card1","up",x,y)
        -- Even if input becomes available before a queued click, it stays consumed.
        battle.phase,ui.active,ui.busy = "player",true,false
        event("card1","endDrag",x,y) event("card1","click",x,y)
        assert(ui.selected == nil and ui.gesture == nil,kind)
        assert(#battle.hand == 2 and battle.energy == 3 and battle.player.block == 0,kind)
        ui:render()
        tap("card1") tap("playArea")
        assert(#battle.hand == 1 and battle.energy == 2 and battle.player.block == 5,kind)
    end
end)

test("fresh stationary taps retain click fallback and a foreign touch cannot release a grab",function()
    local ui,panel,event,tap = setup()
    local battle = ui.run.combat
    local x,y = panel:GetChild("card1").x,panel:GetChild("card1").y
    event("card1","down",x,y,7)
    event("card1","up",x,y,8) event("card1","click",x,y,8)
    assert(ui.gesture and ui.selected == nil and #battle.hand == 2)
    event("card1","up",x,y,7) event("card1","click",x,y,7)
    assert(ui.selected == battle.hand[1].uid and #battle.hand == 2)
    tap("playArea",7)
    assert(#battle.hand == 1 and battle.energy == 2 and battle.player.block == 5)
end)

test("cancelled drags back in the hand never click through and accept the next tap",function()
    for _,point in ipairs({{0,-240},{512,-206},{-560,-200}}) do
        local ui,panel,event,tap = setup()
        local battle = ui.run.combat
        -- This case starts in the expanded hand, not at the source draw-pile
        -- opening position. Advance the real animation without changing input bounds.
        local before=Combat.copy(battle)
        local function same(a,b)
            if a==b then return true end
            if type(a)~='table' or type(b)~='table' then return false end
            for k,v in pairs(a)do if not same(v,b[k])then return false end end
            for k in pairs(b)do if a[k]==nil then return false end end
            return true
        end
        local card=panel:GetChild('card1')
        for _=1,80 do ui:update(1/60)end -- Existing opening-hand replay cadence.
        local x,y=card.x,card.y;ui:update(1/60)
        assert(card.x==x and card.y==y,'opening card must have a source-settled position')
        assert(same(before,battle),'settling visuals must preserve complete battle state, including RNG')
        assert(#battle.hand==2 and battle.energy==3 and battle.turn==1)
        event("card1","down",x,y) event("card1","drag",point[1],point[2])
        ui:update(0.45) -- source: a short (<.4s) out-of-zone release retains click-drag
        event("dragLayer","up",point[1],point[2])
        event("card1","endDrag",point[1],point[2]) event("endTurn","click",0,0)
        event("card1","click",x,y)
        assert(#battle.hand == 2 and battle.energy == 3 and battle.turn == 1)
        assert(ui.selected == nil and not panel:GetChild("dragLayer").visible)
        tap("card1") tap("playArea")
        assert(#battle.hand == 1 and battle.player.block == 5)
    end
end)

test("unsettled opening drag uses its real source-relative valid drop line",function()
    local ui,panel,event=setup()
    local battle,card=ui.run.combat,panel:GetChild('card1')
    local pile=require('abyss_theme').layout.drawPile.position
    assert(card.x==pile[1] and card.y==pile[2],'negative control starts at the actual draw pile')
    local x,y=card.x,card.y
    assert(-200>y+140*720/1080,'opening point lies above the original hoverStartLine')
    event('card1','down',x,y)
    assert(-200>ui.gesture.hoverStartLine and -200>ui.gesture.handCancelY,
        'opening release lies above both actual source lift and hand cancellation lines')
    event('card1','drag',-560,-200)
    ui:update(0.45)
    event('dragLayer','up',-560,-200)
    event('card1','endDrag',-560,-200);event('endTurn','click',0,0)
    event('card1','click',x,y)
    assert(#battle.hand==1 and battle.energy==2 and battle.turn==1 and battle.player.block==5,
        'valid opening release plays one Defend; trailing clicks cannot end turn or play twice')
end)

test("targeted drag pulled back to the hand cancels and commits only the aimed living enemy",function()
    local ui,panel,event = setup()
    local battle = Combat.new(Data,{deck={"strike"},enemies={"cultist","jaw_worm"}})
    for index,actor in ipairs(battle.enemies) do actor.sourcePosition={x=-600+(index-1)*500,y=0} end
    ui.run.combat = battle ui:render()
    local x,y = panel:GetChild("card1").x,panel:GetChild("card1").y
    local hp1,hp2 = battle.enemies[1].hp,battle.enemies[2].hp
    event("card1","down",x,y) event("card1","drag",-200,0) event("card1","drag",x,-340) event("card1","up",x,-340)
    event("enemy1","click",0,0)
    assert(#battle.hand == 1 and battle.energy == 3 and battle.enemies[1].hp == hp1)
    local enemy = monsterControl(panel,"enemy2")
    event("card1","down",x,y) event("card1","drag",enemy.x,enemy.y)
    event("dragLayer","up",enemy.x,enemy.y) event("card1","endDrag",enemy.x,enemy.y)
    assert(#battle.hand == 0 and battle.energy == 2 and battle.enemies[1].hp == hp1 and battle.enemies[2].hp == hp2-6)
end)

test("real feedback rejects new drag input until playback ends",function()
    local ui,panel,event,tap = setup()
    local battle = ui.run.combat
    tap("card1") tap("playArea")
    assert(ui.busy and #battle.hand == 1)
    local x,y = panel:GetChild("card1").x,panel:GetChild("card1").y
    event("card1","down",x,y) event("card1","drag",0,0) event("card1","up",0,0)
    event("card1","click",x,y)
    assert(ui.gesture == nil and #battle.hand == 1 and battle.energy == 2)
    drain(ui)
    tap("card1") tap("playArea")
    assert(#battle.hand == 0 and battle.energy == 1 and battle.player.block == 10)
end)

test("stationary release cannot select a shifted or missing hand slot",function()
    for _,kind in ipairs({"shifted","missing"}) do
        local ui,panel,event,tap = setup()
        local battle = ui.run.combat
        local slot = kind == "missing" and 2 or 1
        local name = "card"..slot
        local x,y = panel:GetChild(name).x,panel:GetChild(name).y
        event(name,"down",x,y)
        table.remove(battle.hand,slot)
        event(name,"up",x,y) event(name,"click",x,y)
        assert(ui.selected == nil and ui.gesture == nil,"stale slot must cancel: "..kind)
        assert(ui.suppressClick == true,"missing slot must consume queued clicks")
        assert(#battle.hand == 1 and battle.energy == 3 and battle.player.block == 0)
        tap("card1") tap("playArea")
        assert(#battle.hand == 0 and battle.energy == 2 and battle.player.block == 5)
    end
end)
print("LUA_DRAG_BOUNDARIES_PASS "..count)
