-- Fixed-source Blood/Fruit health arithmetic shared by battle and room use.
local f32=require('abyss_sts_random').float32
local M={}
function M.modifyHealing(healing,relics,inCombat)
    for _,id in ipairs(relics or {}) do
        if id=='mark_of_bloom' then healing=0
        elseif id=='magic_flower' and inCombat then healing=math.floor(f32(f32(healing)*1.5)+0.5) end
    end
    return healing
end
function M.apply(actor,op,value,relics,inCombat)
    if op~='healPercent' and op~='increaseMaxHp' then return false,'unsupported_health_effect' end
    if type(value)~='number' or value<0 or value%1~=0 or value>2147483647 then return false,'invalid_effect_value' end
    local maximum=actor.maxHp
    if op=='increaseMaxHp' then
        maximum=maximum+0.0+value
        if maximum>2147483647 then return false,'effect_overflow' end
    end
    local healing=op=='healPercent' and math.floor(f32(f32(actor.maxHp)*f32(f32(value)/100))) or value
    healing=M.modifyHealing(healing,relics,inCombat)
    local before=actor.hp
    actor.maxHp,actor.hp=maximum,math.min(maximum,actor.hp+0.0+healing)
    return true,actor.hp-before
end
return M
