-- Synchronous enemy operations. No continuation-queue ownership is transferred here.
local Actors=require('abyss_actor')
local Events=require('abyss_events')
local M={}
function M.awakenedVoid(context)
    require('abyss_awakened_one').void(context.state,context.source)
end
function M.enemyBurnBoth(context)
    local state=context.state
    local source=context.source
    require('abyss_act3_powers').burnBoth(state,source)
end

function M.enemyDazedDraw(context)
    local state=context.state
    local source=context.source
    require('abyss_act3_powers').dazedDraw(state,source)
end

function M.enemyStasis(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    require('abyss_act2_stasis').apply(combat,state,source)
end

function M.enemyBronzeSpawn(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    assert(source.ai and source.ai.policy=='automaton','Automaton spawn only')
    require('abyss_act2_summons').bronze(combat,state)
end

function M.enemyTorchSpawn(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local op=context.effect.op
    assert(source.ai and source.ai.policy=='collector','Collector summon only')
    require('abyss_act2_summons').torches(combat,state,source,op=='enemyTorchRevive')
end
M.enemyTorchRevive=M.enemyTorchSpawn

function M.enemyRally(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    assert(source.ai and source.ai.policy=='leader','Leader summon only')
    require('abyss_act2_summons').rally(combat,state,source)
end

function M.enemyEncourage(context)
    local state=context.state
    local source=context.source
    local value=context.effect.value
    assert(source.ai and source.ai.policy=='leader','Leader Encourage only')
    for _,ally in ipairs(state.enemies)do if Actors.isActive(ally) then
            Actors.applyPower(state,ally,'strength',value,source)
            if ally~=source then Actors.block(state,ally,6,true) end
    end end
end

function M.enemyVampireDamage(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local target=context.target
    local value=context.effect.value
    local dealt=context.dealt
    assert(source~=state.player and source.ai and source.ai.policy=='parasite','Parasite attack only')
    local reactions={}
    local lost=combat.damage(state,source,target,value,false,reactions)
    dealt=dealt+lost
    -- Vampire queues TOP Heal(lastDamageTaken) above onAttacked's
    -- reactions. The captured loss precedes Fairy's revival; a fatal
    -- non-Fairy hit opens the death screen before either queued action.
    if state.player.hp>0 then
        if lost>0 and Actors.isActive(source) then
            local healed=math.min(lost,source.maxHp-source.hp);source.hp=source.hp+healed
            Events.emit(state,'heal',{source=source.id,target=source.id,amount=healed})
        end
        Actors.resolveDamageReactions(state,reactions,combat.retaliate)
    end
    return dealt
end

function M.enemyCleanse(context)
    local state=context.state
    local source=context.source
    assert(source~=state.player and source.ai and source.ai.kind=='act2','Act2 cleanse only')
    local ids={}
    for id,n in pairs(source.statuses)do
        if source.statusDefinitions[id].kind=='debuff' or (id=='strength' or id=='dexterity' or id=='focus') and n<0 then ids[#ids+1]=id end
    end
    table.sort(ids)
    for _,id in ipairs(ids)do
        local n=source.statuses[id]
        require('abyss_power_schedule').remove(state,source,id)
        source.statuses[id]=nil
        local order={};for _,old in ipairs(source.powerOrder or {})do if old~=id then order[#order+1]=old end end
        source.powerOrder=order
        Events.emit(state,'status',{source=source.id,target=source.id,status=id,amount=-n})
    end
end

function M.enemyHealAll(context)
    local state=context.state
    local source=context.source
    local op=context.effect.op
    local value=context.effect.value
    assert(source~=state.player and source.ai and (source.ai.kind=='act2' or op=='enemyStrengthAll' and source.ai.kind=='act3_boss' and source.ai.policy=='donu'),'unsupported enemy group action')
    -- takeTurn queues one action per then-active monster reference.
    -- Resolve that fixed group, rechecking each target but not the caster.
    local recipients={}
    for _,ally in ipairs(state.enemies)do
        if Actors.isActive(ally)then recipients[#recipients+1]=ally end
    end
    for _,ally in ipairs(recipients)do
        if Actors.isActive(ally)then
            if op=='enemyHealAll' then
                local healed=math.min(value,ally.maxHp-ally.hp)
                ally.hp=ally.hp+healed
                Events.emit(state,'heal',{source=source.id,target=ally.id,amount=healed})
            else Actors.applyPower(state,ally,'strength',value,source) end
        end
    end
end
M.enemyStrengthAll=M.enemyHealAll
return M
