-- BackToBasics at fixed source 319009d5, expressed in the local command model.
-- Nodes owns the enclosing transaction; no price, RNG, refund or new reward.
local Run=require('abyss_run')
local Purge=require('abyss_living_wall')
local M={}
-- The eight source classes explicitly carry STARTER_STRIKE/STARTER_DEFEND.
-- STRIKE, BASIC, display names and starter-deck membership are not that tag.
local starters={Strike_R=true,Defend_R=true,Strike_G=true,Defend_G=true,
    Strike_B=true,Defend_B=true,Strike_P=true,Defend_P=true}
local function unresolved(run)
    return run.data.originalV4Role~=nil or run.characterProfile and run.characterProfile.originalV4==true
end
local function row(choice,title,description,enabled,picker)
    return {choice=choice,title=title,description=description,enabled=enabled~=false,picker=picker}
end
function M.prepare(_run,event)
    event.stage='intro';event.body='古老的文字记载着两条道路：优雅与简洁。'
end
function M.options(run,event)
    if event.stage=='intro' then
        local boundary=unresolved(run)
        return {row('elegance','优雅','免费移除一张非瓶装、可清除的永久牌。'),
            row('simplicity','简洁',boundary and '当前原创职业的初始打击/防御源标签映射尚未确认，暂不可用。' or
                '升级所有尚可升级的初始打击与防御。',not boundary)}
    elseif event.stage=='choose_card' then
        return {row('purge','移除卡牌','选择一张非瓶装、可清除的永久牌。',#Purge.purgeCards(run)>0,'basics_purge')}
    elseif event.stage=='result' then return {row('leave','离开','返回路线。')} end
    return {}
end
function M.view(run,event)
    if event.stage~='choose_card' then return end
    event.purgeCards=Purge.purgeCards(run)
    -- Four-argument grid overload: canCancel=true internally, unlike Beggar.
    -- Normal event UI does not expose its cancel button; no cancel command.
    event.selection={count=1,forUpgrade=false,forTransform=false,canCancel=true,forPurge=false,anyNumber=false}
end
local function unique(run,uid)
    local matches=0
    for _,card in ipairs(run.deck) do if card.uid==uid then matches=matches+1 end end
    return type(uid)=='number' and uid%1==0 and uid>0 and matches==1
end
local function upgradeStarters(run,event,upgradeable)
    if unresolved(run) then return false,'starter_tags_unresolved' end
    local targets={}
    for _,card in ipairs(run.deck) do
        local definition
        for _,entry in ipairs(run.data.cards.cards) do if entry.id==card.cardId then definition=entry;break end end
        local sources=run.data.cards.sourcePools
        local metadata=sources and sources.cardSourceMetadata and sources.cardSourceMetadata[card.cardId]
        local sourceId=definition and definition.sourceId or metadata and metadata.sourceId or definition and definition.id
        if starters[sourceId] and not card.upgraded then
            -- These eight source classes canUpgrade while not upgraded. Missing
            -- local content is not a source zero-target outcome. Resolve every
            -- target before writing any, so an implementation gap fails closed.
            if not definition or not upgradeable(run,card) then return false,'card_content_unavailable' end
            if not unique(run,card.uid) then return false,'invalid_card' end
            targets[#targets+1]=card
        end
    end
    event.upgradedUids={}
    for _,card in ipairs(targets) do
        card.upgrades=(card.upgrades or (card.upgraded and 1 or 0))+1
        card.upgraded=true
        -- Bottle flags remain on the same permanent entity; combat reads it.
        event.upgradedUids[#event.upgradedUids+1]=card.uid
    end
    event.choice,event.stage='simplicity','result'
    event.body='文字归于简洁。已升级 '..#targets..' 张初始打击与防御。'
    return true,'pending'
end
local function purge(run,event,uid)
    if not unique(run,uid) then return false,'invalid_card' end
    local allowed=false
    for _,card in ipairs(Purge.purgeCards(run)) do if card.uid==uid then allowed=true;break end end
    if not allowed then return false,'card_not_purgeable' end
    local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
    event.removedUid,event.stage=uid,'result'
    event.body='你舍弃了一张卡牌，领会了优雅。'
    return true,'pending'
end
function M.choose(run,flow,choice,uid,upgradeable)
    local event=flow.event
    if event.stage=='result' and choice=='leave' and uid==nil then return true,'complete' end
    if event.stage=='choose_card' then
        if choice~='purge' then return false,'invalid_event_choice' end
        return purge(run,event,uid)
    end
    if event.stage~='intro' or uid~=nil then return false,'invalid_event_choice' end
    if choice=='simplicity' then return upgradeStarters(run,event,upgradeable) end
    if choice~='elegance' then return false,'invalid_event_choice' end
    event.choice='purge'
    if #Purge.purgeCards(run)==0 then
        event.stage='result';event.body='没有可移除的卡牌。古老的文字渐渐沉寂。'
        return true,'pending'
    end
    event.stage='choose_card';event.body='选择一张非瓶装、可清除的永久牌移除。'
    return true,'choose_card'
end
return M
