-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Theme = require("abyss_theme")
local Controller = require("abyss_controller")
local M = {}
local L = Theme.layout
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, _ownership, host, dependencies)
    local function statusActorAt(slot)
        local battle=owner.run and owner.run.combat
        if not battle then return end
        if slot==0 then return battle,0,battle.player end
        local entry=dependencies.enemyAt(slot,battle)
        if entry then return battle,entry.index,entry.actor end
    end
    local function hasCursorPair(first,second)
        return host.cursor and host.cursor[first] and host.cursor[second]
    end
    local function forgetHelp(control,hoverSlot,input)
        input.held,input.released,input.consumed=nil,nil,nil
        if hoverSlot and owner.hover==hoverSlot then owner.hover=nil end
        if owner.help and owner.help.source==control then owner.help=nil end
        if owner.info and owner.info.source==control then owner.info=nil end
    end
    -- hoverSlot: a reward card also reports pointer enter/exit for its hover pose (one listener per event).
    local function bindHelp(control,describe,clickable,hoverSlot,guard,cleanups)
        local function current()return not guard or guard()end
        if not current() then return end
        local input={}
        local function cancel(silent,engineDestroyed)
            if engineDestroyed then input.engineDestroyed=true end
            if input.engineDestroyed then forgetHelp(control,hoverSlot,input);return end
            input.held,input.released,input.consumed=nil,nil,nil
            if hoverSlot and owner.hover==hoverSlot then owner:setHover(nil) end
            if owner.help and owner.help.source==control then owner.help=nil end
            if owner.info and owner.info.source==control and owner.info.transient then dependencies.closeInfo();if silent~=true then owner:render() end end
        end
        if cleanups then cleanups[#cleanups+1]={control=control,cancel=cancel} end
        if hasCursorPair("CursorEnter","CursorExit") then
            control:AddCursorEventListener(host.cursor.CursorEnter,function()
                if not current() then return false end
                if hoverSlot then owner:setHover(hoverSlot) end
                owner:queueHelp(describe(),control,false)
            end)
            if not current() then return end
            control:AddCursorEventListener(host.cursor.CursorExit,cancel)
            if not current() then return end
        end
        if not clickable then return end
        Controller.bind(host.controller,control,function()return owner.potionAim and "aim" or "battle"end,function()
            if not current() then return false end
            local spec=describe()
            if spec then return owner:openHelp(spec,control,false)end
        end,function()return current() and dependencies.controllerReady()end,80)
        if not current() then return end
        local function ready(token)
            local run=owner.run
            return current() and token and owner.active and not owner.busy and not owner.gesture and run==token.run
                and run.phase=="combat" and run.combat==token.battle and run.combat.turn==token.turn
                and dependencies.helpActorReady(token,run)
                and (token.spec.kind~="potion" or run.potions==token.spec.inventory and run.potions[token.spec.slot]==token.spec.potionId)
        end
        control:AddCursorEventListener(host.clickEvent,function(event)
            if not current() or Controller.pointerBlocked(host.controller)then return false end
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
        if not current() then return end
        if hasCursorPair("CursorDown","CursorUp") then
            control:AddCursorEventListener(host.cursor.CursorDown,function(event)
                if not current() then return false end
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
            if not current() then return end
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
            if not current() then return end
            if host.cursor.CursorEndDrag then control:AddCursorEventListener(host.cursor.CursorEndDrag,cancel) end
        end
    end

    local function bindActorHelp(screenSlot,box,entryAt,guard,cleanups)
            if guard and not guard() then return end
            if screenSlot>0 then bindHelp(box:GetChild("intentHit"),function()
                local entry=entryAt()
                return entry and {kind="intent",index=entry.index,screenSlot=screenSlot,controlBox=guard and box or nil}
            end,true,nil,guard,cleanups) end
            if guard then return end -- Dynamic monsters own one control per power, not fixed chips.
            for slot=1,L.statusIcon.perRow*L.statusIcon.rows do
                if guard and not guard() then return end
                local position=slot
                bindHelp(box:GetChild("statusRow"):GetChild("hit"..slot),function()
                    local index,actor
                    if guard then
                        local entry=entryAt();index=entry and entry.index;actor=entry and entry.actor
                    else
                        local _;_,index,actor=statusActorAt(screenSlot)
                    end
                    if not Actors.isPresent(actor)then return end
                    local entries=Combat.statusView(actor)
                    local perRow=L.statusIcon.perRow
                    local slots=perRow*L.statusIcon.rows
                    if not entries[position] then return end
                    local overflow=position==slots and #entries>=slots
                    return {index=index,screenSlot=screenSlot>0 and screenSlot or nil,controlBox=guard and box or nil,statusId=not overflow and entries[position].id or nil,
                        offset=overflow and position or nil}
                end,true,nil,guard,cleanups)
            end
        end

    local function bindDetailControls()
        -- Enemy portraits keep targeting; the hero portrait and every status row only open
        -- details, so a status tap never plays a card or moves the potion target.
        dependencies.listen(dependencies.child("hero"):GetChild("hit"), function() owner:showStatus(0) end)
        local names=host.monsterSurfaces and {"hero"} or {"hero", "enemy1", "enemy2", "enemy3", "enemy4", "enemy5"}
        for i, name in ipairs(names) do
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
        info:GetChild("page"):AddCursorEventListener(host.clickEvent,function(event)
            if Controller.pointerBlocked(host.controller)then return false end
            local swallow=owner.swallow
            if swallow and swallow.touch==(event and event.touchId) then owner.swallow=nil;return end
            return infoPage()
        end)
        if host.cursor and host.cursor.CursorDown then
            info:GetChild("page"):AddCursorEventListener(host.cursor.CursorDown,function() owner.swallow=nil end)
        end
        Controller.bind(host.controller,info:GetChild("page"),"battleInfo",infoPage,nil,1)
        bindActorHelp(0,dependencies.child("hero"),function()end)
        if not host.monsterSurfaces then
            for i=1,5 do
                local slot=i
                bindActorHelp(slot,dependencies.child("enemy"..slot),function()return dependencies.enemyAt(slot)end)
            end
        end
        for slot=1,10 do
            local index=slot
            bindHelp(dependencies.child("card"..slot):GetChild("hit"),function() return owner:cardHelpSpec(index) end,false,slot)
        end
        for slot=1,L.battlePotions.count do
            local index=slot
            bindHelp(dependencies.child("potionHelp"..slot),function() return owner:potionHelpSpec(index) end,false)
            bindHelp(dependencies.child("potion"..slot),function() return owner:potionHelpSpec(index) end,false)
        end
    end
    local bound=setmetatable({}, {__mode="k"})
    local function bindEnemyDetailControls(screenSlot,box)
        -- A preceding native registration may synchronously retire this surface.
        if host.monsterSurfaces and host.monsterSurfaces:control(screenSlot)~=box then return end
        if bound[box] then return end
        local manager=assert(host.monsterSurfaces,"dynamic monster surfaces required")
        local captured=assert(manager:entry(screenSlot),"dynamic enemy must be published before binding")
        local actorId=captured.id
        local run,battle=owner.run,owner.run and owner.run.combat
        local binding={controls={}};bound[box]=binding
        local function entryAt()
            if binding.retired or box.alive==false or host.monsterSurfaces~=manager or manager:control(screenSlot)~=box
                or owner.run~=run or not run or run.combat~=battle then return end
            local entry=manager:entry(screenSlot)
            local current=entry and battle.enemies[entry.index]
            if entry and entry.id==actorId and current and current.id==actorId then return entry end
        end
        local function guard()return entryAt()~=nil end
        bindActorHelp(screenSlot,box,entryAt,guard,binding.controls)
    end
    local function unbindEnemyDetailControls(_screenSlot,box,engineDestroyed)
        local binding=bound[box]
        if not binding then return end
        binding.retired=true
        for _,item in ipairs(binding.controls)do
            if item.cancel then item.cancel(true,engineDestroyed) end
            Controller.unbind(host.controller,item.control,engineDestroyed)
        end
        bound[box]=nil
    end
    local powerBindings=setmetatable({}, {__mode="k"})
    local function bindEnemyPowerControl(actorSlot,powerSlot,powerBox,powerManager)
        if powerBindings[powerBox] or powerManager:control(powerSlot)~=powerBox then return end
        local manager=host.monsterSurfaces
        local actorBox=manager and manager:control(actorSlot)
        local actorEntry=manager and manager:entry(actorSlot)
        local powerEntry=powerManager:entry(powerSlot)
        if not actorBox or not actorEntry or not powerEntry then return end
        local actorId,powerId=actorEntry.id,powerEntry.id
        local run,battle=owner.run,owner.run and owner.run.combat
        local binding={controls={}};powerBindings[powerBox]=binding
        local function surfaceCurrent()
            return not (binding.retired or powerBox.alive==false or actorBox.alive==false
                or host.monsterSurfaces~=manager or manager:control(actorSlot)~=actorBox
                or owner.run~=run or not run or run.combat~=battle
                or powerManager:control(powerSlot)~=powerBox)
        end
        local function describe()
            if not surfaceCurrent() then return end
            local entry=manager:entry(actorSlot)
            local power=powerManager:entry(powerSlot)
            local actor=entry and battle and battle.enemies[entry.index]
            if not entry or entry.id~=actorId or not actor or actor.id~=actorId
                or not Actors.isPresent(actor) or not power or power.id~=powerId then return end
            -- Resolve by power identity, never the row position or a feedback snapshot.
            for _,status in ipairs(Combat.statusView(actor))do
                if status.id==powerId then
                    return {index=entry.index,screenSlot=actorSlot,controlBox=actorBox,statusId=powerId}
                end
            end
        end
        bindHelp(powerBox:GetChild("hit"),describe,true,nil,function()return describe()~=nil end,binding.controls)
    end
    local function unbindEnemyPowerControl(powerBox,engineDestroyed)
        local binding=powerBindings[powerBox]
        if not binding then return end
        binding.retired=true
        for _,item in ipairs(binding.controls)do
            if item.cancel then item.cancel(true,engineDestroyed) end
            Controller.unbind(host.controller,item.control,engineDestroyed)
        end
        powerBindings[powerBox]=nil
    end
    return {
        statusActorAt=statusActorAt, bindDetailControls=bindDetailControls,
        bindEnemyPowerControl=bindEnemyPowerControl, unbindEnemyPowerControl=unbindEnemyPowerControl,
        bindEnemyDetailControls=bindEnemyDetailControls, unbindEnemyDetailControls=unbindEnemyDetailControls
    }
end
return M
