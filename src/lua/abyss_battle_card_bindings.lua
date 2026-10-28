-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local CardInput = require("abyss_card_input")
local RewardOwner = require("abyss_battle_reward_owner")
local Controller = require("abyss_controller")
local M = {}
local L = Theme.layout
-- Only this responsibility owns these closures; cross-responsibility calls are explicit ports.
function M.install(owner, ownership, host, dependencies)
    local function cardToken(slot, input, event)
        local run, battle = owner.run, owner.run.combat
        local instance = run.phase == "combat" and battle.hand[slot]
        local uid = instance and instance.uid or run.phase == "reward" and Run.rewardOptions(run)[slot]
        if not uid then return end
        local g = {uid=uid,slot=slot,run=run,battle=battle,turn=battle and battle.turn,
            phase=run.phase,touch=event and event.touchId,input=input}
        RewardOwner.capture(g, owner, run)
        return g, instance, battle
    end
    local function beginCardDrag(g, instance, battle, event)
        local x, y = dependencies.point(event)
        if not instance or not x then return end
        local ok, reason = Combat.canPlay(battle, instance.uid, nil)
        if not ok and reason ~= "invalid_target" then return end
        g.sx, g.sy, g.x, g.y, g.origin = x, y, x, y, owner.cardPositions[instance.uid]
        CardInput.begin(g, Theme.canvas.base[2], host.platform.touchScreen and host.platform.touchScreen(), Theme.canvas.base[1])
        g.handCancelY = L.hand.y + Theme.motion.hoverLift
        owner.hover, owner.handHover = nil, nil
        owner.carry = nil
        owner.gesture = g
    end
    local function bindCardControls()
        for i = 1, 10 do
            local slot,hit = i,dependencies.child("card" .. i):GetChild("hit")
            local input = {}
            ownership.cardInputs[i] = input
            Controller.bind(host.controller,hit,"battle",function()
                owner.suppressClick=false;owner:playSlot(slot);return true
            end,dependencies.controllerReady,slot,"hand",function()owner:setHover(slot)end)
            if host.controller and host.controller.api.events.LostFocus then
                hit:AddNavigationEventListener(host.controller.api.events.LostFocus,function()
                    if owner.hover==slot then owner:setHover(nil)end
                end)
            end
            dependencies.listen(hit,function() owner:playSlot(slot) end,input)
            if owner.dragEnabled then
                hit:AddCursorEventListener(host.cursor.CursorDown,function(event)
                    ownership.pointerObserved = true
                    dependencies.retireInterruptedPress(event)
                    if owner.gesture then return end
                    local dismissed = dependencies.down(event)
                    input.held, input.released = nil, nil
                    if dismissed or not owner.active or owner.busy or not owner.run then return end
                    local g, instance, battle = cardToken(slot, input, event)
                    if not g then return end
                    input.held = g
                    dependencies.cancelPotionAim("已取消药水瞄准。")
                    owner:queueHelp(owner:cardHelpSpec(slot),hit,true,event and event.touchId,g)
                    beginCardDrag(g, instance, battle, event)
                end)
                hit:AddCursorEventListener(host.cursor.CursorDrag,function(event) dependencies.move(event,input) end)
                hit:AddCursorEventListener(host.cursor.CursorUp,function(event) dependencies.release(event,input) end)
                hit:AddCursorEventListener(host.cursor.CursorEndDrag,function(event) dependencies.release(event,input,true) end)
            end
        end
        if owner.dragEnabled then
            local layer = dependencies.child("dragLayer")
            layer.disableCursorEventPassthrough = true
            local hit = layer:GetChild("hit")
            -- Do not replay this press onto whatever was under the old drag.
            -- Retire its capture only; a subsequent deliberate click owns input.
            hit:AddCursorEventListener(host.cursor.CursorDown,dependencies.retireInterruptedPress)
            hit:AddCursorEventListener(host.cursor.CursorDrag,dependencies.move)
            hit:AddCursorEventListener(host.cursor.CursorUp,dependencies.release)
            hit:AddCursorEventListener(host.cursor.CursorEndDrag,function(event) dependencies.release(event,nil,true) end)
        end
    end
    return {cardToken=cardToken, beginCardDrag=beginCardDrag, bindCardControls=bindCardControls}
end
return M
