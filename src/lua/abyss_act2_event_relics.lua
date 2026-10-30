-- Direct Act2 event relics, fixed STS319009d5. Hosts own permanent/combat
-- transactions; this leaf never imports Run/Combat or invents another queue.
local Actors=require('abyss_actor')
local Events=require('abyss_events')
local M={}
local aliases={['Bloody Idol']='bloody_idol',MutagenicStrength='mutagenic_strength',
    Necronomicon='necronomicon',Enchiridion='enchiridion',["Nilry's Codex"]='nilrys_codex'}
local identities={bloody_idol=true,mutagenic_strength=true,necronomicon=true,enchiridion=true,nilrys_codex=true}
function M.is(id)return identities[aliases[id]or id]==true end
function M.owns(owner,id)
    for _,held in ipairs(owner.relics or {})do if (aliases[held]or held)==id then return true end end
    return false
end
function M.onEquip(_run,id,api)
    if id~='necronomicon'then return true end
    assert(api and type(api.obtainCard)=='function','Necronomicon requires permanent obtain API')
    local ok,why=api.obtainCard('Necronomicurse')
    if not ok then return false,why end
    return true
end
function M.onUnequip(run,id)
    if id~='necronomicon'then return true end
    -- Necronomicon.onUnequip uses group.remove, NOT removeCard. It removes
    -- only the first matching Necronomicurse and must not trigger its rebound.
    for i,card in ipairs(run.deck)do
        if card.cardId=='necronomicurse'or card.cardId=='Necronomicurse'then table.remove(run.deck,i);break end
    end
    return true
end
function M.gainGold(owner,amount,heal)
    if amount<=0 or not M.owns(owner,'bloody_idol')then return end
    assert(type(heal)=='function','Bloody Idol requires the owner healing API')
    heal(5)
end
local function lossPower(state,amount)
    local p=state.player
    if not Actors.isActive(p)or Actors.tryBlockDebuff(state,p,'lose_strength')then return end
    local old=p.temporaryStrength or 0
    assert(type(old)=='number'and old%1==0 and old>=0 and old+0.0+amount<=2147483647,'invalid Mutagenic loss')
    p.temporaryStrength=old+amount
    local order={};local found=false
    for _,id in ipairs(p.temporaryPowerOrder or {})do order[#order+1]=id;if id=='strength'then found=true end end
    if not found then order[#order+1]='strength'end
    p.temporaryPowerOrder=order
    order={};found=false
    for _,id in ipairs(p.powerOrder or {})do order[#order+1]=id;if id=='lose_strength'then found=true end end
    if not found then order[#order+1]='lose_strength'end
    p.powerOrder=order
    Events.emit(state,'status',{source=p.id,target=p.id,status='lose_strength',amount=amount})
end
function M.battleStart(state,id)
    assert(id=='mutagenic_strength','unknown Act2 battle-start relic')
    -- Three TOP inserts: RelicAbove, LoseStrength, Strength. The loss Power
    -- reaches Artifact BEFORE the gain. Flex's gain-then-loss helper differs.
    lossPower(state,3)
    Actors.applyPower(state,state.player,'strength',3,state.player)
end
function M.turnStart(state)
    if M.owns(state,'necronomicon')then state.relicCombat.necronomiconActivated=true end
end
function M.copyAttack(combat,state,instance,card,targetIndex,energyOnUse,freeToPlayOnce,sourceCost,actions)
    if card.dontTriggerOnUseCard or card.type~='attack'or not M.owns(state,'necronomicon')then return false end
    local c=assert(state.relicCombat,'missing Necronomicon combat owner')
    if c.necronomiconActivated==false then return false end
    local x=combat.combatBaseCost(state,instance)==-1
    local cost=sourceCost or card.cost
    if not((cost>=2 and not freeToPlayOnce)or(x and energyOnUse>=2))then return false end
    c.necronomiconActivated=false
    local copied=assert(actions,'Necronomicon requires the host card API').sameInstance(combat,state,instance)
    combat.queueCard(state,copied,{targetIndex=targetIndex,energyOnUse=energyOnUse,purge=true,exhaustCards=false})
    Events.emit(state,'relic_repeat',{relic='necronomicon',uid=instance.uid,copyUid=copied.uid})
    return true
end
function M.preBattle(combat,state,actions,implemented)
    local candidates={}
    for _,rarity in ipairs({'common','uncommon','rare'})do
        for _,id in ipairs(assert(state.sourcePools.src[rarity],'missing Enchiridion source pool'))do
            local d=assert(state.catalog.cards[id],'missing Enchiridion source card '..id)
            if d.type=='power'and not d.healing then candidates[#candidates+1]=id end
        end
    end
    assert(#candidates>0,'empty Enchiridion source power pool')
    local id=candidates[combat.cardRandom(state,#candidates)]
    assert(implemented and implemented(state.catalog.cards[id]),'Enchiridion card_content_unavailable: '..id)
    assert(actions,'Enchiridion requires the host card API')
    local card=actions.fresh(combat,state,id)
    -- Enchiridion sets cost before MakeTempCardInHand; Master Reality then
    -- upgrades the physical generated card once, retaining this turn's zero.
    if combat.combatBaseCost(state,card)~=-1 then card.costForTurn=0 end
    actions.created(combat,state,card)
    actions.toHand(state,card)
    Events.emit(state,'cards_created',{source=state.player.id,relic='enchiridion',cardId=id,amount=1,pile=#state.hand>0 and state.hand[#state.hand]==card and'hand'or'discard'})
end
return M
