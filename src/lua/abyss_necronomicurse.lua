-- Necronomicurse's actual special-curse lifecycle, fixed319009d5. Permanent
-- removal rebirth bypasses obtains; combat exhaust uses a fresh hand copy.
local M={}
function M.supported(card)
    return type(card)=='table'and card.id=='necronomicurse'and card.sourceId=='Necronomicurse'
        and card.type=='curse'and(card.color==nil or card.color=='curse')and card.rarity=='special'and card.cost==-2
        and type(card.effects)=='table'and next(card.effects)==nil and card.upgrade==nil
        and not card.exhaust and not card.ethereal and not card.innate
end
function M.onRemove(run,card)
    if card.cardId~='necronomicurse'then return false end
    local definition
    for _,d in ipairs(run.data.cards.cards)do if d.id=='necronomicurse'then definition=d;break end end
    assert(M.supported(definition),'missing real Necronomicurse')
    local uid=run.nextDeckUid
    assert(type(uid)=='number'and uid%1==0 and uid>0 and uid<9007199254740991.0,'invalid Necronomicurse UID')
    for _,c in ipairs(run.deck)do assert(c.uid~=uid,'duplicate Necronomicurse UID')end
    -- NecronomicurseEffect constructor directly masterDeck.addToTop(new ...).
    -- Omamori, Darkstone Periapt and Ceramic Fish must NOT see this rebirth.
    run.deck[#run.deck+1]={uid=uid,cardId='necronomicurse',upgraded=false}
    run.nextDeckUid=uid+1.0
    return true
end
function M.exhaustPlan(instance)
    if instance.cardId~='necronomicurse'then return end
    return {kind='effect',effect={op='makeTempCardInHand',card='necronomicurse',value=1}}
end
return M
