-- Explicit experimental class data. Does not start a battle or mutate source data.
local M={}
local specs={
    silent={hp=70,color="green",suffix="G",count=5,module="abyss_silent",extras={"survivor","neutralize"},
        relic="ring_of_the_snake",relicSource="Ring of the Snake",effect={op="draw",value=2}},
    defect={hp=75,color="blue",suffix="B",count=4,module="abyss_defect_cards",extras={"zap","dualcast"},
        relic="cracked_core",relicSource="Cracked Core",effect={op="channelOrb",orb="lightning",value=1}},
    watcher={hp=72,color="purple",suffix="P",count=4,module="abyss_watcher_cards",extras={"eruption","vigilance"},
        relic="pure_water",relicSource="PureWater",effect={op="makeMiracle",value=1}},
}
local copy=require('abyss_copy').copy
local function basic(id,sourceId,color,attack)
    local op=attack and "damage" or "block"
    return {id=id,sourceId=sourceId,sts_name=attack and "Strike" or "Defend",name=attack and "打击" or "防御",
        color=color,type=attack and "attack" or "skill",rarity="basic",cost=1,sourceTags=attack and {'STRIKE'} or nil,
        effects={{op=op,value=attack and 6 or 5}},upgrade={effects={{op=op,value=attack and 9 or 8}}}}
end
function M.prepare(data,id)
    local spec=specs[id]
    assert(id=="ironclad" or spec,"unknown experimental character")
    assert(type(data)=="table" and type(data.rules)=="table" and type(data.rules.player)=="table"
        and type(data.cards)=="table" and type(data.cards.cards)=="table"
        and type(data.relics)=="table" and type(data.relics.relics)=="table", "invalid character source data")
    assert(data.experimentalCharacter==nil,"character data already prepared")
    -- Ironclad builds its explicit verified subset, even when production has
    -- additional red cards. Other classes retain only shared statuses/curses.
    if id == "ironclad" then return require("abyss_warrior_cards").prepareProfile(data) end
    local prepared=copy(data)
    local retained={}
    for _,card in ipairs(prepared.cards.cards) do
        -- Defect utility supplies its audited Burn lifecycle definition.
        -- Production may already contain Burn with a different data schema.
        if (card.type=="status" or card.type=="curse") and not (id=="defect" and card.id=="burn") then
            retained[#retained+1]=card
        end
    end
    prepared.cards.cards=retained
    if id=='silent' then prepared=require('abyss_silent').withFoundationCards(prepared)
    elseif id=='defect' then prepared=require('abyss_defect_cards').withFoundationCards(prepared)
    else prepared=require('abyss_watcher_cards').withFoundationCards(prepared) end
    if id=="silent" then
        prepared=require("abyss_silent_discard_cards").withCardDefinitions(prepared)
        prepared=require("abyss_shivs").withInfiniteBladesDefinition(prepared)
        prepared=require('abyss_silent_attack_cards').withCardDefinitions(prepared)
        prepared=require('abyss_card_triggers').withCards(prepared,id)
        prepared=require('abyss_silent_tactics_cards').withCardDefinitions(prepared)
        prepared=require('abyss_silent_final_cards').withCardDefinitions(prepared)
    elseif id=="defect" then
        prepared=require("abyss_orb_powers").withCards(prepared)
        prepared=require("abyss_defect_utility_cards").withCards(prepared)
        prepared=require('abyss_card_triggers').withCards(prepared,id)
        prepared=require('abyss_defect_engine_cards').withCards(prepared)
        prepared=require('abyss_retrieval_cards').withCards(prepared,id)
        prepared=require('abyss_defect_final_cards').withCards(prepared)
    elseif id=="watcher" then
        prepared=require("abyss_retained_cards").withCards(prepared)
        prepared=require("abyss_watcher_attack_cards").withCards(prepared)
        prepared=require('abyss_watcher_flow_cards').withCards(prepared)
        prepared=require('abyss_watcher_final_cards').withCards(prepared)
    end
    local cards=prepared.cards.cards
    -- Foundation helpers currently contain only this class's verified subset.
    for _,card in ipairs(cards) do
        if card.type~="status" and card.type~="curse" and card.rarity~="special" then card.color=spec.color end
    end
    local strike,defend="strike_"..spec.color,"defend_"..spec.color
    cards[#cards+1]=basic(strike,"Strike_"..spec.suffix,spec.color,true)
    cards[#cards+1]=basic(defend,"Defend_"..spec.suffix,spec.color,false)
    if id=="silent" then
        cards[#cards+1]={id="neutralize",sourceId="Neutralize",sts_name="Neutralize",name="Neutralize",color="green",
            type="attack",rarity="basic",cost=0,
            effects={{op="damage",value=3},{op="applyStatus",status="weak",value=1}},
            upgrade={effects={{op="damage",value=4},{op="applyStatus",status="weak",value=2}}}}
    elseif id=="watcher" then
        local miracle=false
        for _,card in ipairs(cards) do if card.id=='miracle' then miracle=true end end
        if not miracle then cards[#cards+1]={id="miracle",sourceId="Miracle",sts_name="Miracle",name="Miracle",color="colorless",
            type="skill",rarity="special",cost=0,selfRetain=true,exhaust=true,
            effects={{op="energy",value=1}},upgrade={effects={{op="energy",value=2}}}} end
    end
    local deck={}
    for _=1,spec.count do deck[#deck+1]=strike end
    for _=1,spec.count do deck[#deck+1]=defend end
    for _,card in ipairs(spec.extras) do deck[#deck+1]=card end
    prepared.cards.starter_deck={cards=deck,note="Experimental "..id.." source starter; incomplete class pool"}
    prepared.cards.note="Experimental "..id.." foundation subset; not a complete class pool or release qualification"
    if id=='defect'then
        prepared.cards.starter_deck.note='Fixed319009 Defect starter deck'
        prepared.cards.note='Fixed319009 Defect 75-card offline implementation; platform release qualification pending'
    end
    local rules=prepared.rules.player
    rules.maxHp=spec.hp;rules.energyPerTurn=3;rules.drawPerTurn=5;rules.startingGold=99
    rules.startingRelics={spec.relic}
    -- Catalog presence is not ownership. Preserve prerequisite definitions such
    -- as Burning Blood so Black Blood's replaces reference remains resolvable.
    local relics=prepared.relics.relics
    for _,relic in ipairs(relics) do assert(relic.id~=spec.relic,"starter relic already defined") end
    relics[#relics+1]={id=spec.relic,sourceId=spec.relicSource,name=spec.relicSource,rarity="starter",
        trigger="combat_start",effects={copy(spec.effect)}}
    prepared.relics.relics=relics
    prepared.characterId=id
    prepared.experimentalCharacter=id
    local profile={id=id,color=spec.color,experimental=true,maxHp=spec.hp,energyPerTurn=3,drawPerTurn=5,startingGold=99,
        startingRelic=spec.relic,starterDeck=copy(deck),enableStances=true,enableOrbs=true,startingOrbSlots=id=='defect' and 3 or 0}
    require('abyss_class_card_pools').apply(prepared,id)
    return prepared,profile
end
return M
