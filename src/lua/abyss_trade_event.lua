-- Fixed 319009d5 WeMeetAgain. Constructor ordering and cached physical
-- inventory/card identity matter; the player does not select the tribute.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local M={}
local function find(list,id,key)for _,value in ipairs(list)do if value[key or 'id']==id then return value end end end
local function row(choice,title,description,enabled)return {choice=choice,title=title,description=description,enabled=enabled~=false}end
function M.prepare(run,event,rng)
    local slots={}
    for slot=1,Run.potionCapacity(run)do
        if run.potions[slot]then
            assert(find(run.data.potions.potions,run.potions[slot]),'unknown trade potion')
            slots[#slots+1]=slot
        end
    end
    if #slots>0 then
        R.shuffle(rng,slots)
        event.tradePotionSlot,event.tradePotionId=slots[1],run.potions[slots[1]]
    end
    event.tradeGold=run.gold>=50 and R.randomIntBetween(rng,50,math.min(150,run.gold)) or 0
    local cards={}
    for _,card in ipairs(run.deck)do
        local definition=assert(find(run.data.cards.cards,card.cardId),'unknown trade card')
        if definition.rarity~='basic' and definition.type~='curse' then cards[#cards+1]=card end
    end
    if #cards>0 then
        R.shuffle(rng,cards)
        local card=cards[1]
        event.tradeCardUid,event.tradeCardId=card.uid,card.cardId
        event.tradeCardUpgraded,event.tradeCardUpgrades=card.upgraded,card.upgrades
    end
end
function M.options(run,event)
    if event.stage=='result' then return {row('leave','离开','返回路线。')} end
    local potion=row('trade_potion','药水换遗物','交出所示药水，获得随机遗物。',
        event.tradePotionSlot~=nil and run.potions[event.tradePotionSlot]==event.tradePotionId)
    potion.potionId=event.tradePotionId
    local card=row('trade_card','卡牌换遗物','交出所示卡牌，获得随机遗物。',
        event.tradeCardUid~=nil and find(run.deck,event.tradeCardUid,'uid')~=nil)
    card.cardId,card.upgraded,card.upgrades=event.tradeCardId,event.tradeCardUpgraded,event.tradeCardUpgrades
    return {potion,row('trade_gold','金币换遗物','支付'..event.tradeGold..'金币，获得随机遗物。',event.tradeGold>0 and run.gold>=event.tradeGold),
        card,row('leave','拒绝','拒绝交易，不支付任何物品。')}
end
function M.choose(run,flow,choice,uid)
    local event=flow.event
    if uid~=nil then return false,'invalid_event_choice' end
    if event.stage=='result' then
        if choice~='leave' then return false,'invalid_event_choice' end
        return true,'complete'
    elseif event.stage then return false,'invalid_event_choice' end
    local body
    if choice=='leave' then body='你谢绝了交易。'
    elseif choice=='trade_potion' then
        local slot=event.tradePotionSlot
        if not slot or run.potions[slot]~=event.tradePotionId then return false,'event_condition_unmet' end
        -- This is the event's removePotion, not a public discard/use command.
        run.potions[slot]=nil;event.removedPotionSlot=slot
        body='你交出了约定的药水。'
    elseif choice=='trade_gold' then
        if event.tradeGold<=0 or run.gold<event.tradeGold then return false,'insufficient_gold' end
        run.gold=run.gold-event.tradeGold;event.goldPaid=event.tradeGold
        body='你支付了'..event.tradeGold..'金币。'
    elseif choice=='trade_card' then
        local card=event.tradeCardUid and find(run.deck,event.tradeCardUid,'uid')
        if not card or card.cardId~=event.tradeCardId then return false,'invalid_card' end
        -- Source excludes BASIC/CURSE only; bottled nonbasic cards remain valid.
        local ok,why=Run.removeCard(run,card.uid);if not ok then return false,why end
        event.removedUid=card.uid;body='你交出了约定的卡牌。'
    else return false,'invalid_event_choice' end
    if choice~='leave' then
        local offer,pool=Run.prepareRelic(run,{channel='event',screenless=true,room='event'})
        if not offer then return false,pool end
        local ok,id=Run.obtainRelic(run,offer.id);if not ok then return false,id end
        run.relicPool=pool;event.relicOffer,event.obtainedRelicId=offer,id
        body=body..'作为交换，你获得了一件遗物。'
    end
    event.stage,event.body='result',body
    return true,'pending'
end
return M
