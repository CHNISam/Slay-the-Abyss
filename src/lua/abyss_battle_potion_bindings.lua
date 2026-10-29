-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Theme = require("abyss_theme")
local Controller = require("abyss_controller")
local M = {}
local L = Theme.layout
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, ownership, host, dependencies)
    function owner.openPotionMenu(_,slot)
        if not owner.active or owner.busy or owner.gesture or owner.suppressClick or not owner.run
            or owner.run.phase~="combat" or owner.run.combat.phase~="player" then return false end
        if not dependencies.potionBinding(slot)then return false end
        dependencies.cancelPotionAim();dependencies.cancelCardInputs();dependencies.cancelActionInputs()
        owner.selected,owner.carry,owner.help,owner.info=nil,nil,nil,nil
        local opened=host.potionPopup:open(slot)
        if opened then host.stage:GetChild('potionHelp'):SetAsLastSibling();dependencies.refresh()end
        return opened
    end
    local function bindPotionControls()
        for i = 1, L.battlePotions.count do
            local slot, control, input = i, dependencies.child("potion" .. i), {}
            ownership.potionInputs[i] = input
            Controller.bind(host.controller,control,"battle",function()
                owner.suppressClick=false;return owner:openPotionMenu(slot)
            end,dependencies.controllerReady,30+slot,"potions")
            control:AddCursorEventListener(host.clickEvent, function(event)
                if Controller.pointerBlocked(host.controller)then return false end
                if input.consumed and input.consumed.touch == (event and event.touchId) then input.consumed=nil return end
                if dependencies.swallowed(event) then return end
                if ownership.potionPointerObserved then
                    local released = input.released
                    if not released or released.touch ~= (event and event.touchId) then return end
                    input.released = nil
                    if not dependencies.potionReady(released) then return end
                end
                if not owner.suppressClick and not owner.gesture then return owner:openPotionMenu(slot) end
            end)
            if owner.dragEnabled then
                control:AddCursorEventListener(host.cursor.CursorDown, function(event)
                    ownership.potionPointerObserved = true
                    local dismissed = dependencies.down(event)
                    input.held, input.released, input.consumed = nil, nil, nil
                    if dismissed or owner.gesture or not owner.run then return end
                    local run, binding = owner.run, owner.potionSlots and owner.potionSlots[slot]
                    if not binding or owner.potionRun ~= run or owner.potionBattle ~= run.combat then return end
                    local g = {slot = binding.slot, id = binding.id, inventory = run.potions,
                        run = run, battle = run.combat, turn = run.combat and run.combat.turn,
                        touch = event and event.touchId}
                    if dependencies.potionReady(g) then input.held = g; owner:queueHelp(owner:potionHelpSpec(slot),control,true,g.touch) end
                end)
                local function releasePotion(event, ended)
                    local touch, held = event and event.touchId, input.held
                    if held and held.touch == touch then
                        input.held = nil
                        input.released = not ended and dependencies.potionReady(held) and held or nil
                        if owner.help and owner.help.source == control then
                            if owner.help.fired then
                                input.released = nil
                                input.consumed = {touch=touch}
                                if owner.info then owner.info.transient=false; owner:render() end
                            end
                            owner.help = nil
                        end
                    elseif ended and input.released and input.released.touch == touch then
                        input.released = nil
                    end
                end
                control:AddCursorEventListener(host.cursor.CursorUp, releasePotion)
                control:AddCursorEventListener(host.cursor.CursorEndDrag, function(event) releasePotion(event, true) end)
            end
        end
    end
    return {
        bindPotionControls=bindPotionControls
    }
end
return M
