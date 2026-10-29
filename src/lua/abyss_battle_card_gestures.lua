-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Theme = require("abyss_theme")
local CardInput = require("abyss_card_input")
local M = {}
local L = Theme.layout
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, ownership, host, dependencies)
    local updateCarry
    local function point(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local x,y = event:GetUIPos()
        -- Keep unavailable coordinates compatible, but let field taps reject explicit bad numbers.
        if type(x) == "number" and (x ~= x or math.abs(x) == math.huge)
            or type(y) == "number" and (y ~= y or math.abs(y) == math.huge) then return nil,nil,true end
        if type(x) ~= "number" or type(y) ~= "number" then return end
        local width,height = owner.canvasWidth or Theme.canvas.base[1],owner.canvasHeight or Theme.canvas.base[2]
        local k = math.min(width/Theme.canvas.base[1],height/Theme.canvas.base[2])
        return (x-width/2)/k,(y-height/2)/k
    end
    local function retireInterruptedPress(event)
        local potion=owner.potionAim
        if potion and potion.moving and potion.touch==(event and event.touchId) then
            dependencies.cancelPotionAim();dependencies.cancelPotionInputs();owner.suppressClick=true;owner:render();return true
        end
        local g = owner.gesture
        if not g or g.touch ~= (event and event.touchId) then return false end
        -- Another Down from the same pointer starts a new physical sequence.
        -- Its previous Up may have been lost outside the native hit surface.
        -- A different touch must never steal a live drag.
        g.input.held, g.input.released = nil, nil
        owner.gesture, owner.carry, owner.selected = nil, nil, nil
        owner.hover, owner.handHover, owner.help = nil, nil, nil
        owner.suppressClick = true
        if g.moving then host.cardView.renderDrag() end
        return true
    end
    local function down(event)
        if owner.potionAim and owner.potionAim.moving and owner.potionAim.touch~=(event and event.touchId) then return true end
        retireInterruptedPress(event)
        ownership.pointerObserved = true
        owner.help=nil
        if owner.active and not owner.busy and not owner.gesture and event and event.touchId == ownership.releasedDragTouch then
            ownership.releasedDragTouch = nil -- a new physical sequence owns this touch again
        end
        if not owner.gesture then owner.suppressClick = false end
        owner.swallow = nil
        if owner.gesture or not dependencies.closeInfo() then return false end
        owner.swallow = {touch = event and event.touchId}
        owner:render()
        return true
    end
    local function swallowed(event)
        local swallow = owner.swallow
        if swallow and swallow.touch == (event and event.touchId) then owner.swallow = nil return true end
        if not dependencies.closeInfo() then return false end -- click-only hosts dismiss on the click itself
        owner:render()
        return true
    end
    local function renderCardMotion(g)
        owner.suppressClick,owner.selected = true,g.uid
        local valid, target, aiming = dependencies.dragTarget(g)
        if g.cancelled then
            g.input.held, g.input.released = nil, nil
            ownership.releasedDragTouch = g.touch
            owner.gesture, owner.selected, owner.hover, owner.handHover, owner.suppressClick = nil, nil, nil, nil, g
            owner:render(); return
        end
        if g.drawnValid ~= valid or g.drawnTarget ~= target or g.drawnAiming ~= aiming then
            owner:render()
        else host.cardView.renderDrag(valid, target, aiming, true) end
    end
    local function move(event, input)
        if owner.potionAim and owner.potionAim.moving and dependencies.movePotion then return dependencies.movePotion(event,input) end
        local g = owner.gesture
        if not g or not event or event.touchId ~= g.touch then return end
        -- A reused touch ID does not transfer ownership between card controls.
        -- The overlay may continue only the current held gesture and card UID.
        if input and input ~= g.input or g.input.held ~= g or not dependencies.cardReady(g) then return end
        local x,y = point(event)
        if not x then return end
        g.x,g.y = x,y
        if (x-g.sx)^2+(y-g.sy)^2 >= L.cardDrag.threshold^2 then g.moving = true end
        if g.moving then renderCardMotion(g) end
    end
    updateCarry = function()
        local g = owner.carry
        if not g then return end
        if not dependencies.cardReady(g) or owner.selected ~= g.uid then owner:render(); return end
        if not host.platform.cursorPosition or g.touchScreen then return end
        local x,y = point({GetUIPos=host.platform.cursorPosition})
        if not x or x == g.x and y == g.y then return end
        g.x,g.y = x,y
        local valid,target,aiming = dependencies.dragTarget(g)
        if g.cancelled then
            owner.carry,owner.selected,owner.hover,owner.handHover = nil,nil,nil,nil
            owner:render()
        elseif g.drawnValid ~= valid or g.drawnTarget ~= target or g.drawnAiming ~= aiming then
            owner:render()
        else host.cardView.renderDrag(valid,target,aiming,true) end
    end
    local function releaseCardTap(event, input, ended)
        local touch = event and event.touchId
        -- Missing/invalid coordinates disable dragging, not ordinary C-mode.
        local held = input and input.held
        if held and held.touch == touch then
            if owner.help and owner.help.card == held then owner.help = nil end
            input.held = nil
            input.released = not ended and dependencies.cardReady(held) and held or nil
        elseif ended and input and input.released and input.released.touch == touch then
            input.released = nil
        end
    end
    local function finishCardRelease(g, event, ended)
        local x = point(event)
        local valid,target = false,nil
        if x and g.moving then valid,target = dependencies.dragTarget(g) end
        owner.gesture = nil -- consume before invoking the command or any rendering callback
        if not g.moving then
            g.input.released = not ended and g or nil
            return
        end
        g.input.released = nil
        local action = x and CardInput.release(g, valid) or 'cancel'
        owner.carry = (action == 'target' or action == 'carry') and g or nil
        -- Keep the trailing Click bound to this drag, not a persistent global lock.
        ownership.releasedDragTouch = g.touch
        owner.suppressClick,owner.selected = g,action ~= 'cancel' and g.uid or nil
        owner:render()
        if action == 'play' then owner:playSelected(target)
        else dependencies.notice("") end
    end
    local function release(event, input, ended)
        if owner.potionAim and owner.potionAim.moving and dependencies.releasePotionDrag then return dependencies.releasePotionDrag(event,input) end
        local g = owner.gesture
        local touch = event and event.touchId
        if not g then releaseCardTap(event, input, ended) return end
        if touch ~= g.touch or input and input ~= g.input then return end
        if owner.help and owner.help.card == g then owner.help = nil end
        -- Stationary taps must keep their binding through Up until Click, too.
        if not dependencies.cardReady(g) then
            g.input.held = nil
            g.input.released = nil
            owner.gesture, owner.selected, owner.suppressClick = nil, nil, true
            owner:render()
            return
        end
        move(event, input)
        g.input.held = nil
        -- move/render may have cancelled a gesture belonging to an old battle.
        if owner.gesture ~= g then return end
        finishCardRelease(g, event, ended)
    end
    function owner.cancelControllerPointers(_)
        local aim=owner.potionAim
        if aim and aim.moving then ownership.releasedDragTouch=aim.touch end
        dependencies.cancelCardInputs();dependencies.cancelActionInputs();dependencies.cancelPotionInputs()
        for _,input in ipairs(ownership.enemyInputs)do input.held,input.released=nil,nil end
    end
    local function controllerReady()
        return owner.active and not owner.busy and not owner.gesture and not owner.potionMenu and owner.run
            and (owner.run.phase=="reward" or owner.run.phase=="combat" and owner.run.combat.phase=="player")
    end
    function owner.controllerBack(_)
        if dependencies.closeInfo() then owner:render();return true end
        if owner.selected or owner.potionAim then
            local movingAim=owner.potionAim and owner.potionAim.moving and owner.potionAim
            dependencies.cancelPotionAim();owner.selected,owner.carry,owner.hover=nil,nil,nil;owner.suppressClick=movingAim or false
            if movingAim then ownership.releasedDragTouch=movingAim.touch end
            owner.selectionEpoch=(owner.selectionEpoch or 0)+1
            dependencies.cancelCardInputs();dependencies.cancelActionInputs();dependencies.refresh()
            return true
        end
        if owner.run and owner.run.phase=="reward" and owner.rewardScreen=="cards" then
            dependencies.rewardScreen("list");dependencies.refresh();return true
        end
        return false
    end

    return {
        point=point, retireInterruptedPress=retireInterruptedPress, down=down, swallowed=swallowed, move=move,
        updateCarry=updateCarry, releaseCardTap=releaseCardTap, finishCardRelease=finishCardRelease, release=release, controllerReady=controllerReady
    }
end
return M
