-- Read-only permanent card candidates. Commands and transactions stay with Run.
local C = require('abyss_copy')
local M = {}
local protected = {Necronomicurse=true,CurseOfTheBell=true,AscendersBane=true,
    necronomicurse=true,curse_of_the_bell=true,ascenders_bane=true}
function M.purgeCards(run)
    local rows={}
    for _,card in ipairs(run.deck) do
        local context=run.transformContext
        local source=context and context.cards and context.cards[card.cardId]
        local sourceId=source and source.sourceId or card.cardId
        if not protected[sourceId] and not protected[card.cardId] and not card.inBottleFlame and not card.inBottleLightning and not card.inBottleTornado then
            -- Source addToTop is group.add(c), preserving masterDeck order.
            rows[#rows+1]=C.copy(card)
        end
    end
    return rows
end
return M
