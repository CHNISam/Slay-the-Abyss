-- Source hook construction only. Combat owns the single queue and transaction.
local Actors=require('abyss_actor')
local Schedule=require('abyss_power_schedule')
local OrbPowers=require('abyss_orb_powers')
local Strength=require('abyss_warrior_strength_cards')
local Status=require('abyss_warrior_status_cards')
local Flow=require('abyss_watcher_flow_cards')
local Tactics=require('abyss_silent_tactics_cards')
local Mantra=require('abyss_mantra')
local Events=require('abyss_events')
local M={}
local MAX=2147483647
M.phases={
    turn_start={nightmare=true,phantasmal=true,hello_world=true,creative_ai=true,magnetism=true,mayhem=true,berserk=true,infinite_blades=true,bias=true,loop=true,flame_barrier=true,
        next_turn_block=true,battle_hymn=true,energy_down=true,wrath_next_turn=true,end_turn_death=true,foresight=true},
    energy_recharge={energized=true,energized_blue=true,collect=true,deva_form=true},
    turn_start_post_draw={tools_of_the_trade=true,demon_form=true,noxious_fumes=true,devotion=true,brutality=true,
        draw_next_turn=true,draw_card_next_turn=true},
}
M.scheduledIds={}
for _,filter in pairs(M.phases)do for id in pairs(filter)do M.scheduledIds[id]=true end end
local function integer(n)
    return type(n)=='number' and n==n and n%1==0 and n>=0 and n<=MAX
end
local function live(state)
    assert(type(state)=='table' and type(state.player)=='table' and type(state.player.statuses)=='table','missing turn Power state')
    if not Actors.isActive(state.player) or state.phase=='victory' or state.phase=='defeat' then return false end
    for _,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then return true end end
    return false
end
local function action(effect,id)
    return {kind='effect',effect=effect,turnPower=id}
