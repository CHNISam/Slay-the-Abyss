-- Acquisition/upgrade capability, independent of energy, hand, phase or target.
-- A definition's presence alone does not mean the combat engine implements it.
local Effects=require('abyss_effects')
local M={}
local function empty(effects)return type(effects)=='table' and next(effects)==nil end
function M.isImplemented(card)
    if type(card)~='table' or card.condition or card.costMode then return false end
    -- Registered current lifecycle implementations. Legitimate unplayable
    -- cards remain obtainable; unknown curses/statuses are not blanket-enabled.
    if card.type=='curse' then
        return card.id=='regret' and card.cost==-2 and empty(card.effects)
    elseif card.type=='status' then
        if card.id=='dazed' then return card.cost==-2 and card.ethereal==true and empty(card.effects) end
        if card.id=='slimed' then
            return card.cost==1 and card.exhaust==true and not card.ethereal
                and card.upgrade==nil and empty(card.effects)
        end
        return false
    end
    if card.type~='attack' and card.type~='skill' and card.type~='power' then return false end
    return card.cost~=-2 and Effects.supported(card.effects)==true
end
return M
