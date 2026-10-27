-- Fixed 319009d5 source ordering. Colored pools come from the active class's
-- existing pool owner; colorless and curse library order are catalog inputs,
-- including unavailable definitions. Never filter these lists by capability.
local M={}
local colorless={'Madness','Thinking Ahead','Mind Blast','Metamorphosis','Jack Of All Trades','Swift Strike','Good Instincts','Master of Strategy','Magnetism','Finesse','Discovery','Chrysalis','Transmutation','Panacea','Purity','Enlightenment','Forethought','Flash of Steel','HandOfGreed','Mayhem','Apotheosis','Secret Weapon','Panache','Violence','Deep Breath','Secret Technique','Bandage Up','Blind','The Bomb','Impatience','Dramatic Entrance','Trip','PanicButton','Sadistic Nature','Dark Shackles'}
local curses={'Regret','Injury','Shame','Parasite','Normality','Doubt','Writhe','Pain','Decay','Clumsy'}
function M.new(run)
    local source=run.data.cards.sourcePools
    if not source or not source.reward or not source.src then return nil end
    if type(source.reward.common)~='table' or type(source.src.uncommon)~='table' or type(source.src.rare)~='table' then return nil end
    local result={pools={common={},srcUncommon={},srcRare={},srcColorless={},curses={}},cards={},sourceToLocal={}}
    local definitions={}
    for _,card in ipairs(run.data.cards.cards)do
        local id=card.sourceId or card.sts_name or card.id
        definitions[card.id]=id
        result.sourceToLocal[id]=card.id
        result.cards[card.id]={sourceId=id,category=card.type=='curse' and 'curse' or card.color=='colorless' and 'colorless' or 'colored'}
    end
    for name,entries in pairs({common=source.reward.common,srcUncommon=source.src.uncommon,srcRare=source.src.rare})do
        for _,id in ipairs(entries)do
            -- A mismatched class pool is unavailable rather than silently
            -- transformed into the previous class's cards.
            if not definitions[id]then return nil end
            result.pools[name][#result.pools[name]+1]=definitions[id]
        end
    end
    for i,id in ipairs(colorless)do result.pools.srcColorless[i]=id end
    for i,id in ipairs(curses)do result.pools.curses[i]=id end
    return result
end
return M
