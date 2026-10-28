-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Theme = require("abyss_theme")
local Controller = require("abyss_controller")
local M = {}
local L = Theme.layout
-- Only this responsibility owns these closures; cross-responsibility calls are explicit ports.
function M.install(owner, _ownership, host, dependencies)
    local function statusActorAt(slot)
        local battle=owner.run and owner.run.combat
        if not battle then return end
        if slot==0 then return battle,0,battle.player end
        local entry=dependencies.enemyAt(slot,battle)
        if entry then return battle,entry.index,entry.actor end
    end
    local function bindDetailControls()
        -- Enemy portraits keep targeting; the hero portrait and every status row only open
        -- details, so a status tap never plays a card or moves the potion target.
        dependencies.listen(dependencies.child("hero"):GetChild("hit"), function() owner:showStatus(0) end)
        for i, name in ipairs({"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}) do
            local screenSlot = i - 1
            dependencies.listen(dependencies.child(name):GetChild("statusRow"):GetChild("hit"), function()
                local entry=screenSlot>0 and dependencies.enemyAt(screenSlot)
                if screenSlot==0 or entry then owner:showStatus(entry and entry.index or 0) end
            end)
        end
        local info = dependencies.child("statusInfo")
        info.disableCursorEventPassthrough = true
        dependencies.listen(info:GetChild("hit"), function() if dependencies.closeInfo() then owner:render() end end)
        -- A tap on the card itself turns to the next page; a single page closes like any tap.
        -- Not routed through listen(): that dismisses the open card before any handler runs.
        local function infoPage()
            local open = owner.info
            if not open then return end
            owner.swallow = nil
            if (open.pages or 1) > 1 then open.page = open.page % open.pages + 1 owner:render()
            elseif dependencies.closeInfo() then owner:render() end
        end
        info:GetChild("page"):AddCursorEventListener(host.clickEvent,function()
            if Controller.pointerBlocked(host.controller)then return false end
            return infoPage()
        end)
        Controller.bind(host.controller,info:GetChild("page"),"battleInfo",infoPage,nil,1)
        -- hoverSlot: a reward card also reports pointer enter/exit for its hover pose (one listener per event).
        local function bindHelp(control,describe,clickable,hoverSlot)
            local input={}
            local function cancel()
                input.held,input.released=nil,nil
                if hoverSlot and owner.hover==hoverSlot then owner:setHover(nil) end
                if owner.help and owner.help.source==control then owner.help=nil end
                if owner.info and owner.info.source==control and owner.info.transient then dependencies.closeInfo();owner:render() end
            end
            if host.cursor and host.cursor.CursorEnter and host.cursor.CursorExit then
                control:AddCursorEventListener(host.cursor.CursorEnter,function()
                    if hoverSlot then owner:setHover(hoverSlot) end
                    owner:queueHelp(describe(),control,false)
                end)
                control:AddCursorEventListener(host.cursor.CursorExit,cancel)
            end
            if not clickable then return end
            Controller.bind(host.controller,control,function()return owner.potionAim and "aim" or "battle"end,function()
                local spec=describe()
                if spec then return owner:openHelp(spec,control,false)end
            end,dependencies.controllerReady,80)
            local function ready(token)
                local run=owner.run
                return token and owner.active and not owner.busy and not owner.gesture and run==token.run
                    and run.phase=="combat" and run.combat==token.battle and run.combat.turn==token.turn
                    and dependencies.helpActorReady(token,run)
                    and (token.spec.kind~="potion" or run.potions==token.spec.inventory and run.potions[token.spec.slot]==token.spec.potionId)
            end
            control:AddCursorEventListener(host.clickEvent,function(event)
                if Controller.pointerBlocked(host.controller)then return false end
                local touch=event and event.touchId
                if input.consumed and input.consumed.touch==touch then input.consumed=nil;return end
                if input.pointerObserved then
                    local token=input.released;input.released=nil
                    if not ready(token) or token.touch~=touch then return end
                end
                if dependencies.swallowed(event) then return end
                local spec=describe()
                if spec then owner:openHelp(spec,control,false) end
            end)
            if host.cursor and host.cursor.CursorDown and host.cursor.CursorUp then
                control:AddCursorEventListener(host.cursor.CursorDown,function(event)
                    input.pointerObserved=true;input.held,input.released,input.consumed=nil,nil,nil
                    if dependencies.down(event) then return end
                    local run=owner.run
                    if not run or run.phase~="combat" then return end
                    local spec=describe()
                    if not spec then return end
                    local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
                    local token={run=run,battle=run.combat,turn=run.combat.turn,touch=event and event.touchId,spec=spec,actor=actor}
                    if ready(token) then input.held=token;owner:queueHelp(describe(),control,true,token.touch) end
                end)
                control:AddCursorEventListener(host.cursor.CursorUp,function(event)
                    local token=input.held;input.held=nil
                    if not ready(token) or token.touch~=(event and event.touchId) then return end
                    local help=owner.help
                    if help and help.source==control and help.fired then
                        input.consumed={touch=token.touch}
                        if owner.info and owner.info.source==control then owner.info.transient=false;owner:render() end
                    else input.released=token end
                    if help and help.source==control then owner.help=nil end
                end)
                if host.cursor.CursorEndDrag then control:AddCursorEventListener(host.cursor.CursorEndDrag,cancel) end
            end
        end
        for i,name in ipairs({"hero","enemy1","enemy2","enemy3","enemy4","enemy5"}) do
            local screenSlot=i-1
            if screenSlot>0 then bindHelp(dependencies.child(name):GetChild("intentHit"),function()
                local entry=dependencies.enemyAt(screenSlot)
                return entry and {kind="intent",index=entry.index,screenSlot=screenSlot}
            end,true) end
            for slot=1,L.statusIcon.perRow*L.statusIcon.rows do
                local position=slot
                bindHelp(dependencies.child(name):GetChild("statusRow"):GetChild("hit"..slot),function()
                    local battle,index,actor=statusActorAt(screenSlot)
                    if not Actors.isPresent(actor)then return end
                    local entries=Combat.statusView(actor)
                    local width=index==0 and L.hpBar.size[1] or select(2,dependencies.enemyPosition(battle,index))
                    local perRow=math.max(1,math.min(L.statusIcon.perRow,math.floor((width+L.statusIcon.gap)/(L.statusIcon.size+L.statusIcon.gap))))
                    local slots=perRow*L.statusIcon.rows
                    if not entries[position] then return end
                    local overflow=position==slots and #entries>slots
                    return {index=index,screenSlot=screenSlot>0 and screenSlot or nil,statusId=not overflow and entries[position].id or nil,
                        offset=overflow and position or nil}
                end,true)
            end
        end
        for slot=1,10 do
            local index=slot
            bindHelp(dependencies.child("card"..slot):GetChild("hit"),function() return owner:cardHelpSpec(index) end,false,slot)
        end
        for slot=1,L.battlePotions.count do
            local index=slot
            bindHelp(dependencies.child("potionHelp"..slot),function() return owner:potionHelpSpec(index) end,true)
            bindHelp(dependencies.child("potion"..slot),function() return owner:potionHelpSpec(index) end,false)
        end
    end
    return {statusActorAt=statusActorAt, bindDetailControls=bindDetailControls}
end
return M
