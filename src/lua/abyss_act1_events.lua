-- Fixed 319009d5 event contracts. Source option order and intermediate screens
-- are retained; rewards use Run's permanent inventory transaction boundary.
local Run=require('abyss_run')
local Purge=require('abyss_living_wall')
local M={ids={sssserpent=true,big_fish=true,accursed_blacksmith=true,bonfire=true}}
function M.prepare(run,event)
    if event.id=='big_fish' then event.healAmount=math.floor(run.maxHp/3) end
end
local function row(choice,title,description,enabled)
    return {choice=choice,title=title,description=description,enabled=enabled~=false}
end
local function result(run,text)
    run.nodeFlow.event.stage='result';run.nodeFlow.event.body=text
    return true,'pending'
end
local function find(list,id,key)
    for _,value in ipairs(list) do if value[key or 'id']==id then return value end end
end
local function transaction(run,fn)
    if not Run.transaction then return false,'event_content_unavailable' end
    return Run.transaction(run,fn)
end
local function commitCard(run,offer)
    if not Run.commitCard then return false,'event_content_unavailable' end
    local ok,uid=Run.commitCard(run,offer)
    if ok then
        run.nodeFlow.event.obtainedCardUid=type(uid)=='number' and uid or nil
        run.nodeFlow.event.curseBlocked=uid=='curse_blocked'
    end
    return ok,uid
end
local function obtainRelic(run,id)
    if not Run.obtainRelic then return false,'event_content_unavailable' end
    local ok,localId=Run.obtainRelic(run,id)
    if ok then run.nodeFlow.event.obtainedRelicId=localId end
    return ok,localId
