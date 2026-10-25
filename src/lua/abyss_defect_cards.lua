-- Opt-in source-verified foundation cards; no change to normal acquisition pools.
local M={}
local function copy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value) do out[k]=copy(v) end;return out
end
local function channel(orb) return {op='channelOrb',orb=orb,value=1} end
local cards={
    {id='zap',name='引雷',sts_name='Zap',type='skill',rarity='basic',cost=1,
        effects={channel('lightning')},upgrade={cost=0}},
    {id='dualcast',name='双重释放',sts_name='Dualcast',type='skill',rarity='basic',cost=1,
        effects={{op='dualcastOrb',value=1}},upgrade={cost=0}},
    {id='cold_snap',name='寒击',sts_name='Cold Snap',type='attack',rarity='common',cost=1,
        effects={{op='damage',value=6},channel('frost')},
        upgrade={effects={{op='damage',value=9},channel('frost')}}},
    {id='ball_lightning',name='雷击',sts_name='Ball Lightning',type='attack',rarity='common',cost=1,
        effects={{op='damage',value=7},channel('lightning')},
        upgrade={effects={{op='damage',value=10},channel('lightning')}}},
    {id='coolheaded',name='寒息',sts_name='Coolheaded',type='skill',rarity='common',cost=1,
        effects={channel('frost'),{op='draw',value=1}},
        upgrade={effects={channel('frost'),{op='draw',value=2}}}},
    {id='darkness',name='凝暗',sts_name='Darkness',type='skill',rarity='uncommon',cost=1,
        effects={channel('dark')},upgrade={effects={channel('dark'),{op='darkImpulseOrb',value=1}}}},
    {id='leap',name='飞跃',sts_name='Leap',type='skill',rarity='common',cost=1,
        effects={{op='block',value=9}},upgrade={effects={{op='block',value=12}}}},
    {id='sweeping_beam',name='扫射',sts_name='Sweeping Beam',type='attack',rarity='common',cost=1,
        effects={{op='damageAll',value=6},{op='draw',value=1}},
        upgrade={effects={{op='damageAll',value=9},{op='draw',value=1}}}},
    {id='beam_cell',name='光束',sts_name='Beam Cell',type='attack',rarity='common',cost=0,
        effects={{op='damage',value=3},{op='applyStatus',status='vulnerable',value=1}},
        upgrade={effects={{op='damage',value=4},{op='applyStatus',status='vulnerable',value=2}}}},
    {id='fusion',name='融能',sts_name='Fusion',type='skill',rarity='uncommon',cost=2,
        effects={channel('plasma')},upgrade={cost=1}},
    {id='defragment',name='凝神',sts_name='Defragment',type='power',rarity='uncommon',cost=1,
        effects={{op='gainFocus',value=1}},upgrade={effects={{op='gainFocus',value=2}}}},
    {id='capacitor',name='扩容',sts_name='Capacitor',type='power',rarity='uncommon',cost=1,
        effects={{op='gainOrbSlots',value=2}},upgrade={effects={{op='gainOrbSlots',value=3}}}},
    {id='consume',name='聚能',sts_name='Consume',type='skill',rarity='uncommon',cost=2,
        effects={{op='gainFocus',value=2},{op='loseOrbSlots',value=1}},
        upgrade={effects={{op='gainFocus',value=3},{op='loseOrbSlots',value=1}}}},
    {id='reprogram',name='重构',sts_name='Reprogram',type='skill',rarity='uncommon',cost=1,
        effects={{op='gainFocus',value=-1},{op='gainStatus',status='strength',value=1},{op='gainStatus',status='dexterity',value=1}},
        upgrade={effects={{op='gainFocus',value=-2},{op='gainStatus',status='strength',value=2},{op='gainStatus',status='dexterity',value=2}}}},
    {id='biased_cognition',name='偏执聚能',sts_name='Biased Cognition',type='power',rarity='rare',cost=1,
        effects={{op='gainFocus',value=4},{op='applyBias',value=1}},
        upgrade={effects={{op='gainFocus',value=5},{op='applyBias',value=1}}}},
}
function M.withFoundationCards(data)
    assert(type(data)=='table' and data.cards and type(data.cards.cards)=='table','missing card data')
    local out=copy(data)
    local present={}
    for _,card in ipairs(out.cards.cards) do present[card.id]=true end
    for _,card in ipairs(cards) do
        assert(not present[card.id],'foundation card collision: '..card.id)
        out.cards.cards[#out.cards.cards+1]=copy(card)
    end
    return out
end
return M
