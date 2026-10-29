-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Controller = require("abyss_controller")
local M = {}
local function needsTarget(state, instance)
    -- Ask the core to validate the same card with and without a target.
    local _, reason = Combat.canPlay(state, instance.uid, nil)
    return reason == "invalid_target"
end
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, ownership, host, dependencies)
    local function bindEnemyControls()
        for i = 1, 5 do
            local screenSlot, control, input = i, dependencies.child("enemy" .. i):GetChild("hit"), {}
            ownership.enemyInputs[i] = input
            local function chooseEnemy()
            local entry=dependencies.enemyAt(screenSlot)
            if not entry then return false end
            local target=entry.index
            if owner.potionAim then
                local slot = owner.potionAim.slot
                owner.target = target
                return owner:commitPotion(slot, target)
            end
            if owner.active and owner.run and not owner.busy and owner.run.phase == "combat" and owner.run.combat.enemies[target] and Actors.isActive(owner.run.combat.enemies[target]) then
                owner.target = target
                local selected
                for _, instance in ipairs(owner.run.combat.hand) do
                    if instance.uid == owner.selected then selected = instance break end
                end
                if selected and needsTarget(owner.run.combat, selected) then owner:playSelected(target)
                else
                    owner:showStatus(target)
                end
            end
            end
            Controller.bind(host.controller,control,function()
                local selected
                if owner.run and owner.run.combat then
                    for _,card in ipairs(owner.run.combat.hand)do if card.uid==owner.selected then selected=card end end
                end
                return (owner.potionAim or selected and needsTarget(owner.run.combat,selected)) and "aim" or "battle"
            end,function()owner.suppressClick=false;return chooseEnemy()end,function()
                local entry=dependencies.enemyAt(screenSlot)
                return dependencies.controllerReady() and owner.run.phase=="combat" and entry and Actors.isActive(entry.actor)
            end,screenSlot,"enemies",function()
                local entry=dependencies.enemyAt(screenSlot)
                if entry then owner.target=entry.index;owner:render()end
            end)
            control:AddCursorEventListener(host.clickEvent, function(event)
                if Controller.pointerBlocked(host.controller)then return false end
                if dependencies.swallowed(event) then
                    -- Dismissal consumes this pointer too, but cannot consume a
                    -- newer token owned by a different touch on the same actor.
                    dependencies.discardEnemyPointer(input,event)
                    return
                end
                if ownership.enemyPointerObserved then
                    -- Existing enemy hosts may send Down/Click without Up. Both
                    -- forms consume the same actor-bound, one-shot ownership.
                    local released = input.released or input.held
                    if not released or released.touch ~= (event and event.touchId) then return end
                    input.held, input.released = nil, nil
                    if not dependencies.enemyReady(released) then return end
                end
                if not dependencies.consumeReleasedDragClick(event) and not owner.suppressClick and not owner.gesture then return chooseEnemy() end
            end)
            if owner.dragEnabled then
                control:AddCursorEventListener(host.cursor.CursorDown, function(event)
                    ownership.enemyPointerObserved = true
                    local dismissed = dependencies.down(event)
                    input.held, input.released = nil, nil
                    if dismissed then return end
                    local run, battle = owner.run, owner.run and owner.run.combat
                    local entry=dependencies.enemyAt(screenSlot,battle)
                    local actor=entry and entry.actor
                    if not actor then return end
                    local g = {slot=entry.index,screenSlot=screenSlot, actor=actor, run=run, battle=battle,
                        uid=owner.selected, selectionEpoch=owner.selectionEpoch,aim=owner.potionAim,
                        turn=battle.turn, touch=event and event.touchId}
                    if dependencies.enemyReady(g) then input.held = g end
                end)
                local function releaseEnemy(event, ended)
                    ownership.enemyPointerObserved = true
                    local touch, held = event and event.touchId, input.held
                    if held and held.touch == touch then
                        input.held = nil
                        input.released = not ended and dependencies.enemyReady(held) and held or nil
                        if ended and dependencies.cancelPotionAim("已取消药水瞄准。") then owner:render() end
                    elseif ended and input.released and input.released.touch == touch then
                        input.released = nil
                        if dependencies.cancelPotionAim("已取消药水瞄准。") then owner:render() end
                    end
                end
                control:AddCursorEventListener(host.cursor.CursorUp, releaseEnemy)
                control:AddCursorEventListener(host.cursor.CursorEndDrag, function(event) releaseEnemy(event, true) end)
            end
        end
    end
    local function helpActorReady(token,run)
        local spec=token.spec
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        return actor==token.actor and Actors.isPresent(token.actor)
            and (not spec.screenSlot or dependencies.sameEnemySlot(spec.screenSlot,token.actor,run.combat))
    end
    return {
        bindEnemyControls=bindEnemyControls, helpActorReady=helpActorReady
    }
end
return M
