-- FountainOfCurseRemoval / AbstractPlayer.isCursed at fixed 319009d5.
-- The event grants no maximum HP or healing; Parasite's own removal hook
-- reduces maximum HP. The enclosing node command owns the transaction.
local Curses=require('abyss_curses')
local M={}
local protected={Necronomicurse=true,CurseOfTheBell=true,AscendersBane=true,
    necronomicurse=true,curse_of_the_bell=true,ascenders_bane=true}
local function definition(run,card)
    for _,def in ipairs(run.data.cards.cards) do if def.id==card.cardId then return def end end
end
local function curse(run,card)
    local def=definition(run,card)
    return def and def.type=='curse' and not protected[card.cardId]
        and not protected[def.sts_name],def
end
function M.isCursed(run)
    for _,card in ipairs(run.deck) do if curse(run,card) then return true end end
    return false
end
function M.cleanse(run,flow)
    local uids={}
    for i=#run.deck,1,-1 do
        local card=run.deck[i]
        local eligible,def=curse(run,card)
        if eligible and not card.inBottleFlame and not card.inBottleLightning then
            -- Do not silently skip an unsupported onRemoveFromMasterDeck effect.
            if not Curses.isImplemented(def) then return false,'event_content_unavailable' end
            uids[#uids+1]=card.uid
        end
    end
    flow.event.removedUids={}
    for _,uid in ipairs(uids) do
        local ok,reason=require('abyss_run').removeCard(run,uid)
        if not ok then return false,reason end
        flow.event.removedUids[#flow.event.removedUids+1]=uid
    end
    return true
end
return M
