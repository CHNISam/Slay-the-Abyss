-- Four opt-in retained cards. Combat owns retention phase and queued actions.
local M={}
local MAX=2147483647
local specs={
    protect={cost=2,type="skill"},
    perseverance={cost=1,type="skill",field="retainedBlockBonus",op="block",base=5,up=7,step=2,upStep=3},
    windmill_strike={cost=2,type="attack",field="retainedDamageBonus",op="damage",base=7,up=10,step=4,upStep=5},
    sands_of_time={cost=4,type="attack"},
}
local fields={"retainedBlockBonus","retainedDamageBonus","retainedCostReduction"}
local function integer(n) return type(n)=="number" and n==n and n%1==0 and n>=0 and n<=MAX end
local function copy(x)
    if type(x)~="table" then return x end
    local y={};for k,v in pairs(x) do y[k]=copy(v) end;return y
end
local function value(instance,field)
    local n=instance[field] or 0
    assert(integer(n),"invalid retained instance field: "..field)
    return n
end
local function effective(state,instance)
    local card=copy(assert(state.catalog.cards[instance.cardId],"unknown retained card"))
    assert(instance.upgraded==nil or type(instance.upgraded)=="boolean","invalid retained upgrade")
    if instance.upgraded then for k,v in pairs(card.upgrade or {}) do card[k]=copy(v) end end
    return card
end
local function guard(state,instance,card)
    local spec=specs[instance.cardId]
    if not spec then return nil end
    assert(integer(instance.uid) and instance.uid>0,"invalid retained instance UID")
    assert(type(state.player)=="table" and type(state.player.statuses)=="table","missing retained player")
    assert(card.id==instance.cardId and card.type==spec.type and card.cost==spec.cost,"unsupported retained base modification")
    assert(card.selfRetain==true,"retained build card missing selfRetain")
    assert(not card.ethereal and not instance.ethereal,"unsupported_currentcompound")
    assert(not instance.retain,"unsupported_temporary_retain_compound")
    local establishment=state.player.statuses.establishment or 0
    local corruption=state.player.statuses.corruption or 0
    assert(integer(establishment) and integer(corruption),"invalid retained cost Power")
    assert(establishment==0,"unsupported_retained_establishment")
    -- Corruption is handled by the shared instance-cost/payment/exhaust ABI.
    -- Retain changes base Block only; it must not reapply or erase those costs.
    for _,field in ipairs(fields) do
        local n=value(instance,field)
        if field~=spec.field and not (instance.cardId=="sands_of_time" and field=="retainedCostReduction") then
            assert(n==0,"retained bonus attached to wrong card")
        end
    end
    for _,field in ipairs({"combatCost","turnCost"}) do
        assert(instance[field]==nil or integer(instance[field]),"unsupported retained cost override")
    end
    for _,field in ipairs({"costForTurn","costOverride","freeToPlayOnce","isCostModifiedForTurn"}) do
        assert(instance[field]==nil or instance[field]==false,"unsupported retained cost ABI: "..field)
    end
    return spec
end
local function inPile(pile,instance)
    for _,card in ipairs(pile or {}) do if card==instance then return true end end
    return false
