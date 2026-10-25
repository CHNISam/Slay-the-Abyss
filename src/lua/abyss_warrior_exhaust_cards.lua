-- Explicit opt-in definitions; Corruption costs and exhaust hooks live in Core.
-- Audited against aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0.
local M={}
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for key,child in pairs(value) do result[key]=copy(child) end;return result
end
local function power(id,value) return {{op='gainExhaustPower',status=id,value=value}} end
local function pact(count)
    return {{op='handChoice',mode='exhaust_choose',value=1},{op='draw',value=count}}
end
local cards={
    {id='corruption',sts_name='Corruption',name='腐化',type='power',rarity='rare',cost=3,
        effects=power('corruption',1),upgrade={cost=2},
        text='技能牌耗能变为0。每当你打出技能牌，消耗它。',
        upgradeText='技能牌耗能变为0。每当你打出技能牌，消耗它。'},
    {id='feel_no_pain',sts_name='Feel No Pain',name='无惧疼痛',type='power',rarity='uncommon',cost=1,
        effects=power('feel_no_pain',3),upgrade={effects=power('feel_no_pain',4)},
        text='每当你消耗一张牌，获得3点格挡。',upgradeText='每当你消耗一张牌，获得4点格挡。'},
    {id='dark_embrace',sts_name='Dark Embrace',name='黑暗之拥',type='power',rarity='uncommon',cost=2,
        effects=power('dark_embrace',1),upgrade={cost=1},
        text='每当你消耗一张牌，抽1张牌。',upgradeText='每当你消耗一张牌，抽1张牌。'},
    {id='sentinel',sts_name='Sentinel',name='哨卫',type='skill',rarity='uncommon',cost=1,
        effects={{op='block',value=5}},upgrade={effects={{op='block',value=8}}},
        text='获得5点格挡。如果这张牌被消耗，获得2点能量。',
        upgradeText='获得8点格挡。如果这张牌被消耗，获得3点能量。'},
    {id='burning_pact',sts_name='Burning Pact',name='燃烧契约',type='skill',rarity='uncommon',cost=1,
        effects=pact(2),upgrade={effects=pact(3)},
        text='消耗1张手牌。抽2张牌。',upgradeText='消耗1张手牌。抽3张牌。'},
}
local powers={
    {id='corruption',name='腐化',kind='buff',stack='none',decay='none',
        description='技能牌耗能变为0。每当你打出技能牌，消耗它。'},
    {id='feel_no_pain',name='无惧疼痛',kind='buff',stack='intensity',decay='none',
        description='每当你消耗一张牌，获得等同于此能力层数的格挡；不受敏捷或脆弱影响。'},
    {id='dark_embrace',name='黑暗之拥',kind='buff',stack='intensity',decay='none',
        description='每当你消耗一张牌，抽等同于此能力层数的牌。'},
}
function M.withCards(data)
    assert(type(data)=='table' and data.cards and type(data.cards.cards)=='table'
        and data.statuses and type(data.statuses.statuses)=='table','missing warrior exhaust data')
    assert(not data.experimentalWarriorExhaust,'warrior exhaust data already prepared')
    local out,cardIds,statusIds=copy(data),{},{}
    for index,card in ipairs(out.cards.cards) do
        assert(type(card)=='table' and type(card.id)=='string' and not cardIds[card.id],'duplicate source card')
        cardIds[card.id]=index
    end
    for index,status in ipairs(out.statuses.statuses) do
        assert(type(status)=='table' and type(status.id)=='string' and not statusIds[status.id],'duplicate source status')
        statusIds[status.id]=index
    end
    local nativeReplacements={}
    for _,card in ipairs(cards) do
        local index=cardIds[card.id]
        if index then
            -- Native develop cards carry target metadata. Replace only that
            -- detached definition; an existing opt-in card is a real collision.
            local existing=out.cards.cards[index]
            assert(existing.target~=nil and existing.experimental~=true,
                'warrior exhaust card already defined: '..card.id)
            nativeReplacements[card.id]=true
        end
        local definition=copy(card);definition.color='red';definition.experimental=true
        out.cards.cards[index or #out.cards.cards+1]=definition
    end
    for _,status in ipairs(powers) do
        local index=statusIds[status.id]
        assert(not index or nativeReplacements[status.id],
            'warrior exhaust power already defined: '..status.id)
        out.statuses.statuses[index or #out.statuses.statuses+1]=copy(status)
    end
    out.experimentalWarriorExhaust=true
    return out
end
return M
