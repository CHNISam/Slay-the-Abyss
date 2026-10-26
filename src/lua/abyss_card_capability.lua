-- Acquisition/upgrade capability, independent of energy, hand, phase or target.
-- A definition's presence alone does not mean the combat engine implements it.
local Effects=require('abyss_effects')
local Curses=require('abyss_curses')
local M={}
local function empty(effects)return type(effects)=='table' and next(effects)==nil end
function M.isImplemented(card)
    if type(card)~='table' then return false end
    if card.originalV4 then return (card.type=='attack' or card.type=='skill') and require('abyss_original_v4').supported(card.originalV4) end
    if card.condition and card.condition~='only_attacks_in_hand' and card.condition~='draw_pile_empty' then return false end
    if card.costMode and card.costMode~='all_energy' then return false end
    -- Default develop now implements Clash and the cost0/X Whirlwind ABI.
    -- Class-only conditional/X definitions retain their explicit activation.
    if card.condition=='draw_pile_empty' and card.experimental~=true then return false end
    if card.experimental==true and card.costMode and card.cost~=-1 then return false end
    -- Registered current lifecycle implementations. Legitimate unplayable
    -- cards remain obtainable; unknown curses/statuses are not blanket-enabled.
    if card.type=='curse' then
        return Curses.isImplemented(card)
    elseif card.type=='status' then
        if card.id=='wound' then
            return card.cost==-2 and empty(card.effects) and not card.ethereal and not card.exhaust and card.upgrade==nil
        end
        if card.id=='dazed' then return card.cost==-2 and card.ethereal==true and empty(card.effects) end
        if card.id=='void' then return card.cost==-2 and card.ethereal==true and empty(card.effects) end
        if card.id=='burn' then
            if card.cost~=-2 or not empty(card.effects) or card.ethereal or card.exhaust then return false end
            -- Upstream's implicit2 Burn and opt-in upgraded2/4 Burn coexist.
            if card.burnDamage==nil then return card.upgrade==nil end
            return card.burnDamage==2 or card.burnDamage==4
        end
        if card.id=='slimed' then
            return card.cost==1 and card.exhaust==true and not card.ethereal
                and card.upgrade==nil and empty(card.effects)
        end
        return false
    end
    if card.type~='attack' and card.type~='skill' and card.type~='power' then return false end
    if card.cost == -2 then
        return (card.id == "tactician" or card.id == "reflex") and card.type == "skill" and empty(card.effects)
    end
    return Effects.supported(card.effects)==true
end
return M