end
function M.adaptDefinition(state,instance,card)
    local spec=guard(state,instance,card)
    if not spec then return card end
    local out=copy(card)
    if spec.field then
        local expected=instance.upgraded and spec.up or spec.base
        assert(#out.effects==1 and out.effects[1].op==spec.op and out.effects[1].value==expected,"unsupported retained effect modification")
        local total=expected+0.0+value(instance,spec.field)
        assert(integer(total),"retained card value overflow")
        out.effects[1].value=total
    elseif instance.cardId=="sands_of_time" then
        out.cost=math.max(0,spec.cost-value(instance,"retainedCostReduction"))
    end
    return out
end

-- Host calls at RestoreRetainedCardsAction's boundary, after ordinary discard
-- and ethereal processing, before enemy actions. `retainedCards` is its limbo.
-- A scheduled cost reduction must be consumed AFTER restoration in queue order.
function M.onRetained(state,instance)
    if not specs[instance.cardId] then return false,"not_retained_build_card" end
    assert(type(state.player)=="table","missing retained player")
    if state.player.hp<=0 or state.phase~="player" then return false,"not_retention_phase" end
    if inPile(state.draw,instance) or inPile(state.discard,instance) or inPile(state.exhaust,instance)
        or state.cardInUse==instance then return false,"not_retained" end
    if not inPile(state.hand,instance) and not inPile(state.retainedCards,instance) then return false,"not_retained" end
    local card=effective(state,instance);local spec=guard(state,instance,card)
    assert(integer(state.turn) and state.turn>0,"invalid retained turn")
    local previous=instance.retainedTurn
    assert(previous==nil or integer(previous),"invalid retained turn stamp")
    if previous==state.turn then return false,"already_retained_this_turn" end
    if spec.field then
        local amount=instance.upgraded and spec.upStep or spec.step
        local total=value(instance,spec.field)+0.0+amount
        assert(integer(total),"retained growth overflow")
        local base=instance.upgraded and spec.up or spec.base
        assert(integer(base+0.0+total),"retained card value overflow")
        instance[spec.field]=total
    end
    instance.retainedTurn=state.turn
    if instance.cardId=="sands_of_time" then return true,{op="reduceRetainedCost",uid=instance.uid} end
    return true
end

-- Implements ReduceCostAction's source modifyCostForCombat(-1), using the
-- shared generic override ABI rather than always subtracting from original 4.
function M.reduceBaseCost(state,instance)
    assert(instance.cardId=="sands_of_time","retained cost target must be Sands of Time")
    local card=effective(state,instance);guard(state,instance,card)
    if state.player.hp<=0 or state.phase~="player" then return false,"not_retention_phase" end
    local reduction=value(instance,"retainedCostReduction")
    local base=instance.combatCost
    if base==nil then base=math.max(0,4-reduction) end
    local turn=instance.turnCost
    if turn==nil then turn=base end
    local nextBase,nextTurn
    if turn>0 then nextBase=math.max(0,turn-1);nextTurn=nextBase
    else nextBase=math.max(0,base-1);nextTurn=0 end
    local increment=(turn>0 or base>0) and 1 or 0
    assert(integer(reduction+0.0+increment),"retained reduction overflow")
    instance.combatCost=nextBase;instance.turnCost=nextTurn
    instance.retainedCostReduction=reduction+increment
    return true
end

function M.withCards(data)
    assert(type(data)=="table" and data.cards and type(data.cards.cards)=="table","missing retained card data")
    local out=copy(data);local seen={}
    for _,c in ipairs(out.cards.cards) do seen[c.id]=true end
    local cards={
        {id="protect",sourceId="Protect",sts_name="Protect",name="护身",color="purple",type="skill",rarity="common",cost=2,selfRetain=true,
            effects={{op="block",value=12}},upgrade={effects={{op="block",value=16}}},
            text="保留。获得12点格挡。",upgradeText="保留。获得16点格挡。"},
        {id="perseverance",sourceId="Perseverance",sts_name="Perseverance",name="坚韧",color="purple",type="skill",rarity="uncommon",cost=1,selfRetain=true,
            effects={{op="block",value=5}},upgrade={effects={{op="block",value=7}}},
            text="保留。获得5点格挡。每次保留时，本牌本场战斗的格挡增加2。",upgradeText="保留。获得7点格挡。每次保留时，本牌本场战斗的格挡增加3。"},
        {id="windmill_strike",sourceId="WindmillStrike",sts_name="Windmill Strike",name="风车打击",color="purple",type="attack",rarity="uncommon",cost=2,selfRetain=true,
            sourceTags={"STRIKE"},effects={{op="damage",value=7}},upgrade={effects={{op="damage",value=10}}},
            text="保留。造成7点伤害。每次保留时，本牌本场战斗的伤害增加4。",upgradeText="保留。造成10点伤害。每次保留时，本牌本场战斗的伤害增加5。"},
        {id="sands_of_time",sourceId="SandsOfTime",sts_name="Sands of Time",name="化沙",color="purple",type="attack",rarity="uncommon",cost=4,selfRetain=true,
            effects={{op="damage",value=20}},upgrade={effects={{op="damage",value=26}}},
            text="保留。造成20点伤害。每次保留时，本牌本场战斗的费用降低1，最低0。",upgradeText="保留。造成26点伤害。每次保留时，本牌本场战斗的费用降低1，最低0。"},
    }
    for _,card in ipairs(cards) do assert(not seen[card.id],"retained card already exists");out.cards.cards[#out.cards.cards+1]=card end
    return out
end
return M
