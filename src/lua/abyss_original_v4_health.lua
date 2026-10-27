-- Original heroes share one actual-HP ledger per combat. Traveler paths stay native.
local Events=require('abyss_events')
local M={}
function M.hpEvent(state,amount)
    local v=state.originalV4
    if not v or v.role~='FR' or amount<=0 then return end
    local r=state.originalV4Rules.FR
    local gained=math.max(0,math.min(amount,r.fanfare_per_actual_hp_event_cap,r.fanfare_per_turn_cap-v.fanGained,r.fanfare_max-v.fan))
    if gained>0 then
        v.fan=v.fan+gained;v.fanGained=v.fanGained+gained
        Events.emit(state,'original_v4_resource',{resource='fan',amount=gained,value=v.fan})
    end
end
function M.heal(state,actor,requested,category,origin)
    local v=state.originalV4
    assert(v and actor==state.player,'original healing needs its combat owner')
    if actor.hp<=0 or v.role=='AR' and category~='burst' or require('abyss_potion_health').blocked(state.relics) then return 0 end
    local amount=math.max(0,math.min(math.floor(requested),actor.maxHp-actor.hp,state.originalV4Rules.common.battle_actual_heal_cap-v.healUsed))
    if amount==0 then return 0 end
    local before=actor.hp;actor.hp=actor.hp+amount;v.healUsed=v.healUsed+amount
    Events.emit(state,'heal',{target=actor.id,amount=amount,origin=origin or 'original_v4'})
    M.hpEvent(state,amount)
    require('abyss_relic_hooks').hpChanged(state,actor,before)
    return amount
end
return M
