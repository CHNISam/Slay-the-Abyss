-- Fixed-source Silent attack/defence subset. Shared Combat owns action order.
local Actors, Events = require("abyss_actor"), require("abyss_events")
local M = {}
local MAX = 2147483647
local names={bane="毒性追击",slice="快切",sucker_punch="虚弱打击",poisoned_stab="淬毒刺击",
    riddle_with_holes="五连刺",backstab="先手背刺",adrenaline="肾上腺素",deflect="偏折",
    caltrops="铁蒺藜",flying_knee="飞膝",outmaneuver="迂回蓄势",dodge_and_roll="闪避翻滚",
    grand_finale="华丽收场",heel_hook="勾踢"}
local function integer(n)
    return type(n)=="number" and n==n and n%1==0 and n>=0 and n<=MAX
end
local function conditional(status, effects)
    return {op="conditional",["if"]="target_"..status,["then"]=effects}
end
function M.withCardDefinitions(data)
    local d=require("abyss_combat").copy(data)
    local cards={
        {id="bane",sourceId="Bane",type="attack",rarity="common",cost=1,
            effects={{op="damage",value=7},conditional("poison",{{op="damage",value=7}})},
            upgrade={effects={{op="damage",value=10},conditional("poison",{{op="damage",value=10}})}}},
        {id="slice",sourceId="Slice",type="attack",rarity="common",cost=0,
            effects={{op="damage",value=6}},upgrade={effects={{op="damage",value=9}}}},
        {id="sucker_punch",sourceId="Sucker Punch",type="attack",rarity="common",cost=1,
            effects={{op="damage",value=7},{op="applyStatus",status="weak",value=1}},
            upgrade={effects={{op="damage",value=9},{op="applyStatus",status="weak",value=2}}}},
        {id="poisoned_stab",sourceId="Poisoned Stab",type="attack",rarity="common",cost=1,
            effects={{op="damage",value=6},{op="applyStatus",status="poison",value=3}},
            upgrade={effects={{op="damage",value=8},{op="applyStatus",status="poison",value=4}}}},
        {id="riddle_with_holes",sourceId="Riddle With Holes",type="attack",rarity="uncommon",cost=2,
            effects={{op="damage",value=3,times=5}},upgrade={effects={{op="damage",value=4,times=5}}}},
        {id="backstab",sourceId="Backstab",type="attack",rarity="uncommon",cost=0,innate=true,exhaust=true,
            effects={{op="damage",value=11}},upgrade={effects={{op="damage",value=15}}}},
        {id="adrenaline",sourceId="Adrenaline",type="skill",rarity="rare",cost=0,exhaust=true,
            effects={{op="energy",value=1},{op="draw",value=2}},
            upgrade={effects={{op="energy",value=2},{op="draw",value=2}}}},
        {id="deflect",sourceId="Deflect",type="skill",rarity="common",cost=0,
            effects={{op="block",value=4}},upgrade={effects={{op="block",value=7}}}},
        {id="caltrops",sourceId="Caltrops",type="power",rarity="uncommon",cost=1,
            effects={{op="gainStatus",status="thorns",value=3}},
            upgrade={effects={{op="gainStatus",status="thorns",value=5}}}},
        {id="flying_knee",sourceId="Flying Knee",type="attack",rarity="common",cost=1,
            effects={{op="damage",value=8},{op="nextEnergy",value=1}},
            upgrade={effects={{op="damage",value=11},{op="nextEnergy",value=1}}}},
        {id="outmaneuver",sourceId="Outmaneuver",type="skill",rarity="common",cost=1,
            effects={{op="nextEnergy",value=2}},upgrade={effects={{op="nextEnergy",value=3}}}},
        {id="dodge_and_roll",sourceId="Dodge and Roll",type="skill",rarity="common",cost=1,
            effects={{op="block",value=4},{op="nextBlock",value=4}},
            upgrade={effects={{op="block",value=6},{op="nextBlock",value=6}}}},
        {id="grand_finale",sourceId="Grand Finale",type="attack",rarity="rare",cost=0,condition="draw_pile_empty",experimental=true,
            effects={{op="damageAll",value=50}},upgrade={effects={{op="damageAll",value=60}}}},
        {id="heel_hook",sourceId="Heel Hook",type="attack",rarity="uncommon",cost=1,
            effects={{op="heelHook",value=5}},upgrade={effects={{op="heelHook",value=8}}}},
    }
    local present={};for _,c in ipairs(d.cards.cards)do present[c.id]=true end
    for _,c in ipairs(cards)do
        if not present[c.id]then
            c.name=assert(names[c.id]);c.sts_name=c.sourceId
            d.cards.cards[#d.cards.cards+1]=c
        end
    end
    local statuses={};for _,s in ipairs(d.statuses.statuses)do statuses[s.id]=true end
    for _,id in ipairs({"energized","next_turn_block"})do
        if not statuses[id]then
            d.statuses.statuses[#d.statuses.statuses+1]={id=id,name=id=="energized"and"下回合能量"or"下回合格挡",
                kind="buff",stack="intensity",decay="none",
                description=id=="energized"and"下一回合补充能量时，额外获得等同层数的能量，随后移除。"
                    or"下一回合开始时，获得等同层数的格挡，随后移除。"}
        end
    end
    return d
end

function M.applyNextEnergy(state,value)
    assert(integer(value),"invalid next-turn energy")
    local before=state.player.statuses.energized or 0
    assert(integer(before)and before<=999,"invalid Energized amount")
    assert(before+0.0+value<=MAX,"unsupported Energized integer overflow")
    -- This subset has no onApplyPower observer: state-equivalent capped delta.
    local delta=math.min(value,999-before)
    return Actors.applyPower(state,state.player,"energized",delta,state.player)
end
function M.applyNextBlock(state,amount)
    -- The caller passes this.block snapshotted when the card is used, already
    -- modified by Dexterity/Frail. Do not apply those modifiers a second time.
    assert(integer(amount),"invalid next-turn block")
    local before=state.player.statuses.next_turn_block or 0
    assert(integer(before)and before+0.0+amount<=MAX,"next-turn block overflow")
    return Actors.applyPower(state,state.player,"next_turn_block",amount,state.player)
end
function M.onEnergyRecharge(state)
    local amount=state.player.statuses.energized
    if amount==nil or not Actors.isActive(state.player)then return false end
    assert(integer(amount)and amount<=999,"invalid Energized amount")
    assert(integer(state.energy)and state.energy<=MAX-amount,"next-turn energy overflow")
    state.energy=state.energy+amount
    Events.emit(state,"next_turn_energy",{amount=amount})
    -- Source queues removal at BOTTOM; caller removes it after the pre-draw
    -- Power actions and before ordinary draw. Do not erase the Power here.
    return true
end
function M.removeNextEnergy(state)
    local amount=state.player.statuses.energized
    if amount==nil then return false end
    assert(integer(amount),"invalid Energized amount")
    require('abyss_power_schedule').remove(state,state.player,'energized')
    state.player.statuses.energized=nil
    Events.emit(state,"status",{source=state.player.id,target=state.player.id,status="energized",amount=-amount})
    return true
end
function M.preDrawBlock(state,api)
    local amount=state.player.statuses.next_turn_block
    if amount==nil or not Actors.isActive(state.player)then return false end
    assert(integer(amount),"invalid next-turn block")
    assert(api and type(api.block)=="function","missing shared block API")
    api.block(state,state.player,amount,true)
    require('abyss_power_schedule').remove(state,state.player,'next_turn_block')
    state.player.statuses.next_turn_block=nil
    Events.emit(state,"status",{source=state.player.id,target=state.player.id,status="next_turn_block",amount=-amount})
    return true
end
return M
