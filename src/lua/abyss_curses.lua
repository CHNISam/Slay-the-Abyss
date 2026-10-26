-- STS1 basic curses. Permanent removal is deliberately separate from combat
-- exhaust/discard; the permanent-deck transaction must call onRemove once.
local M={}
local ids={regret=true,injury=true,doubt=true,pain=true,decay=true,shame=true,
    writhe=true,clumsy=true,normality=true,parasite=true}
function M.isImplemented(card)
    return type(card)=='table' and ids[card.id]==true and card.type=='curse'
        and card.rarity=='curse' and card.cost==-2 and type(card.effects)=='table'
        and next(card.effects)==nil and card.upgrade==nil and not card.exhaust
        and not card.repeatable and not card.costMode and not card.condition
        and (card.ethereal==true)==(card.id=='clumsy')
        and (card.innate==true)==(card.id=='writhe')
        and (card.id~='decay' or card.endTurnDamage==2)
        and ((card.id~='doubt' and card.id~='shame') or card.endTurnStatusAmount==1)
        and (card.id~='pain' or card.onOtherCardHpLoss==1)
        and (card.id~='normality' or card.playLimit==3)
        and (card.id~='parasite' or card.onRemoveMaxHpLoss==3)
end
function M.limitsPlay(state)
    for _,c in ipairs(state.hand) do
        if c.cardId=='normality' and #(state.cardsPlayedThisTurn or {})>=state.catalog.cards[c.cardId].playLimit then return true end
    end
    return false
end
function M.endTurnCard(id)
    return id=='regret' or id=='decay' or id=='doubt' or id=='shame'
end
function M.onRemove(owner,card)
    local id=type(card)=='table' and card.cardId or card
    if id~='parasite' then return 0 end
    assert(type(owner)=='table' and type(owner.maxHp)=='number' and owner.maxHp>=1
        and owner.maxHp%1==0 and owner.maxHp<=2147483647 and type(owner.hp)=='number'
        and owner.hp>=0 and owner.hp<=owner.maxHp and owner.hp%1==0,'invalid permanent HP owner')
    local before=owner.maxHp
    owner.maxHp=math.max(1,owner.maxHp-3)
    owner.hp=math.min(owner.hp,owner.maxHp)
    return before-owner.maxHp
end
return M
