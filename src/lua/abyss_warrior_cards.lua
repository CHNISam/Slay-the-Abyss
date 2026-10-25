-- Explicit experimental activation of the seven dormant source-defined cards.
local M={}
local function copy(x)
    if type(x)~='table' then return x end
    local y={};for k,v in pairs(x) do y[k]=copy(v) end;return y
end
local function choice(mode) return {op='handChoice',mode=mode,value=1} end
-- The opt-in rules below cover this foundation and its explicit additions.
-- A larger production catalog must not silently expand the experimental pool.
local foundationIds={}
for id in ('strike defend bash cleave clothesline iron_wave anger body_slam clash flex true_grit twin_strike pommel_strike shrug_it_off thunderclap warcry uppercut inflame metallicize battle_trance bloodletting barricade carnage disarm dropkick entrench ghostly_armor hemokinesis rampage seeing_red shockwave whirlwind offering impervious demon_form bludgeon reaper'):gmatch('%S+') do
    foundationIds[id]=true
end
local rebuiltPowers={corruption=true,feel_no_pain=true,dark_embrace=true,
    rupture=true,combust=true,brutality=true,berserk=true,rage=true,
    flame_barrier=true,evolve=true,fire_breathing=true}
local rebuiltStates={wound=true,dazed=true,burn=true}
local function profileSource(data)
    assert(type(data)=='table' and data.cards and type(data.cards.cards)=='table'
        and data.statuses and type(data.statuses.statuses)=='table','missing warrior source data')
    local out,seen,retained=copy(data),{},{}
    for _,card in ipairs(out.cards.cards) do
        assert(not seen[card.id],'duplicate source card');seen[card.id]=true
        if foundationIds[card.id] or ((card.type=='status' or card.type=='curse') and not rebuiltStates[card.id]) then
            retained[#retained+1]=card
        end
    end
    for id in pairs(foundationIds) do assert(seen[id],'missing foundation card: '..id) end
    out.cards.cards=retained
    retained={};seen={}
    for _,status in ipairs(out.statuses.statuses) do
        assert(not seen[status.id],'duplicate source status');seen[status.id]=true
        if not rebuiltPowers[status.id] then retained[#retained+1]=status end
    end
    out.statuses.statuses=retained
    return out
end
local replacements={
    clash={cost=0,condition='only_attacks_in_hand',effects={{op='damage',value=14}},
        upgrade={effects={{op='damage',value=18}}}},
    true_grit={cost=1,effects={{op='block',value=7},choice('exhaust_random')},
        upgrade={effects={{op='block',value=9},choice('exhaust_choose')}}},
    warcry={cost=0,exhaust=true,effects={{op='draw',value=1},choice('put_on_deck')},
        upgrade={effects={{op='draw',value=2},choice('put_on_deck')}}},
    metallicize={cost=1,effects={{op='gainStatus',status='metallicize',value=3}},
        upgrade={effects={{op='gainStatus',status='metallicize',value=4}}}},
    whirlwind={cost=-1,costMode='all_energy',effects={{op='whirlwind',value=5}},
        upgrade={effects={{op='whirlwind',value=8}}}},
    demon_form={cost=3,effects={{op='gainStatus',status='demon_form',value=2}},
        upgrade={effects={{op='gainStatus',status='demon_form',value=3}}}},
    reaper={cost=2,exhaust=true,effects={{op='reaperDamage',value=4}},
        upgrade={effects={{op='reaperDamage',value=5}}}},
}
function M.withFoundationCards(data)
    assert(type(data)=='table' and data.cards and type(data.cards.cards)=='table'
        and data.statuses and type(data.statuses.statuses)=='table','missing warrior source data')
    assert(not data.experimentalWarrior,'warrior data already prepared')
    local out,seen=copy(data),{}
    for _,card in ipairs(out.cards.cards) do
        assert(not seen[card.id],'duplicate source card');seen[card.id]=true
        local replacement=replacements[card.id]
        if replacement then
            for k,v in pairs(replacement) do card[k]=copy(v) end
            card.experimental=true
        end
    end
    for id in pairs(replacements) do assert(seen[id],'missing source card: '..id) end
    local statuses={}
    for _,s in ipairs(out.statuses.statuses) do
        assert(not statuses[s.id],'duplicate source status');statuses[s.id]=true
    end
    for _,id in ipairs({'metallicize','demon_form'}) do
        if not statuses[id] then
        out.statuses.statuses[#out.statuses.statuses+1]={id=id,name=id=='metallicize' and '金属化' or '恶魔形态',kind='buff',stack='intensity',decay='none',
            description=id=='metallicize' and '每回合结束时获得等同层数的固定格挡。' or '从下回合起，每回合抽牌后获得等同层数的力量。'}
        end
    end
    out.experimentalWarrior=true
    return out
end
function M.prepareProfile(data)
    assert(type(data)=='table' and not data.experimentalCharacter,'character data already prepared')
    local out=M.withFoundationCards(profileSource(data))
    out=require('abyss_warrior_exhaust_cards').withCards(out)
    out=require('abyss_warrior_strength_cards').withCards(out)
    out=require('abyss_card_triggers').withCards(out,'ironclad')
    out=require('abyss_warrior_status_cards').withCards(out)
    out=require('abyss_retrieval_cards').withCards(out,'ironclad')
    assert(out.rules and out.rules.player and out.relics and type(out.relics.relics)=='table','missing warrior rules')
    local burning=false
    for _,r in ipairs(out.relics.relics) do if r.id=='burning_blood' then burning=true end end
    assert(burning,'missing Burning Blood definition')
    for _,card in ipairs(out.cards.cards) do
        if card.type~='status' and card.type~='curse' then card.color='red' end
    end
    out.cards.note='Experimental Ironclad: explicitly verified 66-card subset; production catalog is preserved separately.'
    local deck={'strike','strike','strike','strike','strike','defend','defend','defend','defend','bash'}
    out.cards.starter_deck={cards=copy(deck),note='Experimental Ironclad source starter.'}
    local p=out.rules.player
    p.maxHp=80;p.energyPerTurn=3;p.drawPerTurn=5;p.startingGold=99;p.startingRelics={'burning_blood'}
    out.characterId='ironclad';out.experimentalCharacter='ironclad'
    return out,{id='ironclad',color='red',experimental=true,maxHp=80,energyPerTurn=3,drawPerTurn=5,
        startingGold=99,startingRelic='burning_blood',starterDeck=copy(deck),enableStances=true,enableOrbs=true,startingOrbSlots=0}
end
return M
