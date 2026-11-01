-- Presentation vocabulary over committed events. No rule writes, RNG or controls.
-- Source mechanisms and adaptation boundaries: docs/research/battle-life-effects.md.
local M = {}
local families={melee=true,heavy=true,projectile=true,poison=true,bind=true,buff=true,defend=true,dot=true}
-- Exact definition + intent pairs; identical intent names on other actors do not match.
local moves={
    sentry={sentry_1='projectile'}, red_slaver={red_slaver_2='bind'},
    chosen={zap='projectile',debilitate='heavy',hex='bind',drain='bind'},
    snake_plant={spores='poison'}, collector={fireball='projectile',mega_debuff='bind'},
    automaton={hyper_beam='projectile'}, bronze_orb={beam='projectile',stasis='bind'},
    gremlin_nob={gremlin_nob_3='heavy'}, champ={heavy_slash='heavy',execute='heavy'},
    acid_slime_s={acid_slime_s_2='poison'}, acid_slime_m={acid_slime_m_2='poison'},
    acid_slime_l={acid_slime_l_2='poison'},
}
local function clamp(p) return math.max(0,math.min(1,p)) end
local function smooth(p) return p*p*p*(p*(p*6-15)+10) end
local function effectsFamily(effects)
    local block,buff,debuff=false,false,false
    for _,effect in ipairs(effects or {}) do
        local op=effect.op
        if op=='damage' or op=='damageAll' or op=='damageEqualToBlock' or op=='enemyVampireDamage' then return 'melee' end
        block=block or op=='block'
        buff=buff or op=='gainStatus' or op=='enemyHealAll' or op=='enemyStrengthAll'
        debuff=debuff or op=='applyStatus' or op=='applyStatusAll'
    end
    return block and 'defend' or buff and 'buff' or debuff and 'bind' or 'none'
end
function M.resolve(kind,detail,context)
    local d,c=detail or {},context or {}
    if kind=='status_damage' or kind=='hp_loss' then return d.status=='poison' and 'poison' or 'dot' end
    if kind=='block' then return 'defend' end
    if kind=='heal' then return 'buff' end
    if families[d.effectType] then return d.effectType end
    if kind=='status' then
        if d.status=='poison' or c.family=='poison' then return 'poison' end
        return c.statusKind=='buff' and 'buff' or 'bind'
    end
    local byEnemy=moves[c.enemyId]
    local family=byEnemy and byEnemy[c.intentId] or c.family or effectsFamily(c.effects)
    if family=='none' then
        family=c.intentKind=='attack' and 'melee' or c.intentKind=='defend' and 'defend'
            or (c.intentKind=='buff' or c.intentKind=='charge') and 'buff'
            or c.intentKind=='debuff' and 'bind' or 'none'
    end
    if kind=='damage' then
        if family~='projectile' and family~='poison' and family~='heavy' then family='melee' end
        if c.weight=='heavy' and family=='melee' then family='heavy' end
    end
    return family
end

-- Returns sx,sy,x,y,alpha,themeColourKey. Contact always begins at the victim;
-- travel belongs to the preceding play/intent interval, never after HP changes.
function M.sample(family,progress,span)
    local p=clamp(progress); local q=1-p; local s=span or 0
    if family=='heavy' then return 1+2*smooth(p),1+2*smooth(p),0,-s*p*p,q*q,'geo' end
    if family=='projectile' then return 2+2*p,0.18+0.12*q,0,0,q*q,'block' end
    if family=='poison' then return 0.7+p,0.8+0.6*p,0,s*p,q*q,'positive' end
    if family=='bind' then return 1.8-0.8*smooth(p),0.45+0.55*smooth(p),0,0,q,'debuff' end
    if family=='buff' then return 0.6+0.6*p,1+0.8*p,0,s*smooth(p),q*q,'buff' end
    if family=='defend' then return 1.2+0.3*p,1.2+0.3*p,0,0,q,'block' end
    if family=='dot' then return 0.6+0.2*p,0.6+0.2*p,0,s*p*0.5,q*q*q,'danger' end
    return 1.2+0.5*p,0.4-0.3*p,0,0,q^5,'geo'
end

-- Quintic acceleration for the cast, smooth travel for a projectile. At p=1
-- hide the travelling control before revealing its separate contact feedback.
function M.travel(family,progress,sourceX,sourceY,targetX,targetY)
    local p=clamp(progress)
    local t=family=='bind' and p^5 or smooth(p)
    return sourceX+(targetX-sourceX)*t,sourceY+(targetY-sourceY)*t,p<1 and 1 or 0
end

-- Existing official audio keys only. Call instead of the old contact/status
-- selector, never in addition; group/multi-hit dedup remains the queue owner's job.
function M.cue(family,kind,detail)
    local d=detail or {}
    if kind=='damage' then
        if (d.amount or 0)>0 then return family=='heavy' and 'hit_heavy' or 'hit' end
        if (d.blocked or 0)>0 then return 'block_hit' end
    elseif kind=='status' then return 'status'
    elseif kind=='block' then return 'block_gain'
    elseif kind=='heal' and (d.amount or 0)>0 then return 'heal' end
end
return M
