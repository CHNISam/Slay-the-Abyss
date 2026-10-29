-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local M = {}
local C, L = Theme.color, Theme.layout
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, ownership, host, dependencies)
    local closeInfo
    local function endTurnFace(part,state)
        local fill=state=='disabled' and C.panelSunken or L.endTurn.faceColour
        for _,name in ipairs({'plate','plateLeft','plateRight'})do dependencies.tint(part:GetChild(name),fill)end
        dependencies.ink(part:GetChild('label'),state=='disabled' and C.textMuted or L.endTurn.textColour)
    end
    local function button(name, enabled, primary, caption)
        local box = dependencies.child(name)
        box.interactable,box.raycastTarget = enabled == true,enabled == true
        for _, state in ipairs({"normal", "hover", "pressed", "disabled"}) do
            local part = box:GetChild(state)
            if caption then part:GetChild("label").text = caption end
            if name=='endTurn' then
                endTurnFace(part,state)
            elseif state == "normal" or state == "hover" then
                dependencies.tint(part:GetChild("plate"), primary and (state == "hover" and C.goldBright or C.geo) or C.panelRaised)
                dependencies.ink(part:GetChild("label"), primary and C.textOnLight or C.goldBright)
            end
        end
    end
    function owner:resize(width, height)
        local cancelled = dependencies.cancelPotionAim("已取消药水瞄准。") or self.gesture ~= nil or self.carry ~= nil
        dependencies.cancelCardInputs()
        dependencies.cancelPotionInputs()
        dependencies.cancelActionInputs()
        for _, input in ipairs(ownership.enemyInputs) do input.held, input.released = nil, nil end
        if cancelled then self.gesture, self.carry, self.selected, self.suppressClick = nil, nil, nil, true end
        if closeInfo() then cancelled = true end
        self.canvasWidth, self.canvasHeight = width, height
        local k = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        dependencies.child("dragLayer"):GetChild("hit"):SetSizeDelta(width/k,height/k)
        if not host.options.embedded then -- The host owns the single canvas scale.
            host.stage:SetLocalScale(k, k, 1)
            host.root:GetChild("backdrop"):SetSizeDelta(width, height)
        end
        if cancelled then self:render() end
    end
    local function describeInfo(battle, info, actor)
        return host.infoContent(owner.data, owner.presentation, battle, info, actor)
    end
    closeInfo = function()
        if host.potionPopup and host.potionPopup:close() then return true end
        if not owner.info then return false end
        owner.info = nil
        dependencies.child("statusInfo"):SetVisible(false)
        return true
    end
    function owner:showStatus(index)
        local run = self.run
        if not self.active or self.busy or self.gesture or not run or run.phase ~= "combat" then return false end
        local actor = index == 0 and run.combat.player or run.combat.enemies[index]
        if not Actors.isPresent(actor) then return false end
        dependencies.cancelPotionAim("已取消药水瞄准。")
        if self.info and self.info.index == index and self.info.id == actor.id then closeInfo()
        else self.info = {index = index, id = actor.id, battle = run.combat} end
        self:render()
        return true
    end
    function owner:openHelp(spec, source, transient)
        local run=self.run
        if not self.active or self.busy or not run or run.phase~="combat" then return false end
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        if not Actors.isPresent(actor)then return false end
        dependencies.cancelPotionAim("已取消药水瞄准。")
        self.info={index=spec.index,id=actor.id,battle=run.combat,kind=spec.kind,statusId=spec.statusId,
            offset=spec.offset,uid=spec.uid,source=source,transient=transient==true,
            slot=spec.slot,potionId=spec.potionId,inventory=spec.inventory}
        self:render()
        return self.info~=nil
    end
    function owner:queueHelp(spec,source,held,touch,card)
        local run=self.run
        if not spec or not self.active or self.busy or not run or run.phase~="combat" then return end
        local actor=spec.index==0 and run.combat.player or run.combat.enemies[spec.index]
        if not Actors.isPresent(actor)then return end
        self.help={spec=spec,source=source,held=held,touch=touch,t=0,run=run,battle=run.combat,
            turn=run.combat.turn,actor=actor,card=card}
    end
    function owner:cardHelpSpec(slot)
        local battle=self.run and self.run.phase=="combat" and self.run.combat
        local instance=battle and battle.hand[slot]
        if not instance then return end
        local card=Combat.cardDefinition(battle,instance)
        local function hasKeyword(effects)
            for _,effect in ipairs(effects) do
                if effect.status or effect.op=="gainTemporaryStrength" or effect["then"] and hasKeyword(effect["then"]) then return true end
            end
        end
        if card.exhaust or card.ethereal or hasKeyword(card.effects) then return {kind="card",index=0,uid=instance.uid} end
    end
    function owner:potionHelpSpec(slot)
        local run = self.run
        if not run or run.phase ~= "combat" or not run.potions[slot] or slot>Run.potionCapacity(run) then return end
        return {kind="potion",index=0,slot=slot,potionId=run.potions[slot],inventory=run.potions}
    end
    return {
        button=button, describeInfo=describeInfo, closeInfo=closeInfo, endTurnFace=endTurnFace
    }
end
return M
