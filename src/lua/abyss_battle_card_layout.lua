-- Read state, issue Run commands. No damage/energy/outcome rules live in this view.
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local M = {}
local L = Theme.layout
-- Explicit ports preserve the approved implementation without a shared constructor closure.
function M.install(owner, _ownership, _host, _dependencies)
    local R = L.rewardPick
    local function placeHandHit(box, w, h, restAngle, baseY, y, scale)
        local r = restAngle * math.pi / 180
        local c,s = math.abs(math.cos(r)),math.abs(math.sin(r))
        local restH,restW = (h*c+w*s)/2,(w*c+h*s)/2
        local hotH = h*Theme.motion.hoverScale/2
        local low = math.min(baseY-restH,baseY+Theme.motion.hoverLift-hotH)
        local high = math.max(baseY+restH,baseY+Theme.motion.hoverLift+hotH)
        local dy,a = (low+high)/2-y,box.localRotationZ*math.pi/180
        local hit = box:GetChild('hit')
        -- Inverse the card transform: one world-space hit rectangle covers both poses.
        hit:SetAnchoredPosition(math.sin(a)*dy/scale,math.cos(a)*dy/scale)
        hit:SetSizeDelta(math.max(restW*2,w*Theme.motion.hoverScale)/scale,(high-low)/scale)
        hit:SetLocalScale(1,1,1)
        hit.localRotationZ = -box.localRotationZ
    end
    local function placeCard(box, count, index, selected)
        local w, h = L.card.size[1], L.card.size[2]
        local spacing = count <= 1 and 0 or math.max(L.hand.spacingMin, math.min(L.hand.spacingMax, (L.hand.maxWidth - w) / (count - 1)))
        local distance = index - (count - 1) / 2
        local angle = -distance * L.hand.arcDegrees
        local radians = math.abs(angle) * math.pi / 180
        local halfHeight = (h * math.cos(radians) + w * math.sin(radians)) / 2
        local floor = -Theme.canvas.base[2] / 2 + Theme.canvas.safe.y + halfHeight
        local baseY = math.max(floor,L.hand.y-math.abs(distance)*L.hand.arcDrop)
        local x, y = distance * spacing, baseY + (selected and Theme.motion.hoverLift or 0)
        box:SetAnchoredPosition(x, y)
        local scale = selected and Theme.motion.hoverScale or 1
        box:SetLocalScale(scale, scale, 1)
        box.localRotationZ = selected and 0 or angle
        placeHandHit(box,w,h,angle,baseY,y,scale)
        box:GetChild("glow"):SetVisible(selected)
        box:SetAsLastSibling()
        return {x, y}
    end
    local function rewardTarget(slot)
        local hot = owner.hover == slot
        return hot and R.hoverScale or R.scale, hot and R.hoverLift or 0
    end
    local function placeReward(box, count, index, anim, hot)
        local hit = box:GetChild('hit')
        hit:SetAnchoredPosition(0,0)
        hit:SetSizeDelta(L.card.size[1],L.card.size[2])
        hit:SetLocalScale(1,1,1)
        hit.localRotationZ = 0
        local x = (index - 1 - (count - 1) / 2) * R.step
        box:SetAnchoredPosition(x, R.y + anim.lift + anim.rise)
        box:SetLocalScale(anim.scale, anim.scale, 1)
        box.localRotationZ = 0
        box:GetChild("glow"):SetVisible(hot)
        -- Later siblings draw on top: neighbours first, the hovered card last.
        if not hot then box:SetAsLastSibling() end
        return {x, R.y}
    end
    local function canHover()
        return owner.active and not owner.busy and not owner.gesture and not owner.carry
    end
    function owner:setHover(slot)
        local run = self.run
        local reward = run and run.phase == 'reward' and self.rewardScreen == 'cards' and Run.rewardOptions(run)[slot]
        local hand = run and run.phase == 'combat' and run.combat.phase == 'player' and run.combat.hand[slot]
        if slot and not (canHover() and (reward or hand)) then slot,hand = nil,nil end
        if self.hover == slot then return end
        self.hover = slot
        self.handHover = hand and {run=run,battle=run.combat,turn=run.combat.turn,slot=slot,uid=hand.uid}
        self:render(true)
    end
    return {
        placeHandHit=placeHandHit, placeCard=placeCard, rewardTarget=rewardTarget, placeReward=placeReward, canHover=canHover
    }
end
return M
