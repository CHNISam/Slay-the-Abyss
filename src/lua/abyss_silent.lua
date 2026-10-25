-- Opt-in Silent foundation. Shared Combat remains the sole play/turn engine.
local Combat = require("abyss_combat")
local Events = require("abyss_events")
local M = {}

local function integer(value, minimum, maximum)
    return type(value) == "number" and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

-- Return detached data: callers must deliberately opt in before Combat.new.
-- This does not add green cards to Ironclad rewards or claim a playable class.
function M.withFoundationCards(data)
    local result = Combat.copy(data)
    for _, card in ipairs(result.cards.cards) do
        assert(card.id ~= "deadly_poison" and card.id ~= "shiv" and card.id ~= "blade_dance", "foundation card already registered")
    end
    result.cards.cards[#result.cards.cards + 1] = {
        id="deadly_poison", type="skill", rarity="common", cost=1,
        effects={{op="applyStatus", status="poison", value=5}},
        upgrade={effects={{op="applyStatus", status="poison", value=7}}},
    }
    result.cards.cards[#result.cards.cards + 1] = {
        id="shiv", type="attack", rarity="special", cost=0, exhaust=true,
        effects={{op="damage", value=4}},
        upgrade={effects={{op="damage", value=6}}},
    }
    result.cards.cards[#result.cards.cards + 1] = {
        id="blade_dance", type="skill", rarity="common", cost=1,
        effects={{op="generateShivs",value=3}},
        upgrade={effects={{op="generateShivs",value=4}}},
    }
    local extra = {
        {id="survivor",type="skill",rarity="basic",cost=1,
            effects={{op="block",value=8},{op="requestDiscard",value=1}},
            upgrade={effects={{op="block",value=11},{op="requestDiscard",value=1}}}},
        {id="acrobatics",type="skill",rarity="common",cost=1,
            effects={{op="draw",value=3},{op="requestDiscard",value=1}},
            upgrade={effects={{op="draw",value=4},{op="requestDiscard",value=1}}}},
        {id="tactician",type="skill",rarity="uncommon",cost=-2,effects={},upgrade={}},
        {id="reflex",type="skill",rarity="uncommon",cost=-2,effects={},upgrade={}},
        {id="footwork",type="power",rarity="uncommon",cost=1,
            effects={{op="gainStatus",status="dexterity",value=2}},
            upgrade={effects={{op="gainStatus",status="dexterity",value=3}}}},
        {id="backflip",type="skill",rarity="common",cost=1,
            effects={{op="block",value=5},{op="draw",value=2}},
            upgrade={effects={{op="block",value=8},{op="draw",value=2}}}},
        {id="dagger_throw",type="attack",rarity="common",cost=1,
            effects={{op="damage",value=9},{op="draw",value=1},{op="requestDiscard",value=1}},
            upgrade={effects={{op="damage",value=12},{op="draw",value=1},{op="requestDiscard",value=1}}}},
        {id="dagger_spray",type="attack",rarity="common",cost=1,
            effects={{op="damageAll",value=4,times=2}},
            upgrade={effects={{op="damageAll",value=6,times=2}}}},
        {id="cloak_and_dagger",type="skill",rarity="common",cost=1,
            effects={{op="block",value=6},{op="generateShivs",value=1}},
            upgrade={effects={{op="block",value=6},{op="generateShivs",value=2}}}},
        {id="prepared",type="skill",rarity="common",cost=0,
            effects={{op="draw",value=1},{op="requestDiscard",value=1}},
            upgrade={effects={{op="draw",value=2},{op="requestDiscard",value=2}}}},
        {id="quick_slash",type="attack",rarity="common",cost=1,
            effects={{op="damage",value=8},{op="draw",value=1}},
            upgrade={effects={{op="damage",value=12},{op="draw",value=1}}}},
        {id="catalyst",type="skill",rarity="uncommon",cost=1,exhaust=true,
            effects={{op="multiplyPoison",value=2}},
            upgrade={effects={{op="multiplyPoison",value=3}}}},
        {id="bouncing_flask",type="skill",rarity="uncommon",cost=2,
            effects={{op="bouncingPoison",value=3}},
            upgrade={effects={{op="bouncingPoison",value=4}}}},
        {id="noxious_fumes",type="power",rarity="uncommon",cost=1,
            effects={{op="gainStatus",status="noxious_fumes",value=2}},
            upgrade={effects={{op="gainStatus",status="noxious_fumes",value=3}}}},
    }
    for _, card in ipairs(extra) do
        for _, existing in ipairs(result.cards.cards) do
            assert(existing.id ~= card.id, "foundation card already registered")
        end
        result.cards.cards[#result.cards.cards + 1] = card
    end
    for _, status in ipairs(result.statuses.statuses) do
        assert(status.id ~= "noxious_fumes", "foundation status already registered")
    end
    result.statuses.statuses[#result.statuses.statuses + 1] = {
        id="noxious_fumes",name="毒雾",kind="buff",stack="intensity",decay="none",
        description="从下回合起，每个你的回合抽牌后，给予所有敌人等同层数的中毒。",
    }
    return require("abyss_shivs").withCardDefinitions(result)
end

-- Resolved generation action; the shared effect dispatcher owns card payment.
-- Master Reality remains unsupported; Accuracy stamps the new instance base.
function M.generateShivs(state, count, upgraded)
    assert(type(state) == "table" and state.phase == "player"
        and not Combat.outcome(state), "generation requires live player combat")
    assert(integer(count,0,2147483647), "invalid Shiv count")
    assert(upgraded == nil or type(upgraded) == "boolean", "invalid upgrade flag")
    assert(integer(state.nextUid, 1, 2147483647 - count), "card UID overflow")
    assert(state.rules.player.maxHand == 10 and #state.hand <= 10, "unsupported hand capacity")
    assert((state.player.statuses.master_reality or 0) == 0,
        "unsupported generated-card power")
    local card = assert(state.catalog.cards.shiv, "register foundation cards before combat")
    assert(card.type == "attack" and card.cost == 0 and card.exhaust == true
        and card.effects[1].op == "damage" and card.effects[1].value == 4
        and card.upgrade.effects[1].value == 6, "unexpected Shiv definition")
    -- Reject UID collisions before changing any pile. All four piles own UIDs.
    local used = {}
    for _, pile in ipairs({state.hand, state.draw, state.discard, state.exhaust}) do
        for _, instance in ipairs(pile) do
            assert(integer(instance.uid, 1, 2147483647) and not used[instance.uid], "invalid card identity")
            used[instance.uid] = true
        end
    end
    if state.cardInUse then used[state.cardInUse.uid] = true end
    for offset = 0, count - 1 do
        assert(not used[state.nextUid + offset], "card UID collision")
    end
    local generated = {}
    for _ = 1, count do
        local instance = {uid=state.nextUid, cardId="shiv", upgraded=upgraded == true}
        require("abyss_shivs").created(state,instance)
        state.nextUid = state.nextUid + 1
        local destination = #state.hand < 10 and "hand" or "discard"
        state[destination][#state[destination] + 1] = instance
        if destination=="hand" and (state.player.statuses.corruption or 0)~=0 then
            require("abyss_corruption").created(state,instance)
        end
        generated[#generated + 1] = instance.uid
        Events.emit(state, "silent_generate", {uid=instance.uid, cardId="shiv", destination=destination})
    end
    return generated
end

return M
