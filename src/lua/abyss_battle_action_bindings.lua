-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Theme = require("abyss_theme")
local RewardOwner = require("abyss_battle_reward_owner")
local Controller = require("abyss_controller")
local M = {}
local L = Theme.layout
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, ownership, host, dependencies)
    local D = L.cardDrag
    local function listen(control, fn, input)
        if host.controller and not input then
            Controller.bind(host.controller,control,control.parent.name=="statusInfo" and "battleInfo" or "battle",fn,
                function()return owner.active and not owner.busy end)
        end
        control:AddCursorEventListener(host.clickEvent,function(event)
            if Controller.pointerBlocked(host.controller)then return false end
            if dependencies.swallowed(event) then return end
            if input and ownership.pointerObserved then
                local released = input.released
                -- Never borrow a foreign or missing touch ID, nor fall back to
                -- click-only after this controller has observed pointer input.
                if not released or released.touch ~= (event and event.touchId) then return end
                input.released = nil -- a valid matching click can be consumed only once
                if not dependencies.cardReady(released) then return end
            end
            if not owner.suppressClick and not owner.gesture then return fn(event) end
        end)
        if owner.dragEnabled and not input then control:AddCursorEventListener(host.cursor.CursorDown,dependencies.down) end
    end
    local function actionToken(name, event)
        local run = owner.run
        local battle = run and run.combat
        local g = {name = name, run = run, phase = run and run.phase,
            uid = owner.selected, selectionEpoch = owner.selectionEpoch,
            battle = battle, turn = battle and battle.turn, touch = event and event.touchId}
        RewardOwner.capture(g, owner, run)
        if name == "playArea" and battle then
            g.aim = owner.potionAim
            g.x, g.y, g.invalidPoint = dependencies.point(event)
            for i, instance in ipairs(battle.hand) do if instance.uid == owner.selected then g.slot = i break end end
        end
        return g
    end
    local function fieldReleaseValid(name, held, event)
        local x, y, invalidPoint = dependencies.point(event)
        return name ~= "playArea" or not invalidPoint and (not x or dependencies.inPlayArea(x, y)
            and (not held.x or (x-held.x)^2+(y-held.y)^2 < D.threshold^2))
    end
    local function bind(name, fn)
        local control, input = dependencies.child(name), {}
        if name == "playArea" then control = control:GetChild("hit") end
        ownership.actionInputs[#ownership.actionInputs + 1] = input
        Controller.bind(host.controller,control,name=="playArea" and "aim" or "battle",function()
            owner.suppressClick=false;return fn()
        end,function()
            if not dependencies.controllerReady()then return false end
            if name~="playArea"then return true end
            if owner.potionAim or not owner.selected or owner.run.phase~="combat"then return false end
            for _,card in ipairs(owner.run.combat.hand)do
                if card.uid==owner.selected then return not needsTarget(owner.run.combat,card)end
            end
            return false
        end,name=="endTurn" and 90 or 50)
        control:AddCursorEventListener(host.clickEvent, function(event)
            if Controller.pointerBlocked(host.controller)then return false end
            if dependencies.swallowed(event) then return end
            if name == "playArea" and ownership.fieldPointerObserved or name ~= "playArea" and ownership.actionPointerObserved then
                local released = input.released
                if not released or released.touch ~= (event and event.touchId) then return end
                input.released = nil
                if not dependencies.actionReady(released) then return end
            end
            if not owner.suppressClick and not owner.gesture then return fn(event) end
        end)
        if owner.dragEnabled then
            control:AddCursorEventListener(host.cursor.CursorDown, function(event)
                if name == "playArea" then ownership.fieldPointerObserved = true else ownership.actionPointerObserved = true end
                local dismissed = dependencies.down(event)
                input.held, input.released = nil, nil
                if dismissed then return end
                local g = actionToken(name, event)
                if not g.invalidPoint and dependencies.actionReady(g) then input.held = g end
            end)
            local function releaseAction(event, ended)
                local touch, held = event and event.touchId, input.held
                if held and held.touch == touch then
                    input.held = nil
                    local fieldValid = fieldReleaseValid(name, held, event)
                    input.released = not ended and fieldValid and dependencies.actionReady(held) and held or nil
                elseif ended and input.released and input.released.touch == touch then
                    input.released = nil
                end
            end
            control:AddCursorEventListener(host.cursor.CursorUp, releaseAction)
            control:AddCursorEventListener(host.cursor.CursorEndDrag, function(event) releaseAction(event, true) end)
            if name == "playArea" then
                control:AddCursorEventListener(host.cursor.CursorDrag, function(event)
                    local held = input.held
                    if not held or held.touch ~= (event and event.touchId) then return end
                    local x,y = dependencies.point(event)
                    if not x or not held.x or (x-held.x)^2+(y-held.y)^2 >= D.threshold^2 then
                        input.held, input.released = nil, nil
                    end
                end)
            end
        end
    end
    return {
        listen=listen, actionToken=actionToken, fieldReleaseValid=fieldReleaseValid, bind=bind
    }
end
return M