end
function M.options(run,event,upgradeCards)
    local id,stage=event.id,event.stage
    if stage=='result' or stage=='disagree' then return {row('leave','离开','返回路线。')} end
    if id=='sssserpent' then
        if stage=='agree' then return {row('confirm','收下馈赠','获得175金币与诅咒「疑虑」。')} end
        return {row('agree','接受','获得175金币与诅咒「疑虑」；需要再次确认。'),row('disagree','拒绝','拒绝这笔交易。')}
    elseif id=='big_fish' then
        return {row('banana','香蕉','回复'..event.healAmount..'点生命。'),row('donut','甜甜圈','最大生命增加5。'),row('box','盒子','获得随机遗物与诅咒「悔恨」。')}
    elseif id=='accursed_blacksmith' then
        if stage=='choose_card' then return {row('forge','锻造','必须选择一张卡牌升级。')} end
        return {row('forge','锻造','升级一张卡牌。',#upgradeCards(run)>0),row('rummage','搜寻','获得扭曲之钳与诅咒「疼痛」。'),row('leave','离开','放弃锻造与搜寻。')}
    elseif id=='bonfire' then
        if not stage then return {row('approach','靠近','靠近篝火中的元素。')} end
        return {row('offer','献祭','移除一张非瓶装可清除卡牌，按稀有度获得回报。')}
    end
    return {}
end
function M.choose(run,flow,choice,uid,upgradeable,upgradeCards)
    local event=flow.event
    if uid~=nil and event.stage~='choose_card' then return false,'invalid_event_choice' end
    if event.stage=='result' or event.stage=='disagree' then
        if choice~='leave' then return false,'invalid_event_choice' end
        return true,'complete'
    end
    if event.id=='sssserpent' then
        if not event.stage and (choice=='agree' or choice=='disagree') then
            event.stage=choice
            event.body=choice=='agree' and '长蛇等待你伸手接过馈赠。' or '你拒绝了交易，准备离去。'
            return true,'pending'
        end
        if event.stage~='agree' or choice~='confirm' then return false,'invalid_event_choice' end
        if not Run.transaction or not Run.prepareCard then return false,'event_content_unavailable' end
        local ok,detail=Run.transaction(run,function(staged)
            local offer,why=Run.prepareCard(staged,'Doubt');if not offer then return false,why end
            if not Run.gainGold then return false,'event_content_unavailable' end
            local gained=Run.gainGold(staged,175)
            local obtained,uid=commitCard(staged,offer)
            if not obtained then return false,uid end
            staged.nodeFlow.event.obtainedCardUid=type(uid)=='number' and uid or nil
            staged.nodeFlow.event.curseBlocked=uid=='curse_blocked'
            staged.nodeFlow.event.stage='result'
            staged.nodeFlow.event.body='获得'..gained..'金币。'..(uid=='curse_blocked' and '诅咒已被御守阻止。' or '诅咒「疑虑」已加入牌组。')
            return true,'pending'
        end)
        return ok,detail
    elseif event.id=='big_fish' then
        if choice=='banana' then
            if not Run.heal then return false,'event_content_unavailable' end
            local healed=Run.heal(run,event.healAmount)
            return result(run,'回复'..healed..'点生命。')
        elseif choice=='donut' then
            if not Run.increaseMaxHp then return false,'event_content_unavailable' end
            local ok,healed=Run.increaseMaxHp(run,5);if not ok then return false,healed end
            return result(run,'最大生命增加5，回复'..healed..'点生命。')
        elseif choice=='box' then
            return transaction(run,function(staged)
                if not Run.prepareRelic or not Run.prepareCard then return false,'event_content_unavailable' end
                local offer,nextPool=Run.prepareRelic(staged,{channel='event',screenless=true,room='event'})
                if not offer then return false,nextPool end
                -- Source first selects the relic, then constructs the card effect
                -- (old Omamori), equips the relic and finally resolves the card
                -- effect's delayed onObtain against the new relic list.
                local card,why=Run.prepareCard(staged,'Regret');if not card then return false,why end
                local ok
                ok,why=obtainRelic(staged,offer.id or offer.sourceId);if not ok then return false,why end
                ok,why=commitCard(staged,card);if not ok then return false,why end
                staged.relicPool=nextPool
                staged.nodeFlow.event.relicOffer=offer
                return result(staged,'你打开了盒子。'..(staged.nodeFlow.event.curseBlocked and '诅咒已被御守阻止。' or '诅咒「悔恨」已加入牌组。'))
            end)
        end
    elseif event.id=='accursed_blacksmith' then
        if not event.stage then
            if choice=='leave' then return result(run,'你离开了铁砧。') end
            if choice=='forge' then
                if #upgradeCards(run)==0 then return false,'card_not_upgradeable' end
                event.stage,event.choice='choose_card','forge'
                event.body='选择一张卡牌升级。';return true,'choose_card'
            end
            if choice=='rummage' then
                return transaction(run,function(staged)
                    if not Run.prepareCard then return false,'event_content_unavailable' end
                    local offer,why=Run.prepareCard(staged,'Pain');if not offer then return false,why end
                    local ok
                    ok,why=obtainRelic(staged,'WarpedTongs');if not ok then return false,why end
                    ok,why=commitCard(staged,offer);if not ok then return false,why end
                    return result(staged,staged.nodeFlow.event.curseBlocked and '获得扭曲之钳；诅咒已被御守阻止。' or '获得扭曲之钳与诅咒「疼痛」。')
                end)
            end
        elseif event.stage=='choose_card' and choice=='forge' then
            local instance=find(run.deck,uid,'uid')
            if not instance then return false,'invalid_card' end
            if not upgradeable(run,instance) then return false,'card_not_upgradeable' end
            instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
            instance.upgraded=true;event.upgradedUids={uid}
            return result(run,'所选卡牌已升级。')
        end
    elseif event.id=='bonfire' then
        if not event.stage and choice=='approach' then
            event.stage='choose';event.body='篝火中的元素等待一张卡牌。';return true,'pending'
        elseif event.stage=='choose' and choice=='offer' then
            if #Purge.purgeCards(run)==0 then return result(run,'没有可献祭的卡牌。') end
            event.stage,event.choice='choose_card','offer';return true,'choose_card'
        elseif event.stage=='choose_card' and choice=='offer' then
            local instance=find(Purge.purgeCards(run),uid,'uid')
            if not instance then return false,'card_not_purgeable' end
            local definition=find(run.data.cards.cards,instance.cardId)
            if not definition then return false,'event_content_unavailable' end
            return transaction(run,function(staged)
                local rarity=definition.rarity
                local beforeHp,beforeMax=staged.hp,staged.maxHp
                if rarity=='curse' then
                    local spirit=false
                    for _,id in ipairs(staged.relics) do if id=='spirit_poop' or id=='Spirit Poop' then spirit=true end end
                    local ok,why=obtainRelic(staged,spirit and 'Circlet' or 'Spirit Poop');if not ok then return false,why end
                elseif rarity=='common' or rarity=='special' then
                    if not Run.heal then return false,'event_content_unavailable' end
                    Run.heal(staged,5)
                elseif rarity=='uncommon' then
                    if not Run.heal then return false,'event_content_unavailable' end
                    Run.heal(staged,staged.maxHp)
                elseif rarity=='rare' then
                    if not Run.increaseMaxHp or not Run.heal then return false,'event_content_unavailable' end
                    local ok,why=Run.increaseMaxHp(staged,10);if not ok then return false,why end
                    Run.heal(staged,staged.maxHp)
                elseif rarity~='basic' then return false,'event_content_unavailable' end
                -- Bonfire applies the reward before permanent remove hooks.
                if not Run.removeCard then return false,'event_content_unavailable' end
                local ok,why=Run.removeCard(staged,uid);if not ok then return false,why end
                staged.nodeFlow.event.removedUid=uid;staged.nodeFlow.event.offeredRarity=rarity
                return result(staged,'卡牌已献祭。生命 '..beforeHp..' → '..staged.hp..'；最大生命 '..beforeMax..' → '..staged.maxHp..'。'..
                    (rarity=='curse' and '获得精灵便便（已持有时改为圆环）。' or ''))
            end)
        end
    end
    return false,'invalid_event_choice'
end
return M
