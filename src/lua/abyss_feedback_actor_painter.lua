local MonsterArt=require('abyss_monster_art')
-- Composes committed actor feedback into native portrait/effect controls only.
-- Queue timing, completion and battle ownership remain with abyss_feedback.
local Theme = require("abyss_theme")
local ActorMotion = require("abyss_actor_motion")
local SkillFeedback = require("abyss_skill_feedback")
local M = {}
local T,C,L,S = Theme.motion,Theme.color,Theme.layout,Theme.space
local OVERSHOOT,FLASH = 1/3,0.85
local function clamp(x) return x < 0 and 0 or x > 1 and 1 or x end
local function easeOut(x) x=clamp(x) return 1-(1-x)*(1-x) end
local function easeIn(x) x=clamp(x) return x*x end
local function hurts(kind) return kind=="damage" or kind=="hp_loss" or kind=="status_damage" end
local function mix(a,b,w) return {r=a.r+(b.r-a.r)*w,g=a.g+(b.g-a.g)*w,b=a.b+(b.b-a.b)*w,a=a.a} end
local function colour(ctx,c,alpha) return ctx.platform.color(c.r,c.g,c.b,math.floor((c.a or 255)*(alpha or 1))) end
local function tint(ctx,box,c,alpha) box.imageColor=colour(ctx,c,alpha) end
-- Piecewise pose: {time, x, scale} keys with smooth in/out between them.
local function pose(keys, age)
    if age >= keys[#keys][1] then return keys[#keys][2], keys[#keys][3], true end
    for i = 2, #keys do
        local a, b = keys[i - 1], keys[i]
        if age < b[1] then
            local p = b[1] > a[1] and (age - a[1]) / (b[1] - a[1]) or 1
            p = p * p * (3 - 2 * p)
            return a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p, false
        end
    end
end

-- Per-actor composition: attacker pose + victim knockback/flash + death collapse, applied once.
local function appendShake(id,sample,shakes)
    local age,d,style,heavy=sample.age,sample.detail,sample.style,sample.heavy
    if id == "player" or heavy or style.lethal then
        local scale = math.min(1, ((d.amount or 0) + (d.blocked or 0)) / T.heavyHitDamage)
        local amplitude = T.shakeAmplitude * (id == "player" and (scale + 1) / 2 or scale / 2)
        if age < T.shake then shakes[#shakes + 1] = amplitude * (1 - age / T.shake) * math.sin(age / T.shake * math.pi * 4) end
    end
end
local function paintKnockback(effect,sample,x,y)
    local age,d,style,kind=sample.age,sample.detail,sample.style,sample.kind
    local after,frozen,lost,heavy=sample.after,sample.frozen,sample.lost,sample.heavy
    -- Knockback snaps out on contact, holds through the hit-stop, then eases home.
    if lost and kind == "damage" then
        local reach = heavy and S.l or style.form == "area" and S.s or S.m
        local out = frozen and 1 or 1 - easeOut(after / T.base)
        x = x + effect.dir * reach * out
        if style.form == "multi" then y = y + (style.hit % 2 == 0 and S.xs or -S.xs) * out end
    elseif lost and style.form == "dot" and d.status ~= "poison" then
        x = x + effect.dir * S.xs * (1 - easeOut(age / T.fast))
    end
    return x,y
end
local function paintMotion(id,effect,sample,shakes,x,y,ink,flash)
    local age,kind=sample.age,sample.kind
    local after,frozen,lost=sample.after,sample.frozen,sample.lost
    x,y=paintKnockback(effect,sample,x,y)
    if lost then
        flash = frozen and 1 or math.max(0, 1 - after / T.fast)
        ink = kind == "damage" and (id == "player" and C.danger or C.goldBright) or kind == "hp_loss" and C.danger or C.debuff
        appendShake(id,sample,shakes)
    elseif kind == "status" or kind == "heal" then
        flash = math.max(0, 1 - age / T.fast) / 2
        ink = effect.ink
    end
    return x,y,ink,flash
end
local function impactShape(effect,sample,e)
    local age,style,kind,heavy=sample.age,sample.style,sample.kind,sample.heavy
    local ix, iy
    local iy0 = 0
    if effect.icon then
        local stamp = kind == "status" and 1 + (1 - easeOut(age / T.fast)) * OVERSHOOT * 2 or 1 - OVERSHOOT + e * OVERSHOOT
        ix, iy = stamp, stamp
        if kind == "status" then iy0 = (effect.ink == C.buff and 1 or -1) * S.m * easeOut((age - T.fast) / (T.slow - T.fast)) end
    elseif heavy then ix, iy = 1 + e, 1 + e
    elseif style.form == "area" then ix, iy = 1.5 + e / 2, 0.2
    elseif style.form == "multi" and style.hit % 2 == 0 then ix, iy = 0.3 * (1 - e) + 0.1, 1.2 + e / 2
    else ix, iy = 1.2 + e / 2, 0.3 * (1 - e) + 0.1 end
    return ix,iy,iy0
end
local function impactTint(id,effect,sample,e)
    local kind,age=sample.kind,sample.age
    local shardInk = effect.icon and effect.ink or id == "player" and C.text or C.geo
    local alpha=(effect.icon and kind == "status" and math.min(1, 2 - 2 * easeIn(age / T.slow)) or 1 - e)
    return shardInk,alpha
end
local function skillImpact(effect,sample,e)
    local family,form=effect.style.family,effect.style.form
    if not effect.icon and family~='none'
        and ((form~='multi' and form~='area')or(family~='melee' and family~='heavy'))then
        return SkillFeedback.sample(family,e,S.m)
    end
    local ix,iy,iy0=impactShape(effect,sample,e)
    return ix,iy,0,iy0
end
local function paintImpact(ctx,id,impact,effect,sample)
    local age,kind=sample.age,sample.kind
    local after,frozen,lost,heavy=sample.after,sample.frozen,sample.lost,sample.heavy
    -- Geo shard: one diamond image, shaped by non-uniform scale per attack form.
    local window = effect.icon and T.slow or heavy and T.base or T.fast
    local e = frozen and 0 or easeOut(after / window)
    local show = (lost or kind == "status") and age < effect.stop + window
    impact:SetVisible(show)
    if show then
        local ix,iy,offset,iy0,alpha,key=skillImpact(effect,sample,e)
        impact:SetLocalScale(ix, iy, 1)
        impact:SetAnchoredPosition(offset or 0, iy0)
        local shardInk,shardAlpha=impactTint(id,effect,sample,e)
        tint(ctx,impact,key and C[key] or shardInk,alpha or shardAlpha)
    end
    return window
end
local function paintShield(ctx,box,shield,sample)
    local age,kind,d=sample.age,sample.kind,sample.detail
    local lost=sample.lost
    -- Shield: crystallises in on gain, shudders when it holds, shatters when it breaks.
    local blocked = (d.blocked or 0) > 0
    local guard = kind == "block" or blocked
    shield:SetVisible(guard and age < T.slow)
    if guard and age < T.slow then
        local scale, wobble = 1, 0
        local fade
        if kind == "block" then
            scale = 1 + (1 - easeOut(age / T.fast)) * OVERSHOOT
            fade = age < T.fast and easeOut(age / T.fast) or 1 - easeIn((age - T.fast) / (T.slow - T.fast))
        elseif lost then
            scale, fade = 1 + easeOut(age / T.fast) / 2, math.max(0, 1 - age / T.fast)
        else
            wobble = S.xs * math.sin(age / T.fast * math.pi * 3) * math.max(0, 1 - age / T.fast)
            fade = 1 - easeIn(age / T.slow)
        end
        shield:SetLocalScale(scale, scale, 1) shield:SetAnchoredPosition(wobble, 0)
        tint(ctx,shield, C.block, fade)
        local pop = 1 + (1 - easeOut(age / T.base)) * OVERSHOOT
        -- Keep the badge inside its reserved horizontal lane beside HP and neighbouring units.
        for _, part in ipairs({"blockEdge", "blockIcon", "block"}) do box:GetChild(part):SetLocalScale(1, pop, 1) end
    end
end
local function numberScale(sample)
    local heavy,lost,frozen,after=sample.heavy,sample.lost,sample.frozen,sample.after
    local peak = heavy and lost and 2 or lost and 1.5 or 1.25
    local scale = frozen and peak or 1 + (peak - 1) * (1 - easeOut(after / T.fast))
    return scale
end
local function paintNumber(ctx,id,box,effect,sample,window)
    local age,style=sample.age,sample.style
    -- Number: pops on contact, holds through the hit-stop, settles, rises and fades.
    local p = clamp(age / T.damagePop)
    local floating = box:GetChild("floating")
    floating:SetVisible(p < 1)
    local drift = style.form == "multi" and (style.hit % 2 == 1 and -S.m or S.m) or 0
    floating:SetAnchoredPosition(drift, L.enemyRow.portrait / 2 + S.xl * easeOut(p))
    floating.fontColor = colour(ctx,effect.ink, p < 0.5 and 1 or 2 - 2 * p)
    local scale=numberScale(sample)
    floating:SetLocalScale(scale, scale, 1)
    local ghost = clamp((age - T.hpGhostDelay) / T.hpGhost)
    box:GetChild("hpGhost").fillAmount = effect.oldHp + (effect.hp - effect.oldHp) * ghost
    if age >= math.max(T.damagePop, T.hpGhostDelay + T.hpGhost, effect.stop + window) then
        ctx.state.effects[id] = nil
        for _, part in ipairs({"blockEdge", "blockIcon", "block"}) do box:GetChild(part):SetLocalScale(1, 1, 1) end
        box:GetChild("impact"):SetLocalScale(1, 1, 1)
    end
end
local function paintDying(ctx,id,box,dt,y,sx,sy,ink,flash,alpha)
    local dying = ctx.state.dying[id]
    if dying then
        -- Gleam, then the figure crumbles into the ground as a shard burst disperses.
        dying.age = dying.age + dt
        local p = clamp(dying.age / T.slow)
        ink, flash, alpha = id == "player" and C.danger or C.goldBright, 1 - easeOut(p), 1 - easeIn(p)
        sx, sy = sx * (1 + p * OVERSHOOT), sy * (1 - easeIn(p) / 2)
        y = y - S.m * easeIn(p)
        local impact = box:GetChild("impact")
        impact:SetVisible(p < 1) impact:SetAnchoredPosition(0, 0)
        impact:SetLocalScale(1 + easeOut(p), 1 + easeOut(p), 1)
        tint(ctx,impact, id == "player" and C.danger or C.geo, (1 - p) * 0.8)
        box:SetVisible(p < 1)
        if p >= 1 then ctx.state.dying[id] = nil end
    end
    return y,sx,sy,ink,flash,alpha
end
function M.paint(ctx,id, dt, shakes)
    local unit, box = ctx.actor(id)
    if not box then ctx.state.effects[id], ctx.state.poses[id], ctx.state.dying[id] = nil, nil, nil return end
    local base = id == "player" and C.geo or C.text
    local ink, flash, alpha = base, 0, 1
    local posed = ctx.state.poses[id]
    local motionState=ActorMotion.state(unit,posed,ctx.state.effects[id],ctx.state.dying[id],ctx.state.escaping[id])
    local x,y,sx,sy=ActorMotion.idle(unit,id,ctx.state.idleClock or 0,motionState,T.actorIdle)
    if posed then
        posed.age = posed.age + dt
        local px, ps, done = pose(posed.keys, posed.age)
        if motionState=='action' then x, sx, sy = px, ps, ps end
        if done then ctx.state.poses[id] = nil end
    end
    local effect = ctx.state.effects[id]
    if effect then
        effect.age = effect.age + dt
        local sample={age=effect.age,detail=effect.detail,style=effect.style,kind=effect.kind,
            after=math.max(0,effect.age-effect.stop),frozen=effect.age<effect.stop,
            lost=hurts(effect.kind) and (effect.detail.amount or 0)>0,heavy=effect.style.weight=='heavy'}
        local impact,shield=box:GetChild('impact'),box:GetChild('shield')
        x,y,ink,flash=paintMotion(id,effect,sample,shakes,x,y,ink,flash)
        local window=paintImpact(ctx,id,impact,effect,sample)
        paintShield(ctx,box,shield,sample)
        paintNumber(ctx,id,box,effect,sample,window)
    end
    y,sx,sy,ink,flash,alpha=paintDying(ctx,id,box,dt,y,sx,sy,ink,flash,alpha)
    local portrait = box:GetChild("portrait")
    portrait:SetAnchoredPosition(x, y)
    portrait:SetLocalScale(sx, sy, 1)
    if id == "player" and ctx.platform.portraits then ctx.platform.portraits:battlePose(x,y,sx,sy) end
    local tone=flash > 0 and mix(base,ink,flash*FLASH) or base
    tint(ctx,portrait,tone,alpha)
    MonsterArt.pose(box,x,y,sx,sy,tone,alpha)
end
return M