end
local function add(out,effect,id)
    if effect.kind=='effect' then
        effect.turnPower=effect.turnPower or id;out[#out+1]=effect
    else out[#out+1]=action(effect,id)end
end
local function append(out,effects,id)
    for _,effect in ipairs(effects)do add(out,effect,id)end
end
local function bottom(out,plan,id)
    assert(not plan.top or #plan.top==0,'unsupported TOP turn Power plan')
    append(out,plan.bottom or {},id)
end
local function ordered(state,phase)
    local filter=M.phases[phase]
    -- Only the legacy pair has a retained source ordering record. It supplies
    -- no ordering relationship to any unrelated manually installed Power.
    if phase=='turn_start' and state.orbPowerOrder then
        local onlyOrbs,missingGeneric=true,true
        for id in pairs(state.player.statuses)do
            if filter[id] and id~='loop' and id~='bias' then onlyOrbs=false end
        end
        for _,entry in ipairs(state.player.powerScheduleOrder or {})do
            if filter[entry.id]then missingGeneric=false end
        end
        if onlyOrbs and missingGeneric then
            local out,seen={},{}
            local size=0
            for key in pairs(state.orbPowerOrder)do
                assert(integer(key) and key>=1,'invalid legacy orb Power index');size=size+1
            end
            for i=1,size do assert(rawget(state.orbPowerOrder,i)~=nil,'sparse legacy orb Power order')end
            for _,id in ipairs(state.orbPowerOrder)do
                assert((id=='loop' or id=='bias') and not seen[id],'invalid legacy orb Power order')
                seen[id]=true
                if rawget(state.player.statuses,id)~=nil then
                    local definition=assert(state.player.statusDefinitions[id],'missing legacy orb Power definition')
                    assert(definition.priority==nil or definition.priority==5,'unsupported legacy orb priority')
                    out[#out+1]={id=id,amount=state.player.statuses[id]}
                end
            end
            for _,id in ipairs({'loop','bias'})do
                assert(rawget(state.player.statuses,id)==nil or seen[id],'unknown legacy Loop/Bias acquisition order')
            end
            if #out>0 then return out end
        end
    end
    return Schedule.list(state,filter)
end
local function amount(entry)
    assert(integer(entry.amount),'invalid turn Power amount: '..entry.id)
    return entry.amount
end

function M.prepareStart(state)
    local out={}
    if not live(state)then return out end
    for _,entry in ipairs(ordered(state,'turn_start'))do
        local id,n=entry.id,amount(entry)
        if id=='nightmare'or id=='phantasmal'then add(out,{op='silentFinal',kind='startPower',status=id,value=n},id)
        elseif id=='loop' or id=='bias' then append(out,OrbPowers.prepareStart(state,id),id)
        elseif id=='berserk' then
            if n==0 then add(out,{op='energy',value=0},id)
            else bottom(out,Strength.planHook(state,id,'turn_start'),id)end
        elseif id=='magnetism' or id=='mayhem' then
            add(out,{op='colorless',kind=id=='magnetism' and 'generateColorless' or 'mayhem',value=n},id)
        elseif id=='hello_world'or id=='creative_ai'then
            append(out,require('abyss_defect_final_cards').turnStartActions(state,id,n),id)
        elseif id=='infinite_blades' then
            add(out,{op='makeTempCard',cardId='shiv',pile='hand',upgraded=false,value=n},id)
        elseif id=='flame_barrier' then
            if n==0 then add(out,{op='removeStatusPower',status=id,value=0},id)
            else bottom(out,Status.planHook(state,id,'turn_start'),id)end
        elseif id=='next_turn_block' then
            add(out,{op='block',value=n,fixed=true},id)
            add(out,{op='removeStatus',status=id,value=0,targetId=state.player.id},id)
        elseif id=='foresight' then add(out,{op='scry',value=n},id)
        elseif id=='end_turn_death' then
            add(out,{op='loseHp',value=99999},id)
            add(out,{op='removeStatus',status=id,value=0},id)
        elseif n>0 then bottom(out,Flow.planHook(state,id,'turn_start'),id)
        elseif id=='battle_hymn' then add(out,{op='makeTempCard',cardId='smite',pile='hand',upgraded=false,value=0},id)
        elseif id=='energy_down' then add(out,{op='loseEnergy',value=0},id)
        elseif id=='wrath_next_turn' then
            add(out,{op='changeStance',stance='Wrath'},id)
            add(out,{op='removeFlowPower',status=id,value=1},id)
        end
    end
    -- Ordinary orb onStartOfTurn is a separate source loop after ALL Powers.
    if state.orbs then append(out,OrbPowers.prepareStart(state,'orbs'),'ordinary_orbs')end
    return out
end

-- Called after base recharge, before adding the ordinary Draw action. Only
-- Energized changes energy immediately; returned Remove/Collect actions wait.
function M.onEnergyRecharge(state)
    local out={}
    if not live(state)then return out end
    for _,entry in ipairs(ordered(state,'energy_recharge'))do
        local id,n=entry.id,amount(entry)
        if id=='energized' or id=='energized_blue' then
            assert(n<=999 and integer(state.energy) and state.energy<=MAX-n,'turn energy overflow')
            state.energy=state.energy+n
            Events.emit(state,'next_turn_energy',{amount=n,status=id})
            add(out,{op='removeStatus',status=id,value=0,targetId=state.player.id},id)
        elseif id=='deva_form' then
            assert(integer(state.devaEnergyGain) and state.energy<=MAX-state.devaEnergyGain,'Deva energy overflow')
            state.energy=state.energy+state.devaEnergyGain
            assert(state.devaEnergyGain<=MAX-n,'Deva growth overflow')
            state.devaEnergyGain=state.devaEnergyGain+n
        elseif n>0 then bottom(out,Flow.planHook(state,id,'energy_recharge'),id)
        else
            -- Source Collect has no positive-amount guard: even zero makes
            -- one Miracle+ and then follows amount<=1's Remove branch.
            add(out,{op='makeTempCard',cardId='miracle',pile='hand',upgraded=true,value=1},id)
            add(out,{op='removeFlowPower',status=id,value=1},id)
        end
    end
    return out
end

-- Construct after ordinary Draw is queued but before it executes. Devotion's
-- Mantra constructor accounting happens here, never in the execution handler.
function M.preparePostDraw(state)
    local out={}
    if not live(state)then return out end
    for _,entry in ipairs(ordered(state,'turn_start_post_draw'))do
        local id,n=entry.id,amount(entry)
        if id=='tools_of_the_trade'then add(out,{op='draw',value=n},id);add(out,{op='requestDiscard',value=n},id)
        elseif id=='demon_form' then add(out,{op='gainStatus',status='strength',value=n},id)
        elseif id=='noxious_fumes' then
            for _,enemy in ipairs(state.enemies)do
                if Actors.isActive(enemy) and not enemy.isDead and not enemy.isDying then
                    local a=action({op='turnPoison',targetId=enemy.id,value=n,newPowerAmount=math.min(9999,n)},id)
                    a.triggerPower=id;out[#out+1]=a
                end
            end
        elseif id=='devotion' then
            if state.player.statuses.mantra==nil and n>=10 then add(out,{op='changeStance',stance='Divinity'},id)
            else add(out,Mantra.prepareGain(state,n),id)end
        elseif id=='brutality' then
            if n==0 then
                add(out,{op='draw',value=0},id);add(out,{op='loseHp',value=0},id)
            else bottom(out,Strength.planHook(state,id,'turn_start_post_draw'),id)end
        elseif id=='draw_next_turn' then append(out,Tactics.planHook(state,id,'turn_start_post_draw'),id)
        elseif n>0 then bottom(out,Flow.planHook(state,id,'turn_start_post_draw'),id)
        else
            add(out,{op='draw',value=0},id);add(out,{op='removeFlowPower',status=id,value=1},id)
        end
    end
    return out
end
return M
