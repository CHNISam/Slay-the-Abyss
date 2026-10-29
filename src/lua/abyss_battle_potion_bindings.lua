-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Theme = require("abyss_theme")
local Controller = require("abyss_controller")
local Run = require("abyss_run")
local M = {}
local L = Theme.layout
local D = L.cardDrag
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
    local function potionMotionOwner(event,input)
        local held
        if input then held=input.held
        elseif owner.potionAim and owner.potionAim.input then held=owner.potionAim.input.held end
        if not held or held.helpOnly or held.touch~=(event and event.touchId) or input and input~=held.input then return end
        return held
    end
    local function potionMotionPoint(held,event)
        local x,y=dependencies.point(event);if not x or not held.sx then return end
        if not held.aim and owner.help and owner.help.fired then return end
        if not held.aim and (x-held.sx)^2+(y-held.sy)^2<D.threshold^2 then return end
        return x,y
    end
    local function prepareMovingPotion(held)
        local item=Run.potionView(owner.run)[held.slot]
        if not item or not item.canUse or item.targetPolicy~='enemy_one' then return false end
        if not held.aim then
            owner.help,owner.info=nil,nil
            dependencies.beginPotionAim({slot=held.slot,id=held.id},item)
            held.aim=owner.potionAim
            held.aim.moving,held.aim.touch,held.aim.input=true,held.touch,held.input
            held.aim.origin=held.origin
        end
        return owner.potionAim==held.aim
    end
    local function movePotion(event,input)
        local held=potionMotionOwner(event,input)
        if not held then return end
        if not dependencies.potionReady(held) then dependencies.cancelPotionAim();held.input.held=nil;owner:render();return end
        local x,y=potionMotionPoint(held,event)
        if not x or not prepareMovingPotion(held) then return end
        held.aim.x,held.aim.y=x,y
        owner.suppressClick=true;owner:render()
    end
    local function releasePotionDrag(event,input)
        local aim=owner.potionAim
        if not aim or not aim.moving or aim.touch~=(event and event.touchId) or input and input~=aim.input then return end
        movePotion(event,input)
        if owner.potionAim~=aim then return end
        local valid,target=dependencies.potionDragTarget(aim)
        -- A drag release must itself carry a valid point. Missing/NaN input
        -- must not reuse an earlier valid enemy position and spend a bottle.
        local x=dependencies.point(event);valid=valid and x~=nil
        aim.input.released=nil;aim.input.consumed={touch=aim.touch}
        if valid then owner.suppressClick=false;return owner:commitPotion(aim.slot,target) end
        dependencies.cancelPotionAim('已取消药水瞄准。');owner.suppressClick=true;dependencies.refresh();return false
    end
    local function potionPressToken(slot,input,event,helpOnly)
        local binding=dependencies.potionBinding(slot)
        if not binding then return end
        local run=owner.run
        local g={slot=binding.slot,id=binding.id,inventory=run.potions,
            run=run,battle=run.combat,turn=run.combat and run.combat.turn,
            touch=event and event.touchId,input=input,helpOnly=helpOnly}
        g.sx,g.sy=dependencies.point(event)
        local offset=helpOnly and L.battlePotions.helpOffset or {0,0}
        g.origin={L.battlePotions.origin[1]+L.battlePotions.step[1]*(slot-1)+offset[1],
            L.battlePotions.origin[2]+L.battlePotions.step[2]*(slot-1)+offset[2]}
        return g
    end
    local function beginPotionPress(slot,control,input,event,helpOnly)
        if owner.potionAim and owner.potionAim.moving and owner.potionAim.touch~=(event and event.touchId) then return end
        ownership.potionPointerObserved=true
        local dismissed=dependencies.down(event)
        input.held,input.released,input.consumed=nil,nil,nil
        if dismissed or owner.gesture or not owner.run then return end
        local g=potionPressToken(slot,input,event,helpOnly)
        if g and dependencies.potionReady(g) then
            input.held=g
            owner:queueHelp(owner:potionHelpSpec(slot),control,true,g.touch)
        end
    end
    local function releasePotionHelp(control,input,touch)
        if not owner.help or owner.help.source~=control then return end
        if owner.help.fired then
            input.released=nil
            input.consumed={touch=touch}
            if owner.info then owner.info.transient=false;owner:render() end
        end
        owner.help=nil
    end
    local function bindPotionControls()
        for i = 1, L.battlePotions.count do
          for _,helpOnly in ipairs({false,true})do
            local slot, control, input = i, dependencies.child((helpOnly and 'potionHelp' or 'potion') .. i), {}
            ownership.potionInputs[#ownership.potionInputs+1] = input
            Controller.bind(host.controller,control,"battle",function()
                if helpOnly then return owner:openHelp(owner:potionHelpSpec(slot),control,false) end
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
                if not owner.suppressClick and not owner.gesture then
                    if helpOnly then return owner:openHelp(owner:potionHelpSpec(slot),control,false) end
                    return owner:openPotionMenu(slot)
                end
            end)
            if owner.dragEnabled then
                control:AddCursorEventListener(host.cursor.CursorDown, function(event)
                    beginPotionPress(slot,control,input,event,helpOnly)
                end)
                control:AddCursorEventListener(host.cursor.CursorDrag,function(event)
                    if not helpOnly then return movePotion(event,input) end
                end)
                local function releasePotion(event, ended)
                    if owner.potionAim and owner.potionAim.moving then return releasePotionDrag(event,input) end
                    local touch, held = event and event.touchId, input.held
                    if held and held.touch == touch then
                        input.held = nil
                        input.released = not ended and dependencies.potionReady(held) and held or nil
                        releasePotionHelp(control,input,touch)
                    elseif ended and input.released and input.released.touch == touch then
                        input.released = nil
                    end
                end
                control:AddCursorEventListener(host.cursor.CursorUp, releasePotion)
                control:AddCursorEventListener(host.cursor.CursorEndDrag, function(event) releasePotion(event, true) end)
            end
          end
        end
    end
    return {
        bindPotionControls=bindPotionControls,movePotion=movePotion,releasePotionDrag=releasePotionDrag
    }
end
return M
